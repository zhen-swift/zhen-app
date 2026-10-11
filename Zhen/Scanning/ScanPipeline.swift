import Foundation
import Synchronization
import ZhenCore
import ZhenScan

/// The app's adapter over a scanner: runs it off the main actor, and hands the main actor
/// its progress in display-rate batches.
///
/// **Why this type is `nonisolated` and its `run` is `@concurrent`.** The app target is
/// main-actor by default, and with approachable concurrency a plain `nonisolated async`
/// function runs on its caller's actor. Without `@concurrent`, a scan started from a view
/// would run every socket helper on the main actor — it compiles, it runs, and the scan is
/// quietly serialised behind the window. `ScanPipelineTests` constructs this type from a
/// synchronous nonisolated context (so marking it `@MainActor` stops the tests compiling)
/// and asserts the scanner ran off the main thread (so removing `@concurrent` fails them).
///
/// **Why it coalesces.** The engine emits far faster than 60 Hz. Each event hopping to the
/// main actor on its own is an unbounded queue in front of SwiftUI, and an unbounded queue
/// is a frame-time tail. Events land in a buffer here; a ticker drains it once per
/// `interval`, so the main actor sees at most one batch per frame and never a dropped event.
nonisolated struct ScanPipeline: Sendable {
  let runner: any ScanRunning
  /// How often a batch is published. A display frame.
  let interval: Duration
  let clock: any Clock<Duration>

  init(runner: any ScanRunning, interval: Duration = .milliseconds(16), clock: any Clock<Duration> = ContinuousClock()) {
    self.runner = runner
    self.interval = interval
    self.clock = clock
  }

  /// Runs one scan. `publish` is called on the main actor with each batch, in order, and
  /// once more with whatever is left when the scan ends; the outcome is returned after
  /// the last batch has been published.
  @concurrent
  func run(
    _ request: ScanRequest,
    publish: @escaping @MainActor @Sendable ([ProbeEvent]) -> Void
  ) async -> ScanOutcome {
    let buffer = EventBuffer()
    let sink = ProgressSink { event in buffer.append(event) }
    let interval = interval
    let clock = clock
    let runner = runner

    return await withTaskGroup(of: ScanOutcome?.self) { group in
      group.addTask {
        while !Task.isCancelled {
          do { try await clock.sleep(for: interval) } catch { break }
          let batch = buffer.drain()
          if !batch.isEmpty { await publish(batch) }
        }
        return nil
      }
      let outcome = await runner.run(request, progress: sink)
      // Stop the ticker and wait for it, so the last batch cannot overtake one in flight.
      group.cancelAll()
      while let _ = await group.next() {}
      let rest = buffer.drain()
      if !rest.isEmpty { await publish(rest) }
      return outcome
    }
  }
}

/// Events between two ticks. A class only because `Mutex` cannot be captured by the
/// escaping sink closure; the lock is what makes it `Sendable`, no annotation needed.
nonisolated final class EventBuffer: Sendable {
  private let pending = Mutex<[ProbeEvent]>([])

  func append(_ event: ProbeEvent) {
    pending.withLock { $0.append(event) }
  }

  func drain() -> [ProbeEvent] {
    pending.withLock { events in
      defer { events.removeAll(keepingCapacity: true) }
      return events
    }
  }
}
