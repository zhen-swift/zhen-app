import Foundation

/// Notifications, as the model asks for them: a test or a fixture launch records them, a
/// real launch posts them through `UNUserNotificationCenter` (`LiveNotifier`).
protocol Notifier {
  /// Asks the person, once, whether the app may notify them. True when it may.
  func requestPermission() async -> Bool
  func post(title: String, body: String, id: String)
}

/// The notifier under `-UITesting` and in tests: nothing reaches Notification Centre.
final class FakeNotifier: Notifier {
  private(set) var posted: [(title: String, body: String)] = []
  var permits = true

  func requestPermission() async -> Bool { permits }
  func post(title: String, body: String, id: String) { posted.append((title, body)) }
}

/// What "a new device joined" means, and what to say about it.
///
/// New is two things at once: a device this window did not know before the scan, and one
/// history first saw during it. Either alone is wrong — a merge re-keys a device it has
/// known for a year, and a device returning after a week is not new. And never on the
/// first scan of a history: every device is new then, and twenty notifications at once
/// is noise, not news.
nonisolated enum NewDeviceNotice {
  /// More than this many new devices make one summary instead of one each.
  static let individualLimit = 3

  static func newDevices(_ devices: [DeviceItem], knownBefore: Set<DeviceItem.ID>, scanStarted: Date) -> [DeviceItem] {
    guard !knownBefore.isEmpty else { return [] }
    return devices.filter { !knownBefore.contains($0.id) && $0.firstSeen >= scanStarted.addingTimeInterval(-1) }
  }

  /// The notifications to post: one per device, or a single summary.
  static func messages(for devices: [DeviceItem]) -> [(title: String, body: String, id: String)] {
    guard !devices.isEmpty else { return [] }
    if devices.count > individualLimit {
      let names = devices.prefix(individualLimit).map(describe).joined(separator: "\n")
      return [(String(localized: .newDevicesOnYourNetwork(devices.count)), names, "new-devices-\(UUID().uuidString)")]
    }
    return devices.map { device in
      (String(localized: .newDeviceOnYourNetwork), describe(device), "new-device-\(device.id)")
    }
  }

  /// "Living Room TV — 192.168.50.44", or what is known when nothing names it.
  static func describe(_ device: DeviceItem) -> String {
    "\(device.name ?? device.subtitle) — \(device.address)"
  }
}
