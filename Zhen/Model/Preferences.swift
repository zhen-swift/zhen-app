import Foundation
import ZhenCore

/// The settings a scan reads, by the keys the Settings scene writes with `@AppStorage`.
struct Preferences {
  enum Key {
    static let scanInterval = "scanIntervalMinutes"
    static let subnetOverride = "subnetOverride"
    static let deepScan = "deepScanNewDevices"
    static let retentionDays = "retentionDays"
  }

  let scanIntervalMinutes: Int
  let subnetOverride: IPv4Network?
  let deepScan: Bool
  let retentionDays: Int

  init(_ defaults: UserDefaults) {
    scanIntervalMinutes = defaults.integer(forKey: Key.scanInterval)
    subnetOverride = defaults.string(forKey: Key.subnetOverride).flatMap(Self.network)
    deepScan = defaults.bool(forKey: Key.deepScan)
    retentionDays = defaults.integer(forKey: Key.retentionDays)
  }

  /// A typed subnet, or nil when it is empty or not a network this app will scan.
  static func network(_ text: String) -> IPv4Network? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, let network = IPv4Network(trimmed), network.isEnumerable else { return nil }
    return network
  }
}
