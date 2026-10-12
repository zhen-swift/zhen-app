import Foundation
import Synchronization
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// An engine that records its run into whatever store it was built over, the way
/// `ScanRunner` does, and counts how many were built.
nonisolated final class CountingEngine: ScanEngine {
  static let built = Mutex(0)
  let store: any HistoryStore
  let report: ScanReport
  var interface: NetworkInterface {
    NetworkInterface(name: "en0", address: report.run.target.networkAddress, network: report.run.target)
  }

  init(store: any HistoryStore, report: ScanReport) {
    self.store = store
    self.report = report
  }

  func run(network: IPv4Network?, budget: Duration, deepScan: Bool, progress: ProgressSink) async -> CompletedScan {
    var report = report
    report.run.id = UUID()
    if let network {
      report.run.target = network
      report.devices = report.devices.filter { $0.ipv4Addresses.contains(where: network.contains) }
    }
    return CompletedScan(report: report, events: await store.record(report))
  }
}

/// Phase 3, stage 1: the scanning bugs that corrupted what the app showed.
@MainActor
struct ScanningBehaviourTests {
  static func loadedModel() async -> NetworkModel {
    let environment = AppEnvironment.parse(
      arguments: ["-Fixture", "home", "-ScanPace", "1", "-UITesting"], environment: [:], now: .now
    )
    let model = NetworkModel(environment: environment)
    await model.load()
    return model
  }

  /// Gate. Break: `records: true` in `NetworkModel.performPortScan` — the /32 becomes the
  /// latest run and every other device reads as gone.
  @Test("A port scan of one device leaves every other device present, and history unchanged")
  func portScanKeepsTheNetwork() async throws {
    let model = await Self.loadedModel()
    let online = model.onlineCount
    let run = model.latestRun?.id
    let events = model.events.count
    let quiet = try #require(model.devices.first { $0.isOnline && $0.device.ports.isEmpty && !$0.device.ipv4Addresses.isEmpty })
    try #require(online > 1)

    model.scanPorts(quiet.id)
    #expect(model.isBusy)
    await model.performPortScan()
    await model.reload()

    #expect(model.onlineCount == online, "a port scan took devices offline")
    #expect(model.latestRun?.id == run, "the port scan became the latest run")
    #expect(model.events.count == events, "the port scan wrote events")
    let result = try #require(model.portScans[quiet.id])
    #expect(result.state == .finished)
    #expect(!result.ports.isEmpty)
    #expect(!model.isBusy)
  }

  /// Gate. Break: hand the engine `store` instead of `ProbeOnlyStore(base: store)` in
  /// `LiveScanRunner.run`.
  @Test("Through the live runner, a scan that does not record leaves the store untouched")
  func liveRunnerProbeOnly() async throws {
    let store = InMemoryHistoryStore()
    let capture = try FixtureNetwork.capture()
    _ = await store.record(capture)
    let before = await store.latestRun()?.id
    let runner = LiveScanRunner(store: store) { store throws(PlatformError) in
      CountingEngine(store: store, report: capture)
    }
    let address = try #require(capture.devices.first?.ipv4Addresses.first)
    let request = ScanRequest(network: IPv4Network(base: address, prefix: 32), deepScan: true, records: false)
    _ = await runner.run(request, progress: ProgressSink { _ in })
    #expect(await store.latestRun()?.id == before)
    #expect(await store.devices().filter(\.isPresent).count == capture.devices.count)
  }

