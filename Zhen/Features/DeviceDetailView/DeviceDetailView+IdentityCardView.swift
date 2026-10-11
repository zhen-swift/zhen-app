import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Which key identifies this device, and how it has changed. The one place identity-key
  /// stability appears: a person who opened this card is asking exactly that.
  struct IdentityCardView: View {
    let item: DeviceItem
    let merges: [DerivedEvent]

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
          ForEach(merges) { merge in
            Divider()
            HStack(spacing: .spacing.medium) {
              StatusDot(.neutral)
              Text(merge.detail).font(.subheadline).foregroundStyle(.textSecondary)
              Spacer()
              Text(merge.date, format: .dateTime.month().day().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            }
            .padding(.spacing.large)
          }
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("identityCard")
    }

    private var caption: String {
      // The lease key's value depends on the network; its kind, which is all this reads, does not.
      let network = IPv4Network(base: item.device.ipv4Addresses.first ?? IPv4Address(raw: 0), prefix: 32)
      let key = HostIdentifier.candidates(for: item.device, in: network).first?.kind
      let described: String = switch key {
      case .universalMAC?: String(localized: "hardware MAC")
      case .randomizedMAC?: String(localized: "rotating MAC")
      case .mdnsInstance?: String(localized: "Bonjour name")
      case .dhcpHostname?: String(localized: "DHCP name")
      case .ipLease?, nil: String(localized: "address only")
      }
      let changes = merges.isEmpty ? String(localized: "No identity changes seen") : String(localized: "\(merges.count) merges")
      return String(localized: "identity key: \(described), stability \(item.device.identityStability.rawValue) · \(changes)")
    }
  }
}
