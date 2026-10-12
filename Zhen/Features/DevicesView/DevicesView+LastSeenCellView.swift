import SwiftUI

extension DevicesView {
  /// When it last answered. Offline is said here, by weight — "2 hr ago" in the primary
  /// ink — and by the ring in the name cell, never by dimming the row.
  struct LastSeenCellView: View {
    let item: DeviceItem
    let now: Date

    var body: some View {
      Text(Self.text(for: item, now: now))
        .font(item.isOnline ? .subheadline : .subheadline.weight(.semibold))
        .foregroundStyle(item.isOnline ? .textSecondary : .textPrimary)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .lineLimit(1)
    }

    static func text(for item: DeviceItem, now: Date) -> String {
      if item.isOnline { return String(localized: .now) }
      return item.lastSeen.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
  }
}
