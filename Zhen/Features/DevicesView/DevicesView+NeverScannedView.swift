import SwiftUI

extension DevicesView {
  /// Before the first scan.
  struct NeverScannedView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      ContentUnavailableView {
        Label(String(localized: .noScanYet), systemImage: "dot.radiowaves.left.and.right")
      } description: {
        Text(.runScanSeeWhatsYourNetwork)
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
