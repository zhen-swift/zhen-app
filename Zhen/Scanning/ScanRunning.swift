import Foundation
import ZhenCore
import ZhenScan

/// What a scan was asked to do.
nonisolated struct ScanRequest: Sendable, Hashable {
  /// The network to scan; nil means the interface's own.
  var network: IPv4Network?
  /// Total time allowed.
  var budget: Duration = .seconds(30)
  /// Whether to probe common ports on the hosts that answered.
  var deepScan: Bool = false
}

/// How a scan ended.
nonisolated enum ScanOutcome: Sendable {
  /// It ran. Complete, cut short by its deadline, or stopped: the report says which, and
  /// carries whatever was found either way.
  case finished(CompletedScan)
  /// It could not start: no usable interface. Said as a degradation, so it reads the same
  /// way as every other reason a scan is less than complete.
  case unavailable(Degradation)
}

/// Something that can run one scan.
///
/// The seam between the app and the engine. The live conformance drives zhen-core's
/// `ScanRunner`; the fixture conformance replays the committed network. Neither is
/// main-actor isolated, and `ScanPipeline` is what keeps them off it.
nonisolated protocol ScanRunning: Sendable {
  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome
}
