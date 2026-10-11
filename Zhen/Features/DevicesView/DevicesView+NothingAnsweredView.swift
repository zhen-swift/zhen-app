import SwiftUI

extension DevicesView {
  /// A scan ran and nothing replied. Usually the Local Network permission, so this says so
  /// and opens the pane — an empty list with no explanation is the likeliest way a new user
  /// decides the app is broken.
  struct NothingAnsweredView: View {
    @Environment(NetworkModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
      VStack(spacing: .spacing.large) {
        ContentUnavailableView {
          Label("Nothing answered", systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
          Text("The scan completed but no devices replied. This usually means the Local Network permission is denied.")
        } actions: {
          Button("Open System Settings…") {
            if let url = SystemSettings.localNetwork { openURL(url) }
          }
          .accessibilityIdentifier("openLocalNetworkSettingsButton")
          Button("Scan Again") { model.startScan() }
            .accessibilityIdentifier("scanAgainButton")
        }
        if !model.lastDegradations.isEmpty {
          DegradationBanner(degradations: model.lastDegradations) { model.startScan() }
            .padding(.horizontal, .spacing.xLarge)
            .padding(.bottom, .spacing.xLarge)
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("nothingAnswered")
    }
  }
}
