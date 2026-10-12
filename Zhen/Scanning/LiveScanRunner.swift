import Foundation
import ZhenCore
import ZhenScan

/// What `LiveScanRunner` needs from an engine: zhen-core's `ScanRunner`, or a stand-in in a
/// test that counts how often one is built.
nonisolated protocol ScanEngine: Sendable {
  var interface: NetworkInterface { get }
  func run(network: IPv4Network?, budget: Duration, deepScan: Bool, progress: ProgressSink) async -> CompletedScan
}

extension ScanRunner: ScanEngine {}

/// The real network, through zhen-core's `ScanRunner`.
///
/// Core decides at construction whether the helper's capture device is there, and which
/// interface to go out of. A runner kept for the app's lifetime meant installing the helper
/// did nothing until a relaunch (phase 3, stage 1). Rebuilt per scan, though, every scan
/// paid for the helper check: 0.7 ms with no helper, 3.2 s with a registration that does
/// not answer — core's connection timeout, measured on this Mac (ledger). So an engine is
/// kept until the helper's state changes, or a scan finds nothing, which is what a moved
/// network looks like.
actor LiveScanRunner: ScanRunning {
  /// Builds an engine over a store.
  typealias Factory = @Sendable (any HistoryStore) async throws(PlatformError) -> any ScanEngine

  private let store: any HistoryStore
  private let make: Factory
  /// The engines in use, each built when first needed: one that records runs, one that
  /// only probes (see `ProbeOnlyStore`).
  private var engines: [Bool: any ScanEngine] = [:]
  /// The helper's state, and the networks this Mac was on, when they were built.
  private var builtFor: HelperState?
  private var builtOn: String?

  init(store: any HistoryStore, make: @escaping Factory = { store throws(PlatformError) in try await ScanRunner(store: store) }) {
    self.store = store
    self.make = make
  }

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    do {
      let engine = try await prepared(recording: request.records)
      let scan = await engine.run(
        network: request.network, budget: request.budget, deepScan: request.deepScan,
        progress: progress
      )
      if scan.report.devices.isEmpty { engines = [:] }
      return .finished(scan)
    } catch {
      let degradation = Degradation(
        stage: .setup,
        reason: "No network interface could be used for scanning (\(error)). Connect to a network and scan again.",
        recoverable: true
      )
      progress(.degraded(degradation))
      return .unavailable(degradation)
    }
  }

  /// Says what the helper's state is now. A change since the engines were built means
  /// the next scan builds new ones, which see the helper as it is.
  ///
  /// The same for the networks: an engine built on one network scans that network, so a
  /// move to another — `network`, from `NetworkFingerprint` — means a fresh one.
  func note(_ helper: HelperState, network: String = NetworkFingerprint.current()) {
    if builtFor != helper || builtOn != network { engines = [:] }
    builtFor = helper
    builtOn = network
  }

  /// The interface this Mac would scan from, for the sidebar footer and Settings.
  func interface() async -> NetworkInterface? {
    try? await prepared(recording: true).interface
  }

  /// Builds in flight, so two callers arriving together — `load()` asking for the
  /// interface and a scan from a Shortcut, at launch — share one build instead of paying
  /// the helper check twice (review, part 7).
  private var building: [Bool: Task<any ScanEngine, any Error>] = [:]

  private func prepared(recording: Bool) async throws(PlatformError) -> any ScanEngine {
    if let engine = engines[recording] { return engine }
    let task = building[recording] ?? Task { [make, store] in
      try await make(recording ? store : ProbeOnlyStore(base: store))
    }
    building[recording] = task
    defer { building[recording] = nil }
    do {
      let made = try await task.value
      engines[recording] = made
      return made
    } catch let error as PlatformError {
      throw error
    } catch {
      throw PlatformError.unavailable(String(describing: error))
    }
  }
}
