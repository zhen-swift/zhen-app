import Foundation
import ZhenCore
import ZhenScan

/// The real network, through zhen-core's `ScanRunner`.
///
/// An actor because the runner is built once and kept: building it raises the descriptor
/// limit and reads the interface list, neither of which should happen per scan.
actor LiveScanRunner: ScanRunning {
  private let store: any HistoryStore
  private var runner: ScanRunner?

  init(store: any HistoryStore) {
    self.store = store
  }

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    do {
      let runner = try await prepared()
      return .finished(await runner.run(
        network: request.network, budget: request.budget, deepScan: request.deepScan,
        progress: progress
      ))
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

  /// The interface this Mac would scan from, for the sidebar footer and Settings.
  func interface() async -> NetworkInterface? {
    try? await prepared().interface
  }

  private func prepared() async throws(PlatformError) -> ScanRunner {
    if let runner { return runner }
    let made = try await ScanRunner(store: store)
    runner = made
    return made
  }
}
