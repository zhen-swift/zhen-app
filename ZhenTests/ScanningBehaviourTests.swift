import Foundation
import Synchronization
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// An engine that records into whatever store it was built over, the way `ScanRunner`
/// does: a run with `record`, a port probe with `recordPorts`.
nonisolated final class CountingEngine: ScanEngine {
  let store: any HistoryStore
  let report: ScanReport
  var interface: NetworkInterface {
    NetworkInterface(name: "en0", address: report.run.target.networkAddress, network: report.run.target)
  }

  init(store: any HistoryStore, report: ScanReport) {
    self.store = store
    self.report = report
  }

  func run(network: IPv4Network?, budget: Duration, ports: PortStage, progress: ProgressSink) async -> CompletedScan {
    var report = report
    report.run.id = UUID()
    if let network {
      report.run.target = network
      report.devices = report.devices.filter { $0.ipv4Addresses.contains(where: network.contains) }
    }
    return CompletedScan(report: report, events: await store.record(report))
  }

  /// What answers at each address: the device's recorded ports, or the common ports closed.
  func probePorts(_ addresses: [IPAddress], spec: PortSpec, budget: Duration, progress: ProgressSink) async -> CompletedPortScan {
    var ports: [IPAddress: [PortObservation]] = [:]
    for case .v4(let address) in addresses {
      guard let device = report.devices.first(where: { $0.ipv4Addresses.contains(address) }) else { continue }
      ports[.v4(address)] = device.ports.isEmpty ? FixtureScanRunner.closedPorts(at: address) : device.ports
    }
    let result = PortScanResult(ports: ports)
    return CompletedPortScan(result: result, events: await store.recordPorts(result, targeted: addresses, at: .now))
  }
}

/// Phase 3, stage 1: the scanning bugs that corrupted what the app showed — and, with
/// zhen-core 0.7.0, the port probe that replaced their workarounds.
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

  /// Gate. Break: probe through `pipeline.run(ScanRequest(network: /32, ports: .everyHost))`
  /// in `NetworkModel.performPortScan` — the /32 becomes the latest run and every other
  /// device reads as gone.
  @Test("A port scan of one device leaves every other device present, and records no run")
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
    #expect(model.events.count == events, "a first look at a device's ports wrote events")
    let result = try #require(model.portScans[quiet.id])
    #expect(result.state == .finished)
    #expect(!result.ports.isEmpty)
    #expect(model.device(quiet.id)?.device.ports.isEmpty == false, "the ports did not reach history")
    #expect(!model.isBusy)
  }

  /// Gate — the thing `ProbeOnlyStore` cost. Break: build the probe's engine over an
  /// `InMemoryHistoryStore()` in `LiveScanRunner.probePorts`, which is a session-only result.
  @Test("Port results survive a relaunch")
  func portResultsSurviveARelaunch() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "zhen-relaunch-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "history.ndjson")
    let capture = try FixtureNetwork.capture()
    // The file as a scan would have left it, before this launch.
    _ = await LogHistoryStore(url: url).record(capture)
    let quiet = try #require(capture.devices.first { $0.ports.isEmpty && !$0.ipv4Addresses.isEmpty })

    let suite = "zhen.relaunch.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let environment = AppEnvironment.parse(arguments: [], environment: ["ZHEN_HISTORY": url.path], now: .now)
    let engine: LiveScanRunner.Factory = { store, _ in CountingEngine(store: store, report: capture) }
    #expect(environment.dataSource == .live)

    let first = NetworkModel(environment: environment, defaults: defaults, engine: engine)
    await first.load()
    let id = try #require(first.devices.first { $0.device.ipv4Addresses == quiet.ipv4Addresses }?.id)
    first.scanPorts(id)
    await first.performPortScan()
    #expect(first.portScans[id]?.state == .finished)

    // A relaunch: a new model, a new store, the same file.
    let relaunched = NetworkModel(environment: environment, defaults: defaults, engine: engine)
    await relaunched.load()
    let ports = relaunched.device(id)?.device.ports ?? []
    #expect(!ports.isEmpty, "the port scan was lost at relaunch")
    #expect(relaunched.portScans.isEmpty, "the result came from the session, not from history")
    #expect(relaunched.onlineCount == capture.devices.count, "the port scan took devices offline")
  }

  /// Gate. Break: `asksHelper = true` in `LiveScanRunner.note` — a helper this app has not
  /// installed, or that awaits approval, is asked anyway, and an unapproved one never answers.
  @Test("Every scan builds its engine, and asks the helper only when it is installed")
  func engineFollowsTheHelper() async throws {
    let capture = try FixtureNetwork.capture()
    let asked = Mutex<[Bool]>([])
    let runner = LiveScanRunner(store: InMemoryHistoryStore()) { store, asksHelper throws(PlatformError) in
      asked.withLock { $0.append(asksHelper) }
      return CountingEngine(store: store, report: capture)
    }
    for state: HelperState in [.notInstalled, .requiresApproval, .unavailable("no"), .installed] {
      await runner.note(state)
      _ = await runner.run(ScanRequest(), progress: ProgressSink { _ in })
    }
    let address = try #require(capture.devices.first?.ipv4Addresses.first)
    _ = await runner.probePorts(PortProbeRequest(addresses: [.v4(address)]), progress: ProgressSink { _ in })
    #expect(asked.withLock { $0 } == [false, false, false, true, true],
            "the engine was not built for the helper as it stood at each scan")
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
