import Foundation
import ZhenCore
// For `CapturePolicy`, which `ScanRunner`'s initialiser takes and ZhenDarwin defines.
import ZhenDarwin
import ZhenScan

/// What `LiveScanRunner` needs from an engine: zhen-core's `ScanRunner`, or a stand-in in a
/// test.
nonisolated protocol ScanEngine: Sendable {
  var interface: NetworkInterface { get }
  /// Reads the router the interface is behind: what a network's history is keyed by.
  var gateway: any GatewayResolving { get }
  /// The same engine, recording into another store: the history of the network a scan
  /// turned out to be on, known only once the gateway is read.
  func engine(recordingInto store: any HistoryStore) -> any ScanEngine
  func run(network: IPv4Network?, budget: Duration, ports: PortStage, progress: ProgressSink) async -> CompletedScan
  func probePorts(_ addresses: [IPAddress], spec: PortSpec, budget: Duration, progress: ProgressSink) async -> CompletedPortScan
}

// `nonisolated`: the app target is main-actor by default, and the engine runs off it.
nonisolated extension ScanRunner: ScanEngine {
  func engine(recordingInto store: any HistoryStore) -> any ScanEngine {
    recording(into: store)
  }

  // zhen-core 0.8.0 added `reach` and `settings`, with defaults a protocol cannot name.
  func run(network: IPv4Network?, budget: Duration, ports: PortStage, progress: ProgressSink) async -> CompletedScan {
    await run(network: network, budget: budget, ports: ports, progress: progress, reach: .default)
  }
}

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

  /// Chooses the store a scan records into, once its network is known.
  typealias Chooser = @Sendable (NetworkIdentity) async -> any HistoryStore

  /// The current network's store: what port probes record into, and every scan when there
  /// is no chooser.
  private var store: any HistoryStore
  private let make: Factory
  /// Whether the next engine may ask the helper.
  private var asksHelper = false
  /// Set by the model: each network has its own history (zhen-core 0.10.0).
  private var chooser: Chooser?

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

  /// Says how to choose the store for a network a scan is on.
  func choose(with chooser: @escaping Chooser) {
    self.chooser = chooser
  }

  /// Says which store is the current network's.
  func use(_ store: any HistoryStore) {
    self.store = store
  }

  /// The network this Mac is on now, and the interface it is on.
  ///
  /// Read with the helper as it stands: until it is installed and noted, nothing but the
  /// neighbour cache is read, which macOS 27 shows an unprivileged app as empty, and the
  /// answer is the subnet alone. `NetworkHistories` then finds the subnet's latest history.
  func currentNetwork() async -> (identity: NetworkIdentity, interface: NetworkInterface)? {
    guard let engine = try? await make(store, asksHelper) else { return nil }
    let interface = engine.interface
    let identity = await engine.gateway.identity(scanning: interface.network, on: interface)
    return (identity, interface)
  }

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    do {
      var engine = try await make(store, asksHelper)
      // The gateway is read through the engine that runs the scan, so through the helper's
      // capture device when it has one, the way `zhen scan` reads it.
      if let chooser {
        let identity = await engine.gateway.identity(
          scanning: request.network ?? engine.interface.network, on: engine.interface
        )
        let chosen = await chooser(identity)
        store = chosen
        engine = engine.engine(recordingInto: chosen)
      }
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
