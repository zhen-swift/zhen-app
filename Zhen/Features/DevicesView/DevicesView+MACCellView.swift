import SwiftUI

extension DevicesView {
  /// The hardware address, with `private` beside a randomised one: that chip tells a person
  /// this MAC is not a stable identity, so it stays next to the address it qualifies.
  struct MACCellView: View {
    let item: DeviceItem

    var body: some View {
      HStack(spacing: .spacing.small) {
        Text(item.mac ?? "—")
          .font(.callout.monospaced())
          .foregroundStyle(.textSecondary)
          .lineLimit(1)
        if item.isPrivateMAC {
          Chip(.private)
        }
      }
    }
  }
}
