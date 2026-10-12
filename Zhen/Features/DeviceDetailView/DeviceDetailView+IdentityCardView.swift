import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Which key identifies this device, and how its identity has changed: the current
  /// hardware address, then every merge, rename and address move, newest first. The one
  /// place identity-key stability appears: a person who opened this card is asking
  /// exactly that.
  ///
  /// A3 asks for one row per MAC with a date range. zhen-core 0.6.0 keeps only the
  /// current MAC on a device, and its merge event says how many records joined, not which
  /// addresses they had — so the rows are the changes core did record (ledger, phase 3).
  struct IdentityCardView: View {
    let item: DeviceItem
    let changes: [DerivedEvent]

    var body: some View {
      Card("Identity history", caption: caption) {
        VStack(alignment: .leading, spacing: .zero) {
          HStack(spacing: .spacing.medium) {
            StatusDot(.accent)
            Text(item.mac ?? String(localized: "No hardware address"))
              .font(.callout.monospaced())
              .foregroundStyle(.textPrimary)
            if item.isPrivateMAC { Chip("private") }
            Spacer()
            Text(String(localized: "since \(item.firstSeen.formatted(date: .abbreviated, time: .omitted))"))
              .font(.subheadline)
              .foregroundStyle(.textSecondary)
          }
          .padding(.spacing.large)
          .accessibilityElement(children: .combine)
          .accessibilityIdentifier("identityCurrent")
          ForEach(changes) { change in
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: .spacing.medium) {
              StatusDot(.neutral)
              Text(change.kind.label)
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.textSecondary)
                .frame(width: .dimension.eventKindLabel, alignment: .leading)
              Text(change.detail.trimmingPrefix("· "))
                .font(.subheadline)
                .foregroundStyle(.textPrimary)
              Spacer()
              Text(change.date, format: .dateTime.month().day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            }
            .padding(.spacing.large)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("identityChange-\(change.kind)")
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("identityCard")
    }

    private var caption: String {
      let count = changes.count
      // Spelled out: `^[…](inflect: true)` is rendered literally by `String(localized:)`
      // without a catalog entry, which the stage-2 screenshot showed.
      let seen = switch count {
      case 0: String(localized: "No identity changes seen")
      case 1: String(localized: "1 identity change")
      default: String(localized: "\(count) identity changes")
      }
      return "\(item.identityCaption) · \(seen)"
    }
  }
}
