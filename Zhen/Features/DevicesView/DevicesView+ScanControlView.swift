import SwiftUI

extension DevicesView {
  /// Scan Now, or Stop Scan while one runs. The room's one prominent action.
  struct ScanControlView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      if model.isBusy {
        Button(String(localized: .stopScan), systemImage: "stop.fill") { model.stopScanning() }
          .help(String(localized: .stopScanDevicesFoundSoFar))
          .accessibilityIdentifier("stopScanButton")
      } else {
        PrimaryButton(.scanNow, systemImage: "dot.radiowaves.left.and.right", identifier: "scanNowButton") {
          model.startScan()
        }
        .help(String(localized: .scanNetworkNow))
      }
    }
  }
}
