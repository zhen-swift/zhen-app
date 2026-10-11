import SwiftUI

extension DevicesView {
  /// The table's rows: searched, then sorted.
  var rows: [DeviceItem] {
    model.devices.filter { $0.matches(search) }.sorted(using: sortOrder)
  }
}