  /// Gate. Break: drop the reset in `LiveScanRunner.note` — the helper installed
  /// mid-session is then never used until a relaunch.
  @Test("A helper state change builds a fresh engine; the same state keeps the one built")
  func freshEngineOnHelperChange() async throws {
    let capture = try FixtureNetwork.capture()
    let built = Mutex(0)
    let runner = LiveScanRunner(store: InMemoryHistoryStore()) { store throws(PlatformError) in
      built.withLock { $0 += 1 }
      return CountingEngine(store: store, report: capture)
    }
    await runner.note(.notInstalled)
    _ = await runner.run(ScanRequest(), progress: ProgressSink { _ in })
    await runner.note(.notInstalled)
    _ = await runner.run(ScanRequest(), progress: ProgressSink { _ in })
    #expect(built.withLock { $0 } == 1, "an unchanged helper rebuilt the engine: 3.2 s a scan with a stale registration")
    await runner.note(.installed)
    _ = await runner.run(ScanRequest(), progress: ProgressSink { _ in })
    #expect(built.withLock { $0 } == 2, "installing the helper did not reach the engine")
  }

  /// Gate. Break: make `HistoryWatcher.changes` never yield (or drop the
  /// `.task { await model.watchHistory() }`, which this does not see — the UI half is in
  /// the verification doc).
  @Test("A scan written to the history file by another process appears in the model")
  func terminalScanAppears() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "zhen-watch-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "history.ndjson")
    // Live data source, but the history is a scratch file: the real one is never opened.
    var environment = AppEnvironment.parse(arguments: [], environment: ["ZHEN_HISTORY": file.path], now: .now)
    environment.dataSource = .live
    let model = NetworkModel(environment: environment)
    try #require(model.historyURL?.standardizedFileURL == file.standardizedFileURL)
    await model.reload()
    #expect(model.devices.isEmpty)

    let watching = Task { await model.watchHistory() }
    defer { watching.cancel() }
    // Written once the watch is under way, so the poll — not the reload it starts with —
    // is what has to see it.
    try await Task.sleep(for: .milliseconds(300))
    #expect(model.devices.isEmpty)
    // The command line, as far as the file can tell: another store on the same path.
    _ = await LogHistoryStore(url: file).record(try FixtureNetwork.capture())

    let deadline = ContinuousClock.now + .seconds(5)
    while model.devices.isEmpty, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(100))
    }
    #expect(!model.devices.isEmpty, "the window never saw the terminal's scan")
  }

  @Test("The watcher reports a write, a compaction-style replace, and a file appearing")
  func watcherSeesEachKindOfChange() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "zhen-watch-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "history.ndjson")
    let stream = HistoryWatcher.changes(of: file, every: .milliseconds(50))
    let seen = Mutex(0)
    let consumer = Task { for await _ in stream { seen.withLock { $0 += 1 } } }
    defer { consumer.cancel() }
    /// Waits, up to two seconds, for the watcher to have reported `count` changes.
    func reported(_ count: Int) async -> Bool {
      let deadline = ContinuousClock.now + .seconds(2)
      while seen.withLock({ $0 }) < count, ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(20))
      }
      return seen.withLock { $0 } >= count
    }

    try Data("one\n".utf8).write(to: file)  // appears
    #expect(await reported(1), "a new file went unreported")
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("two\n".utf8))  // appended
    try handle.close()
    #expect(await reported(2), "an append went unreported")
    let replacement = directory.appending(path: "history.tmp")
    try Data("snapshot\n".utf8).write(to: replacement)
    _ = try FileManager.default.replaceItemAt(file, withItemAt: replacement)  // compacted
    #expect(await reported(3), "a replace by rename went unreported")
  }

  @Test("The scan budget comes from Settings, and an unknown value falls back to 30 s")
  func budget() throws {
    let defaults = try #require(UserDefaults(suiteName: "zhen.settings.tests"))
    defaults.removePersistentDomain(forName: "zhen.settings.tests")
    #expect(Preferences(defaults).budget == .seconds(30))
    defaults.set(60, forKey: Preferences.Key.budgetSeconds)
    #expect(Preferences(defaults).budget == .seconds(60))
    defaults.set(7, forKey: Preferences.Key.budgetSeconds)
    #expect(Preferences(defaults).budget == .seconds(30))
    defaults.removePersistentDomain(forName: "zhen.settings.tests")
  }
}
