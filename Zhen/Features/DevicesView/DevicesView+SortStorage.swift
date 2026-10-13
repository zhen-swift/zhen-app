import SwiftUI

extension DevicesView {
  /// The table's sort order as scene storage can hold it: a column and a direction.
  ///
  /// `KeyPathComparator` is not storable, so the order is named by the column the person
  /// clicked. The default — online first, then most recently seen — is no column, and is
  /// stored as nothing.
  enum SortStorage {
    /// Each sortable column's comparator, by the name it is stored under.
    static let columns: [(name: String, comparator: KeyPathComparator<DeviceItem>)] = [
      ("name", KeyPathComparator(\.nameSortKey)),
      ("identity", KeyPathComparator(\.identificationRank)),
      ("address", KeyPathComparator(\.addressSortKey)),
      ("mac", KeyPathComparator(\.macSortKey)),
      ("lastSeen", KeyPathComparator(\.lastSeen)),
    ]

    /// "address" or "address-reverse"; "" for the default order.
    static func encode(_ order: [KeyPathComparator<DeviceItem>]) -> String {
      guard let first = order.first, order != DeviceItem.defaultOrder else { return "" }
      for column in columns {
        var forward = column.comparator
        forward.order = .forward
        var reverse = column.comparator
        reverse.order = .reverse
        if first == forward { return column.name }
        if first == reverse { return column.name + "-reverse" }
      }
      return ""
    }

    static func decode(_ text: String) -> [KeyPathComparator<DeviceItem>] {
      let reversed = text.hasSuffix("-reverse")
      let name = reversed ? String(text.dropLast("-reverse".count)) : text
      guard var comparator = columns.first(where: { $0.name == name })?.comparator else { return DeviceItem.defaultOrder }
      comparator.order = reversed ? .reverse : .forward
      return [comparator]
    }
  }
}
