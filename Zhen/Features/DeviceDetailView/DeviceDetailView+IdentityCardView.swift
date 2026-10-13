import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Which key identifies this device, and every hardware address it has presented: one
  /// row per MAC, with how it joined and when it was seen (A3). The one place
  /// identity-key stability appears: a person who opened this card is asking exactly that.
  struct IdentityCardView: View {
    let item: DeviceItem

    var body: some View {
      Card(.identityHistory, caption: caption) {
        VStack(alignment: .leading, spacing: .zero) {
          if item.identityRows.isEmpty {
            HStack(spacing: .spacing.medium) {
              StatusDot(.accent)
              Text(.noHardwareAddress)
                .font(.callout)
                .foregroundStyle(.textPrimary)
              Spacer()
              Text(String(localized: .since(item.firstSeen.formatted(date: .abbreviated, time: .omitted))))
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            }
            .padding(.spacing.large)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("identityCurrent")
          }
          ForEach(item.identityRows.enumerated(), id: \.element.id) { index, row in
            if index > 0 { Divider() }
            RowView(row: row)
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("identityCard")
    }

    private var caption: String {
      "\(item.identityCaption) · \(String(localized: .hardwareAddressesSeen(item.identityRows.count)))"
    }
  }
}
