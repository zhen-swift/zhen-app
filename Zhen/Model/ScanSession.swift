import Foundation
import Observation
import ZhenCore
import ZhenScan

/// A scan as it happens: which stage is running, what has answered, what has degraded.
///
/// Fed by `ScanPipeline` in display-rate batches, never per event. Its lifetime is the
/// `.task(id: runToken)` on the window: clearing the token cancels the task, cancellation
/// reaches the engine, the sockets close, and whatever had answered is kept.
@Observable
final class ScanSession {
  /// Where the scan is.
  enum Phase: Equatable {
    /// No scan: Devices shows the table.
    case idle
    /// Running: Devices shows this session.
    case running
    /// Stopped by the person: the partial results stay on screen until they move on.
    case stopped(after: Duration, found: Int)
  }

  /// One stage card.
  enum StageState: Equatable {
    case queued
    case running(fraction: Double?)
    case done
    /// Not part of this scan: deep scan when it was not asked for.
    case skipped
  }

  /// A host that has answered this scan.
  struct FoundHost: Identifiable, Equatable {
    var id: IPv4Address { facts.ip }
    var facts: HostFacts
    var foundAt: Date
  }

  static let stages: [Stage] = [.discovery, .naming, .deepScan]

  private(set) var phase: Phase = .idle
  /// The task key. A new value starts a scan; nil cancels the one running.
  private(set) var runToken: UUID?
  private(set) var request = ScanRequest()
  private(set) var startedAt: Date?
  private(set) var finishedAt: Date?
  private(set) var stageStates: [Stage: StageState] = [:]
  /// How long each finished stage took, as core measured it.
  private(set) var stageDurations: [Stage: Duration] = [:]
  /// Hosts in the order they answered, and where each one is. Kept oldest-first so an
  /// arrival is an append and an update a lookup: newest-first storage made every batch
  /// re-index every row, and 50 000 hosts took 88 s to apply (`ScanSessionTests`).
  private(set) var arrivals: [FoundHost] = []
  @ObservationIgnored private var positions: [IPv4Address: Int] = [:]

  /// Newest first, as the screen lists them.
  var found: [FoundHost] { arrivals.reversed() }
  private(set) var degradations: [Degradation] = []
  /// How many batches the view has been handed. The coalescing gate reads it.
  private(set) var publishedBatches = 0

  var isRunning: Bool { phase == .running }

  /// The stage running now, counted from one, for "Stage 2 of 3".
  var currentStageNumber: Int {
    let index = Self.stages.lastIndex { stageStates[$0] != .queued && stageStates[$0] != .skipped } ?? 0
    return index + 1
  }

  /// Whether a host with no name yet may still get one. Never once the scan has stopped:
  /// nothing is in flight then, and "Resolving name…" would be a claim about work that
  /// is not happening.
  var isNamingPending: Bool {
    guard phase == .running else { return false }
    switch stageStates[.naming] {
    case .queued, .running: return true
    default: return false
    }
  }

  /// Asks for a scan. The window's task picks it up.
  func start(_ request: ScanRequest) {
    guard phase != .running else { return }
    self.request = request
    phase = .running
    startedAt = .now
    finishedAt = nil
    arrivals = []
    positions = [:]
    degradations = []
    publishedBatches = 0
    stageDurations = [:]
    stageStates = Dictionary(uniqueKeysWithValues: Self.stages.map {
      ($0, $0 == .deepScan && !request.deepScan ? .skipped : .queued)
    })
    runToken = UUID()
  }

  /// Whether a host's task is executing the scan, as opposed to the scan only having been
  /// asked for.
  private(set) var isExecuting = false

  /// Stops the running scan. What had answered stays.
  ///
  /// A scan can be asked for with no host to run it — ⌘R with the window closed and
  /// Settings open, menu bar mode off. Stopping that one has no task to unwind it, so it
  /// returns to idle here; it used to stay "running" until a relaunch (review, part 7).
  func stop() {
    guard phase == .running else { return }
    runToken = nil
    if !isExecuting { phase = .idle }
  }

  /// Leaves a stopped scan's results and goes back to the table.
  func dismiss() {
    guard case .stopped = phase else { return }
    phase = .idle
  }

  /// Runs the requested scan to its end, publishing batches as they come.
  /// Returns what it produced, and whether it ran to completion or was stopped.
  func run(with pipeline: ScanPipeline) async -> ScanOutcome {
    isExecuting = true
    defer { isExecuting = false }
    let outcome = await pipeline.run(request) { [weak self] batch in
      self?.apply(batch)
    }
    finishedAt = .now
    let stopped: Bool
    if case .finished(let scan) = outcome {
      stopped = scan.report.run.outcome == .cancelled
      degradations = scan.report.degradations
    } else {
      stopped = false
    }
    if stopped {
      phase = .stopped(after: elapsed(at: finishedAt ?? .now), found: arrivals.count)
    } else {
      // Hand back to Devices. Its degradations go with it: the model keeps them.
      phase = .idle
    }
    runToken = nil
    return outcome
  }

  /// Folds a batch of engine events into what the screen shows.
  func apply(_ batch: [ProbeEvent]) {
    publishedBatches += 1
    let now = Date.now
    for event in batch {
      switch event {
      case .stageStarted(let stage):
        stageStates[stage] = .running(fraction: nil)
      case .stageProgress(let stage, let completed, let total):
        if total > 0 { stageStates[stage] = .running(fraction: Double(completed) / Double(total)) }
      case .stageFinished(let timing):
        stageStates[timing.stage] = .done
        stageDurations[timing.stage] = .milliseconds(timing.elapsedMillis)
      case .hostFound(let facts), .hostUpdated(let facts):
        if let at = positions[facts.ip] {
          arrivals[at].facts = facts
        } else {
          positions[facts.ip] = arrivals.count
          arrivals.append(FoundHost(facts: facts, foundAt: now))
        }
      case .degraded(let degradation):
        if !degradations.contains(degradation) { degradations.append(degradation) }
      }
    }
  }

  func elapsed(at date: Date) -> Duration {
    guard let startedAt else { return .zero }
    return .seconds(max(0, date.timeIntervalSince(startedAt)))
  }
}
