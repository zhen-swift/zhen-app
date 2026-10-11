import SwiftUI
import ZhenCore

/// What went wrong in a scan, in plain language, with the action that helps.
///
/// Never a modal: these arrive mid-scan and the scan is still useful. Amber, not red:
/// nothing here is broken, the results are just less complete.
struct DegradationBanner: View {
  let degradations: [Degradation]
  let onScanAgain: () -> Void
  @Environment(\.openURL) private var openURL

  var body: some View {
    Card("Running with partial results", caption: String(localized: "results are still valid, just less complete")) {
      VStack(alignment: .leading, spacing: .zero) {
        ForEach(degradations.enumerated(), id: \.offset) { index, degradation in
          let copy = DegradationCopy(degradation)
          if index > 0 { Divider() }
          HStack(alignment: .firstTextBaseline, spacing: .spacing.medium) {
            StatusDot(.warning)
            VStack(alignment: .leading, spacing: .spacing.xxSmall) {
              Text(copy.cause)
                .font(.body.bold())
                .foregroundStyle(.textPrimary)
              Text(copy.consequence)
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: .spacing.large)
            if let action = copy.action {
              Button(action.title) { perform(action) }
                .buttonStyle(.link)
                .accessibilityIdentifier("degradationAction-\(index)")
            }
          }
          .padding(.spacing.large)
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("degradation-\(index)")
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("degradationBanner")
  }

  private func perform(_ action: DegradationCopy.Action) {
    switch action {
    case .openLocalNetworkSettings:
      if let url = SystemSettings.localNetwork { openURL(url) }
    case .scanAgain:
      onScanAgain()
    }
  }
}

extension DegradationCopy.Action {
  var title: LocalizedStringKey {
    switch self {
    case .openLocalNetworkSettings: "Open System Settings…"
    case .scanAgain: "Scan Again"
    }
  }
}

#Preview("Degradation banner — dark") {
  DegradationBanner(
    degradations: FixtureNetwork.degradations(.silent, capture: PreviewContainer.capture)
      + FixtureNetwork.degradations(.partial, capture: PreviewContainer.capture),
    onScanAgain: {}
  )
  .padding(.spacing.xLarge)
  .frame(width: .windowSize.minimumWidth)
  .background(.surface)
  .preferredColorScheme(.dark)
}
