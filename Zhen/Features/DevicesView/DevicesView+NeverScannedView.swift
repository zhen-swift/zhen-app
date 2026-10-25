import SwiftUI

extension DevicesView {
  /// Before the first scan.
  struct NeverScannedView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      ContentUnavailableView {
        // The palette's secondary, not the view's own: macOS 26 draws both in the
        // system's, measured 3.95:1 on the window (`SystemAccessibilityAuditUITests`).
        Label(String(localized: .noScanYet), systemImage: "dot.radiowaves.left.and.right")
          .foregroundStyle(.textSecondary)
      } description: {
        Text(.runScanSeeWhatsYourNetwork)
          .foregroundStyle(.textSecondary)
      } actions: {
        PrimaryButton(.scanNow, systemImage: "dot.radiowaves.left.and.right", identifier: "emptyScanNowButton") {
          model.startScan()
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("neverScanned")
    }
  }
}
