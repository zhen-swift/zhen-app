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

    /// The widths for the model's devices, worked out once per change to them and once a
    /// minute ("2 min. ago" grows), not on every redraw. Uncached, a selection click on a
    /// /16 re-measured 65 534 rows (`ScaleTests`). All devices, never the search's subset:
    /// columns that resized as a person typed would move the thing they were reading.
    static func cached(for model: NetworkModel, now: Date) -> ColumnWidths {
      // Through the observed property (a cache hit must not stop the caller redrawing when
      // the devices change), and keyed on the model (previews and tests make several).
      let devices = model.devices
      let key = Cache.Key(model: ObjectIdentifier(model), revision: model.devicesRevision, minute: Int(now.timeIntervalSince1970 / 60))
      if let cache, cache.key == key { return cache.widths }
      let widths = ColumnWidths(rows: devices, now: now)
      cache = Cache(key: key, widths: widths)
      return widths
    }

    private struct Cache {
      struct Key: Equatable {
        let model: ObjectIdentifier
        let revision: Int
        let minute: Int
      }
      let key: Key
      let widths: ColumnWidths
    }

    private static var cache: Cache?

    /// How many characters a row's address takes, as `DeviceItem.address` writes it.
    static func addressLength(_ item: DeviceItem) -> Int {
      guard let v4 = item.device.addresses.lazy.compactMap(\.v4).min() else { return item.address.count }
      var raw = v4.raw
      var length = 3
      for _ in 0..<4 {
        let octet = raw & 0xFF
        length += octet >= 100 ? 3 : octet >= 10 ? 2 : 1
        raw >>= 8
      }
      return length
    }

    init(rows: [DeviceItem], now: Date) {
      // The header's sort chevron, and the cell's own inset on both sides.
      let chrome = IconSize.large + Spacing.medium
      func header(_ title: String) -> CGFloat { TextMeasure.width(title, .headline) + chrome }

      let words = Identification.allCases.map(IdentityCellView.word(for:))
      identity = max(
        header(String(localized: .identity)),
        IconSize.medium + Spacing.small + TextMeasure.widest(words, .subheadline) + Spacing.medium
      )
      // The longest address is the widest (monospaced). An IPv4 address's length is its
      // digits plus three dots, worked out without writing 65 534 strings (`ScaleTests`).
      var longest: DeviceItem?
      var longestLength = -1
      for row in rows {
        let length = Self.addressLength(row)
        if length > longestLength { (longest, longestLength) = (row, length) }
      }
      address = max(
        header(String(localized: .ipAddressColumn)),
        TextMeasure.widest([longest?.address ?? ""], .callout, monospaced: true) + Spacing.medium
      )
      let chip = rows.contains(where: \.isPrivateMAC)
        ? Spacing.small + TextMeasure.width(String(localized: .private), .caption) + 2 * Spacing.small
        : 0
      // Every MAC is written the same length, so one stands for all of them.
      let macs = [rows.contains { $0.device.mac != nil } ? "00:00:00:00:00:00" : nil,
                  rows.contains { $0.device.mac == nil } ? "—" : nil].compactMap(\.self)
      mac = max(
        header(String(localized: .macAddress)),
        TextMeasure.widest(macs, .callout, monospaced: true) + chip + Spacing.medium
      )
      lastSeen = max(
        header(String(localized: .lastSeenColumn)),
        TextMeasure.widest(LastSeenCellView.distinctTexts(for: rows, now: now), .headline) + Spacing.medium
      )
    }
  }
}
