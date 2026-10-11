import Foundation
import ZhenCore
import ZhenScan

/// A scanner that replays the fixture network instead of probing one.
///
/// Used under `-UITesting` and `-ShowcaseData`, so a test can watch a whole scan — hosts
/// streaming in, names resolving, a degradation arriving, the hand-back — without a network
/// and without ever touching the history file.
nonisolated struct FixtureScanRunner: ScanRunning {
  let store: any HistoryStore
  let capture: ScanReport
  let variant: FixtureNetwork.Variant
  /// Time between events, so a person or a UI test can see the stream.
  let pace: Duration
  let clock: any Clock<Duration>

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    let started = Timestamp.now
    let latest = FixtureNetwork.history(variant == .empty ? .home : variant, capture: capture, now: .now).last
    let devices = latest?.devices ?? []
    let network = request.network ?? capture.run.target
    var stages: [StageTiming] = []
    var announced = 0

    progress(.stageStarted(.discovery))
    for (index, device) in devices.enumerated() {
      guard await pause() else { break }
      progress(.hostFound(Self.facts(device, named: false)))
      announced += 1
      progress(.stageProgress(.discovery, completed: index + 1, total: devices.count))
    }
    stages.append(StageTiming(stage: .discovery, elapsedMillis: Self.elapsed(since: started)))
    progress(.stageFinished(stages[stages.count - 1]))

    let degradations = FixtureNetwork.degradations(variant, capture: capture)
    if !Task.isCancelled, !devices.isEmpty {
      progress(.stageStarted(.naming))
      for degradation in degradations where degradation.stage != .discovery { progress(.degraded(degradation)) }
      for device in devices where !device.names.isEmpty {
        guard await pause() else { break }
        progress(.hostUpdated(Self.facts(device, named: true)))
      }
      stages.append(StageTiming(stage: .naming, elapsedMillis: Self.elapsed(since: started)))
      progress(.stageFinished(stages[stages.count - 1]))
    }
    for degradation in degradations where degradation.stage == .discovery { progress(.degraded(degradation)) }

    if request.deepScan, !Task.isCancelled, !devices.isEmpty {
      progress(.stageStarted(.deepScan))
      _ = await pause()
      stages.append(StageTiming(stage: .deepScan, elapsedMillis: Self.elapsed(since: started)))
      progress(.stageFinished(stages[stages.count - 1]))
    }

    let finished = Timestamp.now
    var run = capture.run
    run.id = UUID()
    run.target = network
    run.startedAt = started
    run.finishedAt = finished
    run.outcome = Task.isCancelled ? .cancelled : (variant == .partial ? .deadlineExpired : .complete)
    run.timing = Timing(stages: stages, counters: ProbeCounterSnapshot(probesSent: 0, repliesSeen: 0, peakConcurrency: 0, inFlight: 0))
    // Stopped: what had answered is kept. Nothing is discarded because someone pressed stop.
    let found = Array(devices.prefix(announced))
    let report = ScanReport(
      run: run,
      devices: found.map { device in
        var seen = device
        seen.lastSeen = finished
        return seen
      },
      degradations: degradations
    )
    let events = await store.record(report)
    return .finished(CompletedScan(report: report, events: events))
  }

  /// Waits one beat. False when the scan was stopped.
  private func pause() async -> Bool {
    do {
      try await clock.sleep(for: pace)
      return true
    } catch {
      return false
    }
  }

  private static func elapsed(since start: Timestamp) -> Double {
    Double(Timestamp.now.millisecondsSinceEpoch - start.millisecondsSinceEpoch)
  }

  /// What discovery knows about a device (address, hardware, round trip), and, once named,
  /// what naming adds.
  static func facts(_ device: Device, named: Bool) -> HostFacts {
    HostFacts(
      ip: device.ipv4Addresses.first ?? IPv4Address(raw: 0),
      mac: device.mac,
      allNames: named ? device.names : [],
      vendor: device.vendor,
      ttl: device.ttl,
      rtt: device.rtt,
      discoveredVia: Set(device.discoveredVia)
    )
  }
}
