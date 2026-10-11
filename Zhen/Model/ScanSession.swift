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
  /// Newest first.
  private(set) var found: [FoundHost] = []
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
    found = []
    degradations = []
    publishedBatches = 0
    stageStates = Dictionary(uniqueKeysWithValues: Self.stages.map {
      ($0, $0 == .deepScan && !request.deepScan ? .skipped : .queued)
    })
    runToken = UUID()
  }

  /// Stops the running scan. What had answered stays.
  func stop() {
    guard phase == .running else { return }
    runToken = nil
  }

  /// Leaves a stopped scan's results and goes back to the table.
  func dismiss() {
    guard case .stopped = phase else { return }
    phase = .idle
  }

  /// Runs the requested scan to its end, publishing batches as they come.
  /// Returns what it produced, and whether it ran to completion or was stopped.
  func run(with pipeline: ScanPipeline) async -> ScanOutcome {
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
      phase = .stopped(after: elapsed(at: finishedAt ?? .now), found: found.count)
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
    let index = Dictionary(uniqueKeysWithValues: found.enumerated().map { ($0.element.id, $0.offset) })
    var arrivals: [FoundHost] = []
    for event in batch {
      switch event {
      case .stageStarted(let stage):
        stageStates[stage] = .running(fraction: nil)
      case .stageProgress(let stage, let completed, let total):
        if total > 0 { stageStates[stage] = .running(fraction: Double(completed) / Double(total)) }
      case .stageFinished(let timing):
        stageStates[timing.stage] = .done
      case .hostFound(let facts), .hostUpdated(let facts):
        if let at = index[facts.ip] {
          found[at].facts = facts
        } else if let pending = arrivals.firstIndex(where: { $0.id == facts.ip }) {
          arrivals[pending].facts = facts
        } else {
          arrivals.append(FoundHost(facts: facts, foundAt: .now))
        }
      case .degraded(let degradation):
        if !degradations.contains(degradation) { degradations.append(degradation) }
      }
    }
    if !arrivals.isEmpty { found.insert(contentsOf: arrivals.reversed(), at: 0) }
  }

  func elapsed(at date: Date) -> Duration {
    guard let startedAt else { return .zero }
    return .seconds(max(0, date.timeIntervalSince(startedAt)))
  }
}
