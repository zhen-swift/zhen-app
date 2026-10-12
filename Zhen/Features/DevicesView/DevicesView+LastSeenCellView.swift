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

    /// Every distinct text the column can show for these rows, without formatting each row.
    ///
    /// Formatting a relative date for every offline row of a /16 took 3.3 s
    /// (`ScaleTests`), only to find the widest. Rows are grouped by age at the resolution
    /// the text shows — minutes within the hour, hours within the day, days after — and
    /// the youngest and oldest of each group are formatted, so a group whose members round
    /// differently still has both spellings measured.
    static func distinctTexts(for rows: [DeviceItem], now: Date) -> [String] {
      var groups: [Int: (young: DeviceItem, old: DeviceItem)] = [:]
      var anyOnline = false
      for row in rows {
        if row.isOnline { anyOnline = true; continue }
        let age = now.timeIntervalSince(row.lastSeen)
        let key = age < 3_600 ? Int(age / 60) : age < 86_400 ? 1_000 + Int(age / 3_600) : 100_000 + Int(age / 86_400)
        if let group = groups[key] {
          groups[key] = (row.lastSeen > group.young.lastSeen ? row : group.young, row.lastSeen < group.old.lastSeen ? row : group.old)
        } else {
          groups[key] = (row, row)
        }
      }
      var texts = groups.values.flatMap { [text(for: $0.young, now: now), text(for: $0.old, now: now)] }
      if anyOnline { texts.append(String(localized: .now)) }
      return texts
    }
  }
}
