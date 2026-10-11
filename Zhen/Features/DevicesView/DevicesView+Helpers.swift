import SwiftUI

extension DevicesView {
  /// The table's rows: searched, then sorted.
  var rows: [DeviceItem] {
    let term = search.trimmingCharacters(in: .whitespaces)
    let matching = term.isEmpty ? model.devices : model.devices.filter { item in
      [item.name ?? "Unidentified device", item.subtitle, item.address, item.mac ?? ""]
        .contains { $0.localizedStandardContains(term) }
    }
    return matching.sorted(using: sortOrder)
  }
}
