import Foundation
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// The live scan's view model: what each engine event does to the screen, and how a scan
/// ends — handed back, or stopped with everything it found.
@MainActor
struct ScanSessionTests {
  let capture: ScanReport

  init() throws {
    capture = try FixtureNetwork.capture()
  }

  private func facts(_ index: Int, named: Bool = false) -> HostFacts {
    FixtureScanRunner.facts(capture.devices[index], named: named)
  }

  @Test("Starting: every stage queued, deep scan skipped unless asked, nothing found")
  func starting() {
    let session = ScanSession()
    session.start(ScanRequest())
    #expect(session.phase == .running)
    #expect(session.stageStates[.discovery] == .queued)
    #expect(session.stageStates[.naming] == .queued)
    #expect(session.stageStates[.deepScan] == .skipped)
    #expect(session.found.isEmpty)
    #expect(session.runToken != nil)
  }

  @Test("Hosts arrive newest first; an update changes the row in place, not its position")
  func arrivals() {
    let session = ScanSession()
    session.start(ScanRequest())
    session.apply([.stageStarted(.discovery), .hostFound(facts(0)), .hostFound(facts(1))])
    session.apply([.hostFound(facts(2))])
    #expect(session.found.map(\.id) == [facts(2).ip, facts(1).ip, facts(0).ip])
    session.apply([.hostUpdated(facts(1, named: true))])
    #expect(session.found.map(\.id) == [facts(2).ip, facts(1).ip, facts(0).ip])
    #expect(session.found[1].facts.displayName == capture.devices[1].displayName)
  }

  @Test("Stage events drive the cards; a repeated degradation is shown once")
  func stagesAndDegradations() {
    let session = ScanSession()
    session.start(ScanRequest(ports: .newHosts))
    let degradation = Degradation(stage: .naming, reason: "x", recoverable: false)
    session.apply([
      .stageStarted(.discovery), .stageProgress(.discovery, completed: 1, total: 4),
    ])
    #expect(session.stageStates[.discovery] == .running(fraction: 0.25))
    session.apply([
      .stageFinished(StageTiming(stage: .discovery, elapsedMillis: 1)), .stageStarted(.naming),
      .degraded(degradation), .degraded(degradation),
    ])
    #expect(session.stageStates[.discovery] == .done)
    #expect(session.currentStageNumber == 2)
    #expect(session.degradations == [degradation])
    #expect(session.isNamingPending)
  }

  @Test("Done: the session hands back on its own")
  func handsBack() async {
    let session = ScanSession()
    session.start(ScanRequest())
    let runner = FixtureScanRunner(store: InMemoryHistoryStore(), capture: capture, variant: .home, pace: .zero, clock: ContinuousClock())
    _ = await session.run(with: ScanPipeline(runner: runner))
    #expect(session.phase == .idle)
    #expect(session.runToken == nil)
  }

  @Test("Stopped: what had answered is kept, counted, and no name is claimed to be in flight")
  func stoppedKeepsResults() async {
    let session = ScanSession()
    session.start(ScanRequest())
    // A second a host: the whole scan takes about 13 s, so the stop always lands mid-scan.
    // At 300 ms, on CI with the scale tests holding the main actor, the scan had finished
    // before this test was next scheduled, and there was nothing left to stop.
    let runner = FixtureScanRunner(store: InMemoryHistoryStore(), capture: capture, variant: .home, pace: .seconds(1), clock: ContinuousClock())
    let scan = Task { await session.run(with: ScanPipeline(runner: runner)) }
    // Until something has answered, not a fixed 250 ms: with the scale tests running beside
    // it, a fixed wait sometimes stopped the scan before the first host (phase 3, part 6).
    let deadline = ContinuousClock.now + .seconds(12)
    while session.found.isEmpty, ContinuousClock.now < deadline {
      try? await Task.sleep(for: .milliseconds(10))
    }
    scan.cancel()
    _ = await scan.value
    guard case .stopped(_, let found) = session.phase else {
      Issue.record("not stopped: \(session.phase)")
      return
    }
    #expect(found > 0 && found < capture.devices.count, "stopped after \(found) of \(capture.devices.count)")
    #expect(session.found.count == found)
    #expect(!session.isNamingPending)
  }

  /// Gate: coalescing, through the view model. The pipeline gate proves batches; this
  /// proves the screen's model sees display-rate batches and every device.
  @Test("Fed far faster than 60 Hz, the session publishes at display rate and loses no device")
  func coalescesIntoTheViewModel() async {
    let hosts = 50_000
    let events = (0..<hosts).map { ProbeEvent.hostFound(HostFacts(ip: IPv4Address(raw: 0x0A00_0000 + UInt32($0)))) }
    let session = ScanSession()
    session.start(ScanRequest())
    let clock = ContinuousClock()
    let started = clock.now
    _ = await session.run(with: ScanPipeline(runner: ProbeRunner(events: events, over: .milliseconds(400))))
    let elapsed = clock.now - started
    let frames = Int((elapsed / .milliseconds(16)).rounded(.up))
    #expect(Set(session.found.map(\.id)).count == hosts)
    // Emission takes 0.4 s. A batch that costs more than it took to arrive is a frame-time
    // tail moved inside the batch: an earlier `apply` was quadratic and took 88 s here.
    #expect(elapsed < Budget.of(.seconds(3)), "applying \(hosts) hosts took \(elapsed)")
    #expect(session.publishedBatches <= frames + 2, "\(session.publishedBatches) batches over \(frames) frames")
  }
}
