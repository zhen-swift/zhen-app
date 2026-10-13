import Foundation
import Synchronization
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// Part 7: the defects the code review found.
@MainActor
struct ReviewFixTests {
  /// Gate. Break: keep the engine between scans in `LiveScanRunner` — the one built on the
  /// old network then scans it from the new one.
  @Test("Every scan builds its engine, so a move to another network is never scanned as the old one")
  func networkChange() async throws {
    let capture = try FixtureNetwork.capture()
    let built = Mutex(0)
    let runner = LiveScanRunner(store: InMemoryHistoryStore()) { store, _ throws(PlatformError) in
      built.withLock { $0 += 1 }
      return CountingEngine(store: store, report: capture)
    }
    _ = await runner.run(ScanRequest(), progress: ProgressSink { _ in })
    _ = await runner.run(ScanRequest(), progress: ProgressSink { _ in })
    #expect(built.withLock { $0 } == 2, "the second scan reused the first scan's engine")
  }

  /// Gate. Break: drop `if !isExecuting { phase = .idle }` from `ScanSession.stop`.
  @Test("A scan asked for with nothing to run it can still be stopped")
  func stopWithoutAHost() {
    let session = ScanSession()
    session.start(ScanRequest())
    #expect(session.isRunning)
    session.stop()
    #expect(!session.isRunning, "stuck running with no host")
  }

  /// Gate. Break: drop the `isOnline` guard in `PortScan.result`.
  @Test("Ports found at an offline device's address are not shown as this one's")
  func portsOfAnotherDevice() throws {
    let capture = try FixtureNetwork.capture()
    let device = try #require(capture.devices.first { !$0.ports.isEmpty && $0.mac != nil })
    let address = try #require(device.ipv4Addresses.first)
    let result = PortScanResult(ports: [.v4(address): device.ports])
    let outcome = PortProbeOutcome.finished(CompletedPortScan(result: result, events: []))
    #expect(PortScan.result(of: outcome, for: address, isOnline: true).state == .finished)
    if case .failed = PortScan.result(of: outcome, for: address, isOnline: false).state {} else {
      Issue.record("ports answering at an offline device's old address were shown as its own")
    }
  }

  @Test("Show in Activity searches for what events carry, never a name given here")
  func activityTerm() throws {
    let capture = try FixtureNetwork.capture()
    let named = try #require(capture.devices.first { $0.displayName != nil })
    let item = DeviceItem(id: "x", device: named, isOnline: true, userName: "My Name", isReassigned: false)
    #expect(item.activitySearchTerm == named.displayName)
  }

  /// Gate. Break: drop `carryAcrossNewIDs` from `reload`.
  @Test("A device whose ID changes keeps its given name, and its old ID still finds it")
  func idChange() async throws {
    let suite = "zhen.review.tests"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let environment = AppEnvironment.parse(arguments: ["-Fixture", "home", "-UITesting"], environment: [:], now: .now)
    let model = NetworkModel(environment: environment, defaults: defaults)
    await model.load()
    // A device keyed by its Bonjour name over a rotating MAC.
    let before = try #require(model.devices.first { $0.id.hasPrefix("mdns") && $0.isPrivateMAC })
    model.rename(before.id, to: "Kitchen laptop")

    // A run in which naming did not happen: the same device, no names.
    var run = try FixtureNetwork.capture()
    run.run.id = UUID()
    run.run.startedAt = Timestamp(millisecondsSinceEpoch: (model.latestRun?.startedAt.millisecondsSinceEpoch ?? 0) + 60_000)
    run.run.finishedAt = run.run.startedAt
    run.devices = run.devices.map { device in
      var device = device
      if device.mac == before.device.mac { device.names = [] }
      return device
    }
    _ = await model.store.record(run)
    await model.reload()

    let after = try #require(model.devices.first { $0.device.mac == before.device.mac })
    try #require(after.id != before.id, "the fixture did not re-key the device; the test proves nothing")
    #expect(after.userName == "Kitchen laptop", "the given name was lost with the old ID")
    #expect(model.device(before.id)?.id == after.id, "the old ID no longer finds the device")
  }

  /// Gate. Break: restore `if let run, let saved = recalledDegradations(…)` in `reload`.
  @Test("A run recorded elsewhere does not inherit the last run's warnings")
  func degradationsFollowTheRun() async throws {
    // Its own domain: the shared fixture one is cleared by every model the parallel tests
    // make, and the saved degradations went with it.
    let suite = "zhen.review.degradations"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let environment = AppEnvironment.parse(arguments: ["-Fixture", "partial", "-UITesting"], environment: [:], now: .now)
    let model = NetworkModel(environment: environment, defaults: defaults)
    await model.load()
    try #require(!model.lastDegradations.isEmpty, "the partial fixture has no degradations; the test proves nothing")
    // `zhen scan` in a terminal: a complete run this app did not record.
    var terminal = try FixtureNetwork.capture()
    terminal.run.id = UUID()
    terminal.run.outcome = .complete
    terminal.run.startedAt = Timestamp(millisecondsSinceEpoch: (model.latestRun?.startedAt.millisecondsSinceEpoch ?? 0) + 60_000)
    terminal.run.finishedAt = terminal.run.startedAt
    _ = await model.store.record(terminal)
    await model.reload()
    #expect(model.lastDegradations.isEmpty, "a complete run showed the previous run's warnings")
    #expect(!model.latestRunIsPartial)
  }

  /// Gate. Break: drop `model:` from the `ColumnWidths` cache key.
  @Test("Two models never share cached widths")
  func cachesAreModels() {
    let home = PreviewContainer.model(.home)
    let empty = PreviewContainer.model(.empty)
    #expect(home.devicesRevision == empty.devicesRevision, "different revisions: the test proves nothing")
    let now = Date.now
    let homeWidths = DevicesView.ColumnWidths.cached(for: home, now: now)
    let emptyWidths = DevicesView.ColumnWidths.cached(for: empty, now: now)
    #expect(emptyWidths.mac == DevicesView.ColumnWidths(rows: empty.devices, now: now).mac)
    #expect(homeWidths.mac != emptyWidths.mac)
  }
}
