import SwiftUI
import ZhenCore

extension DevicesView {
  /// The device table. Every column but NAME is as wide as its widest cell, measured over
  /// every device (not only those the search shows); NAME takes the rest.
  struct DeviceTableView: View {
    let rows: [DeviceItem]
    @Binding var selection: Set<DeviceItem.ID>
    @Binding var sortOrder: [KeyPathComparator<DeviceItem>]
    @Binding var columnCustomization: TableColumnCustomization<DeviceItem>
    let onOpen: (DeviceItem.ID) -> Void
    let onRename: (DeviceItem.ID) -> Void
    let onShowActivity: (String) -> Void
    @Environment(NetworkModel.self) private var model

    var body: some View {
      TimelineView(.everyMinute) { context in
        let widths = ColumnWidths.cached(for: model, now: context.date)
        Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
          TableColumn(String(localized: .name), value: \.nameSortKey) { item in
            NameCellView(item: item, now: context.date)
          }
          .width(min: .windowSize.nameMinimum)
          .customizationID("name")
          // The name is what a row is; hiding it would leave rows nobody can tell apart.
          .disabledCustomizationBehavior(.visibility)
          TableColumn(String(localized: .identity), value: \.identificationRank) { item in
            IdentityCellView(identification: item.identification)
          }
          .width(widths.identity)
          .customizationID("identity")
          TableColumn(String(localized: .ipAddressColumn), value: \.addressSortKey) { item in
            AddressCellView(item: item)
          }
          .width(widths.address)
          .customizationID("address")
          TableColumn(String(localized: .macAddress), value: \.macSortKey) { item in
            MACCellView(item: item)
          }
          .width(widths.mac)
          .customizationID("mac")
          TableColumn(String(localized: .lastSeenColumn), value: \.lastSeen) { item in
            LastSeenCellView(item: item, now: context.date)
          }
          .width(widths.lastSeen)
          .customizationID("lastSeen")
        }
        // The table's minimum is its measured columns. The window grows its own minimum
        // to match, rather than the split view taking the width from the sidebar (F2) —
        // up to the screen's width, past which the table scrolls sideways.
        .frame(minWidth: widths.minimumTableOnScreen)
        .contextMenu(forSelectionType: DeviceItem.ID.self) { ids in
          DeviceMenuView(ids: ids, onOpen: onOpen, onRename: onRename, onShowActivity: onShowActivity)
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
      .accessibilityLabel(String(localized: .devices))
      .accessibilityIdentifier("deviceTable")
    }
  }
}
