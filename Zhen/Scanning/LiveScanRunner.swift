import Foundation
import ZhenCore
// For `CapturePolicy`, which `ScanRunner`'s initialiser takes and ZhenDarwin defines.
import ZhenDarwin
import ZhenScan

/// What `LiveScanRunner` needs from an engine: zhen-core's `ScanRunner`, or a stand-in in a
/// test.
nonisolated protocol ScanEngine: Sendable {
  var interface: NetworkInterface { get }
  func run(network: IPv4Network?, budget: Duration, ports: PortStage, progress: ProgressSink) async -> CompletedScan
  func probePorts(_ addresses: [IPAddress], spec: PortSpec, budget: Duration, progress: ProgressSink) async -> CompletedPortScan
}

extension ScanRunner: ScanEngine {}

/// The real network, through zhen-core's `ScanRunner`.
///
/// An engine is built for each scan, against the helper and the network as they are then.
/// It used to be kept between scans, because building one paid for the helper check —
/// 3.2 s on a registration that never answers — and keeping it meant a second engine for
/// port probes (over a store that refused to record) and a cache keyed by helper state and
/// network. zhen-core 0.7.0 bounds that check, a port probe is a call of its own, and a
/// helper this app has not installed is not asked at all, so none of that is left to keep.
actor LiveScanRunner: ScanRunning {
  /// Builds an engine over a store; the flag says whether it may ask the helper for a
  /// capture device.
  typealias Factory = @Sendable (any HistoryStore, Bool) async throws(PlatformError) -> any ScanEngine

  private let store: any HistoryStore
  private let make: Factory
  /// Whether the next engine may ask the helper.
  private var asksHelper = false

  init(
    store: any HistoryStore,
    make: @escaping Factory = { store, asksHelper throws(PlatformError) in
      // `.fromEnvironment` keeps `ZHEN_CAPTURE=direct`, the baseline `verify-helper.sh`
      // compares against; `.directOnly` never contacts a helper at all.
      try await ScanRunner(store: store, capture: asksHelper ? .fromEnvironment : .directOnly)
    }
  ) {
    self.store = store
    self.make = make
  }

  /// Says what the helper's state is now, so the next engine asks it only when it can
  /// answer. A helper that is not installed, or is waiting for approval, is never
  /// contacted: an unapproved registration accepts the connection and never replies.
  func note(_ helper: HelperState) {
    asksHelper = helper == .installed
  }

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    do {
      let engine = try await make(store, asksHelper)
      return .finished(await engine.run(
        network: request.network, budget: request.budget, ports: request.ports, progress: progress
      ))
    } catch {
      let degradation = Self.noInterface(error)
      progress(.degraded(degradation))
      return .unavailable(degradation)
    }
  }

  func probePorts(_ request: PortProbeRequest, progress: ProgressSink) async -> PortProbeOutcome {
    do {
      let engine = try await make(store, asksHelper)
      return .finished(await engine.probePorts(
        request.addresses, spec: .commonServices, budget: request.budget, progress: progress
      ))
    } catch {
      return .unavailable(Self.noInterface(error))
    }
  }

  /// The interface this Mac would scan from, for the sidebar footer and Settings.
  func interface() async -> NetworkInterface? {
    try? await make(store, asksHelper).interface
  }

  private static func noInterface(_ error: PlatformError) -> Degradation {
    Degradation(
      stage: .setup,
      reason: "No network interface could be used for scanning (\(error)). Connect to a network and scan again.",
      recoverable: true
    )
  }
}
