import SwiftUI
import ZhenCore

extension DevicesView {
  /// Each fixed column's width: its widest cell or its header, whichever is wider.
  ///
  /// Measured from the rows on screen, never declared. The artboards' declared widths
  /// (120 / 130 / 240 / 90) forced a table minimum the split view paid for out of the
  /// sidebar — old defect F2 — and were wrong for a real network anyway.
  struct ColumnWidths {
    let identity: CGFloat
    let address: CGFloat
    let mac: CGFloat
    let lastSeen: CGFloat

    /// The narrowest the table can be with every fixed column whole and NAME at its
    /// minimum: the window's real minimum while Devices is showing.
    var minimumTable: CGFloat {
      let columns = [WindowSize.nameMinimum, identity, address, mac, lastSeen]
      return columns.reduce(0, +) + CGFloat(columns.count) * Dimension.tableIntercell + Dimension.tableIntercell
    }

    init(rows: [DeviceItem], now: Date) {
      // The header's sort chevron, and the cell's own inset on both sides.
      let chrome = IconSize.large + Spacing.medium
      func header(_ title: String) -> CGFloat { TextMeasure.width(title, .headline) + chrome }

      let words = Identification.allCases.map(IdentityCellView.word(for:))
      identity = max(
        header(String(localized: "Identity")),
        IconSize.medium + Spacing.small + TextMeasure.widest(words, .subheadline) + Spacing.medium
      )
      address = max(
        header(String(localized: "IP Address")),
        TextMeasure.widest(rows.map(\.address), .callout, monospaced: true) + Spacing.medium
      )
      let chip = rows.contains(where: \.isPrivateMAC)
        ? Spacing.small + TextMeasure.width(String(localized: "private"), .caption) + 2 * Spacing.small
        : 0
      mac = max(
        header(String(localized: "MAC Address")),
        TextMeasure.widest(rows.map { $0.mac ?? "—" }, .callout, monospaced: true) + chip + Spacing.medium
      )
      lastSeen = max(
        header(String(localized: "Last Seen")),
        TextMeasure.widest(rows.map { LastSeenCellView.text(for: $0, now: now) }, .headline) + Spacing.medium
      )
    }
  }
}
