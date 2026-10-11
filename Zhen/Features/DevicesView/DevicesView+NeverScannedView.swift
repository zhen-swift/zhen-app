import SwiftUI

extension DevicesView {
  /// Before the first scan.
  struct NeverScannedView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      ContentUnavailableView {
        Label("No scan yet", systemImage: "dot.radiowaves.left.and.right")
      } description: {
        Text("Run a scan to see what’s on your network.")
      } actions: {
        PrimaryButton("Scan Now", systemImage: "dot.radiowaves.left.and.right", identifier: "emptyScanNowButton") {
          model.startScan()
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("neverScanned")
    }
  }
}
