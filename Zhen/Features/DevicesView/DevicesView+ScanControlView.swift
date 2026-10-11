import SwiftUI

extension DevicesView {
  /// Scan Now, or Stop Scan while one runs. The room's one prominent action.
  struct ScanControlView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      if model.scan.isRunning {
        Button("Stop Scan", systemImage: "stop.fill") { model.scan.stop() }
          .help("Stop the scan. Devices found so far are kept.")
          .accessibilityIdentifier("stopScanButton")
      } else {
        PrimaryButton("Scan Now", systemImage: "dot.radiowaves.left.and.right", identifier: "scanNowButton") {
          model.startScan()
        }
        .help("Scan the network now")
      }
    }
  }
}
