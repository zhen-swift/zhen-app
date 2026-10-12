import Foundation
import ZhenCore

/// The settings a scan reads, by the keys the Settings scene writes with `@AppStorage`.
struct Preferences {
  enum Key {
    static let scanInterval = "scanIntervalMinutes"
    static let subnetOverride = "subnetOverride"
    static let deepScan = "deepScanNewDevices"
    static let retentionDays = "retentionDays"
    static let budgetSeconds = "scanBudgetSeconds"
    static let notifyNewDevices = "notifyNewDevices"
  }

  /// The scan lengths Settings offers, in seconds. Core's default is 30.
  static let budgets = [10, 20, 30, 60]
  static let defaultBudgetSeconds = 30

  let scanIntervalMinutes: Int
  let subnetOverride: IPv4Network?
  let deepScan: Bool
  let retentionDays: Int
  /// How long a scan may take in all.
  let budget: Duration
  /// Whether a device seen for the first time is announced. Off unless asked for.
  let notifyNewDevices: Bool

  init(_ defaults: UserDefaults) {
    scanIntervalMinutes = defaults.integer(forKey: Key.scanInterval)
    subnetOverride = defaults.string(forKey: Key.subnetOverride).flatMap(Self.network)
    deepScan = defaults.bool(forKey: Key.deepScan)
    retentionDays = defaults.integer(forKey: Key.retentionDays)
    let seconds = defaults.integer(forKey: Key.budgetSeconds)
    budget = .seconds(Self.budgets.contains(seconds) ? seconds : Self.defaultBudgetSeconds)
    notifyNewDevices = defaults.bool(forKey: Key.notifyNewDevices)
  }

  /// A typed subnet, or nil when it is empty or not a network this app will scan.
  static func network(_ text: String) -> IPv4Network? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, let network = IPv4Network(trimmed), network.isEnumerable else { return nil }
    return network
  }
}
