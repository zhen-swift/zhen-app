import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Events about this device. Core names an event's subject the way a person would, so a
  /// device is matched by its name or any of its addresses.
  func events(for item: DeviceItem) -> [DerivedEvent] {
    let keys = Set([item.device.displayName, item.name].compactMap(\.self) + item.device.addresses.map(\.description))
    return model.events.filter { event in
      keys.contains(event.subject) || keys.contains { event.detail.contains($0) && $0.contains(".") }
    }
  }

  func scanPorts(_ item: DeviceItem) {
    guard let address = item.device.ipv4Addresses.first else { return }
    model.startScan(deepScan: true, network: IPv4Network(base: address, prefix: 32))
  }

  /// The device-kind symbol for the header tile.
  static func symbol(for device: Device) -> String {
    let hint = [device.displayModel, device.displayName].compactMap(\.self).joined(separator: " ").lowercased()
    if hint.contains("macbook") { return "laptopcomputer" }
    if hint.contains("imac") || hint.contains("mac") { return "desktopcomputer" }
    if hint.contains("appletv") || hint.contains("apple tv") { return "appletv" }
    if hint.contains("iphone") { return "iphone" }
    if hint.contains("ipad") { return "ipad" }
    if hint.contains("printer") { return "printer" }
    if device.osHint == .networkDevice || device.openPorts.contains(where: { $0.port == 53 }) { return "wifi.router" }
    return "questionmark.circle"
  }
}
