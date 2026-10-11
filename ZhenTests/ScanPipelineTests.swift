import Darwin
import Foundation
import Synchronization
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// A scanner that does nothing but say where it ran and emit what it is told to.
nonisolated final class ProbeRunner: ScanRunning {
  let ranOnMainThread = Mutex<Bool?>(nil)
  let events: [ProbeEvent]
  /// Emit everything this long, spread evenly.
  let over: Duration

  init(events: [ProbeEvent] = [], over: Duration = .zero) {
    self.events = events
    self.over = over
  }

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    ranOnMainThread.withLock { $0 = pthread_main_np() != 0 }
    let clock = ContinuousClock()
    let start = clock.now
    for (index, event) in events.enumerated() {
      progress(event)
      // Pace in chunks so the stream spans `over`, far faster than 60 Hz per event.
      if over > .zero, index.isMultiple(of: 1_000) {
        let due = start + over * (Double(index) / Double(max(events.count, 1)))
        try? await clock.sleep(until: due)
      }
    }
    return .unavailable(Degradation(stage: .setup, reason: "probe", recoverable: true))
  }
}

/// Wraps the app's own fixture scanner and counts progress events emitted on the main thread.
/// The sink is called synchronously from inside the scanner, so where it runs is where the
/// scanner runs.
nonisolated final class ThreadRecordingRunner: ScanRunning {
  let inner: FixtureScanRunner
  let onMain = Mutex(0)
  let total = Mutex(0)

  init(_ inner: FixtureScanRunner) { self.inner = inner }

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    await inner.run(request, progress: ProgressSink { [self] event in
      total.withLock { $0 += 1 }
      if pthread_main_np() != 0 { onMain.withLock { $0 += 1 } }
      progress(event)
    })
  }
}

/// Gate: scan stays off the main actor.
///
/// Two halves, each shown failing on a deliberate break (ledger, stage A):
///  * compile time — `makePipeline` is a synchronous `nonisolated` function constructing
///    the adapter. Mark `ScanPipeline` `@MainActor` (or drop its `nonisolated`, which in this
///    target means the same) and this file stops compiling.
///  * run time — driven from the main actor, the app's own scanner must emit every event
///    off the main thread. Make it hop (`await MainActor.run { progress(…) }` in
///    `FixtureScanRunner`) and this test fails.
///
/// Two breaks that do NOT fail it, measured (ledger, stage A), because something else
/// already holds the line: dropping `@concurrent` from the pipeline (`withTaskGroup`'s body
/// runs off the caller's actor anyway), and dropping `nonisolated` from `FixtureScanRunner`
/// (a type that states `Sendable` does not take the target's MainActor default).
@MainActor
struct ScanPipelineTests {
  nonisolated static func makePipeline(_ runner: some ScanRunning, interval: Duration = .milliseconds(16)) -> ScanPipeline {
    ScanPipeline(runner: runner, interval: interval, clock: ContinuousClock())
  }

  @Test("Driven from the main actor, the scanner runs off the main thread")
  func scannerRunsOffMain() async throws {
    let runner = ProbeRunner()
    _ = await Self.makePipeline(runner).run(ScanRequest()) { _ in }
    #expect(runner.ranOnMainThread.withLock { $0 } == false)

    let fixture = FixtureScanRunner(
      store: InMemoryHistoryStore(), capture: try FixtureNetwork.capture(), variant: .home,
      pace: .zero, clock: ContinuousClock()
    )
    let recording = ThreadRecordingRunner(fixture)
    _ = await Self.makePipeline(recording).run(ScanRequest(deepScan: true)) { _ in }
    #expect(recording.total.withLock { $0 } > 10)
    #expect(recording.onMain.withLock { $0 } == 0, "the app's scanner emitted on the main thread")
  }

  /// Gate: coalescing. 100 000 events in about half a second is ~200 000 per second, three
  /// orders of magnitude past a display. The main actor must see roughly one batch per
  /// frame, and every device.
  @Test("Events far faster than 60 Hz arrive at display rate, none lost")
  func coalescesToDisplayRate() async {
    let hosts = 100_000
    let events = (0..<hosts).map { ProbeEvent.hostFound(HostFacts(ip: IPv4Address(raw: 0x0A00_0000 + UInt32($0)))) }
    let runner = ProbeRunner(events: events, over: .milliseconds(500))
    let pipeline = Self.makePipeline(runner, interval: .milliseconds(16))
    let collector = Collector()
    let clock = ContinuousClock()
    let started = clock.now
    _ = await pipeline.run(ScanRequest()) { batch in collector.take(batch) }
    let batches = collector.batches
    let seen = collector.seen
    let elapsed = clock.now - started
    let frames = Int((elapsed / .milliseconds(16)).rounded(.up))
    #expect(seen.count == hosts, "lost \(hosts - seen.count) devices")
    // At most one batch per tick, plus the final flush.
    #expect(batches <= frames + 2, "\(batches) batches in \(elapsed) — more than one per frame (\(frames))")
    #expect(batches >= 2, "everything arrived in one batch: nothing streamed")
  }
}

/// What the main actor was handed.
@MainActor
final class Collector {
  var batches = 0
  var seen = Set<IPv4Address>()

  func take(_ batch: [ProbeEvent]) {
    batches += 1
    for case .hostFound(let facts) in batch { seen.insert(facts.ip) }
  }
}
