import SwiftUI

/// Labels over values, aligned across rows. A missing value is an em dash — an empty cell
/// looks like a bug; a dash looks like an answer.
struct KeyValueGrid: View {
  struct Pair: Identifiable {
    let label: LocalizedStringResource
    let value: String?
    var isAddress = false
    var chip: LocalizedStringResource?
    let id: String
  }

  let pairs: [Pair]

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: .spacing.xxLarge, verticalSpacing: .spacing.small) {
      ForEach(pairs) { pair in
        GridRow {
          Text(pair.label)
            .font(.caption.bold())
            .textCase(.uppercase)
            .foregroundStyle(.textSecondary)
          HStack(spacing: .spacing.small) {
            Text(pair.value ?? "—")
              .font(pair.isAddress ? .callout.monospaced() : .body)
              .foregroundStyle(pair.value == nil ? .textSecondary : .textPrimary)
              .textSelection(.enabled)
            if let chip = pair.chip { Chip(chip) }
          }
          .accessibilityIdentifier("value-\(pair.id)")
        }
      }
    }
  }
}

#Preview("Key-value grid — dark") {
  KeyValueGrid(pairs: [
    .init(label: .ipAddressLabel, value: "192.168.50.37", isAddress: true, id: "ip"),
    .init(label: .mac, value: "6A:5C:00:00:00:05", isAddress: true, chip: .private, id: "mac"),
    .init(label: .vendor, value: nil, id: "vendor"),
  ])
  .padding(.spacing.xLarge)
  .background(.surface)
  .preferredColorScheme(.dark)
}
