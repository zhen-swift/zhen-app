import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Every source that could name a device, what each offered, and which won. Sources that
  /// offered nothing say so: the absence is information.
  struct KnownByCardView: View {
    let item: DeviceItem

    var body: some View {
      Card("Known by", caption: String(localized: "competing names by source — highest-trust source wins")) {
        VStack(alignment: .leading, spacing: .zero) {
          if let userName = item.userName {
            SourceRowView(source: String(localized: "You"), value: userName, isWinner: true)
            Divider()
          }
          ForEach(NameSource.allCases.enumerated(), id: \.element) { index, source in
            if index > 0 { Divider() }
            let offered = item.device.names.filter { $0.source == source }.min()
            SourceRowView(
              source: source.title,
              value: offered?.value,
              isWinner: item.userName == nil && offered != nil && offered == item.device.names.best
            )
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("knownByCard")
    }
  }
}
