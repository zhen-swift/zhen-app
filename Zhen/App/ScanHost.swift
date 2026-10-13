import SwiftUI

/// The tasks that run scans and keep history current, on whichever view is the one host.
///
/// A scan runs from a view's `.task(id: scan.runToken)`, so cancelling it is a matter of
/// the view going away, and the sockets close with it (house rules: `.task(id:)` owns
/// stream lifetime). That made the window the scanner, and closing it the end of watching.
/// With "Keep watching from the menu bar" on, the menu bar item hosts them instead — it
/// lives as long as the app does. Exactly one host is active at a time: two would run every
/// scan twice, the defect stage 3 removed with the single `Window`.
struct ScanHost: ViewModifier {
  let model: NetworkModel
  let isActive: Bool
  @AppStorage(Preferences.Key.scanInterval) private var scanInterval = 0

  func body(content: Content) -> some View {
    content
      .task(id: Key(active: isActive, token: model.scan.runToken)) {
        if isActive { await model.performScan() }
      }
      .task(id: Key(active: isActive, token: model.portScanTarget)) {
        if isActive { await model.performPortScan() }
      }
      .task(id: isActive) {
        if isActive { await model.watchHistory() }
      }
      .task(id: Key(active: isActive, token: scanInterval)) {
        if isActive { await model.scanAutomatically(every: scanInterval) }
      }
  }

  /// A task key that also changes when the host does, so handing over cancels the old one.
  private struct Key<Token: Hashable>: Hashable {
    let active: Bool
    let token: Token
  }
}

extension View {
  /// Runs scans, port scans, the history watch and automatic scans here, when `isActive`.
  func scanHost(_ model: NetworkModel, isActive: Bool) -> some View {
    modifier(ScanHost(model: model, isActive: isActive))
  }
}
