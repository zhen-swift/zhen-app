import SwiftUI
import ZhenCore

extension DevicesView {
  /// The device table. Every column but NAME is as wide as its widest cell, measured from
  /// the rows it is showing; NAME takes the rest.
  struct DeviceTableView: View {
    let rows: [DeviceItem]
    @Binding var selection: Set<DeviceItem.ID>
    @Binding var sortOrder: [KeyPathComparator<DeviceItem>]
    let onOpen: (DeviceItem.ID) -> Void
    let onRename: (DeviceItem.ID) -> Void
    @Environment(NetworkModel.self) private var model

    var body: some View {
      TimelineView(.everyMinute) { context in
        let widths = ColumnWidths(rows: rows, now: context.date)
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
          TableColumn("Name", value: \.nameSortKey) { item in
            NameCellView(item: item, now: context.date)
          }
          .width(min: .windowSize.nameMinimum)
          TableColumn("Identity", value: \.identificationRank) { item in
            IdentityCellView(identification: item.identification)
          }
          .width(widths.identity)
          TableColumn("IP Address", value: \.addressSortKey) { item in
            AddressCellView(item: item)
          }
          .width(widths.address)
          TableColumn("MAC Address", value: \.macSortKey) { item in
            MACCellView(item: item)
          }
          .width(widths.mac)
          TableColumn("Last Seen", value: \.lastSeen) { item in
            LastSeenCellView(item: item, now: context.date)
          }
          .width(widths.lastSeen)
        }
        // The table's minimum is its measured columns. The window grows its own minimum
        // to match, rather than the split view taking the width from the sidebar (F2).
        .frame(minWidth: widths.minimumTable)
        .contextMenu(forSelectionType: DeviceItem.ID.self) { ids in
          DeviceMenuView(ids: ids, onOpen: onOpen, onRename: onRename)
        } primaryAction: { ids in
          if ids.count == 1, let id = ids.first { onOpen(id) }
        }
        // The primary action answers a double-click; Return, measured, does not reach it.
        // A table on a Mac opens its row on Return, so it is said here.
        .onKeyPress(.return) {
          guard selection.count == 1, let id = selection.first else { return .ignored }
          onOpen(id)
          return .handled
        }
      }
      .accessibilityIdentifier("deviceTable")
    }
  }
}
