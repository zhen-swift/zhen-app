import SwiftUI

extension DevicesView {
  /// Status, name, and what is known — two lines, always.
  ///
  /// An unidentified device is a normal row: "Unidentified device", then the facts we do
  /// have. Never a dash, never a collapsed row, never error styling.
  struct NameCellView: View {
    let item: DeviceItem
    let now: Date

    var body: some View {
      HStack(spacing: .spacing.small) {
        StatusDot(item.isOnline ? .online : .offline)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: .spacing.xxSmall) {
          HStack(spacing: .spacing.small) {
            Text(item.name ?? String(localized: "Unidentified device"))
              .font(.body)
              .foregroundStyle(.textPrimary)
              .lineLimit(1)
            if item.isReassigned {
              Chip("reassigned")
            }
          }
          Text(item.subtitle)
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .help(item.subtitle)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isStaticText)
      .accessibilityLabel(sentence)
      .accessibilityIdentifier("deviceName-\(item.address)")
    }

    /// The row as a person would say it: name, state, address, when.
    private var sentence: String {
      let name = item.name ?? String(localized: "Unidentified device")
      let state = item.isOnline ? String(localized: "online") : String(localized: "offline")
      let identity = IdentityCellView.word(for: item.identification).lowercased()
      let seen = LastSeenCellView.text(for: item, now: now)
      return "\(name), \(state), \(identity), \(item.address), \(String(localized: "last seen")) \(seen)"
    }
  }
}
