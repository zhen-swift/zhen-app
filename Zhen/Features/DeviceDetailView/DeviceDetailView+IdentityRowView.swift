import SwiftUI
import ZhenCore

extension DeviceDetailView.IdentityCardView {
  /// One hardware address: the address, how it joined, and when it was seen.
  struct RowView: View {
    let row: IdentityRow

    var body: some View {
      HStack(alignment: .firstTextBaseline, spacing: .spacing.medium) {
        StatusDot(row.isCurrent ? .accent : .neutral)
        VStack(alignment: .leading, spacing: .spacing.xSmall) {
          HStack(spacing: .spacing.small) {
            Text(verbatim: row.mac)
              .font(.callout.monospaced())
              .foregroundStyle(.textPrimary)
            if row.isPrivate { Chip(.private) }
          }
          Text(row.reason)
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
        }
        Spacer()
        Text(row.span)
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
      }
      .padding(.spacing.large)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isStaticText)
      .accessibilityIdentifier(row.isCurrent ? "identityCurrent" : "identityMAC-\(row.mac)")
    }
  }
}
