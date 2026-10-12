import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Every source that could name a device, everything each offered, and which won.
  /// Sources that offered nothing say so: the absence is information.
  struct KnownByCardView: View {
    let item: DeviceItem

    var body: some View {
      Card(.knownBy, caption: String(localized: .competingNamesSourceHighestTrustSource)) {
        VStack(alignment: .leading, spacing: .zero) {
          if let userName = item.userName {
            SourceRowView(source: String(localized: .you), value: userName, isWinner: true)
            Divider()
          }
          ForEach(item.nameOffers.enumerated(), id: \.offset) { index, offer in
            if index > 0, offer.isFirstOfSource { Divider() }
            SourceRowView(
              source: offer.source.title, value: offer.value, isWinner: offer.isWinner,
              showsSource: offer.isFirstOfSource
            )
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("knownByCard")
    }
  }
}
