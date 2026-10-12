import SwiftUI

extension DevicesView {
  /// The table's rows: searched, then sorted — once per change to the devices, the search
  /// or the sort, not on every redraw. A selection click re-sorted a /16 (0.8 s in Debug).
  var rows: [DeviceItem] {
    // Read through the observed property, so a view that hits the cache still redraws when
    // the devices change; key on the model too, so two models never share an entry.
    let devices = model.devices
    let key = RowsCache.Key(model: ObjectIdentifier(model), revision: model.devicesRevision, search: search, sort: sortOrder)
    if let cached = RowsCache.last, cached.key == key { return cached.rows }
    let rows = devices.filter { $0.matches(search) }.sorted(using: sortOrder)
    RowsCache.last = RowsCache(key: key, rows: rows)
    return rows
  }

  struct RowsCache {
    struct Key: Equatable {
      let model: ObjectIdentifier
      let revision: Int
      let search: String
      let sort: [KeyPathComparator<DeviceItem>]
    }
    let key: Key
    let rows: [DeviceItem]
    static var last: RowsCache?
  }
}
