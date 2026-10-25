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
          Label(String(localized: .nothingAnswered), systemImage: "antenna.radiowaves.left.and.right.slash")
            .foregroundStyle(.textSecondary)
        } description: {
          Text(.scanCompletedButNoDevicesReplied)
            .foregroundStyle(.textSecondary)
        } actions: {
          Button(String(localized: .openSystemSettings)) {
            if let url = SystemSettings.localNetwork { openURL(url) }
          }
          .accessibilityIdentifier("openLocalNetworkSettingsButton")
          Button(String(localized: .scanAgain)) { model.startScan() }
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
