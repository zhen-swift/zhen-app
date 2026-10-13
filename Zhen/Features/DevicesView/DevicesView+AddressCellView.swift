import SwiftUI

extension DevicesView {
  /// The address, at full strength only when the device answered: an absent device's
  /// address is history, and may be someone else's now.
  struct AddressCellView: View {
    let item: DeviceItem

    var body: some View {
      Text(item.address)
        .font(.callout.monospaced())
        .foregroundStyle(item.isOnline ? .textPrimary : .textSecondary)
        .lineLimit(1)
        .textSelection(.enabled)
        .help(item.fullAddress)
    }
  }
}
