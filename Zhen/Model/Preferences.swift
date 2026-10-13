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
    static let keepInMenuBar = "keepInMenuBar"
  }

  /// The scan lengths Settings offers, in seconds. Core's default is 30.
  static let budgets = [10, 20, 30, 60]
  static let defaultBudgetSeconds = 30

  let scanIntervalMinutes: Int
  let subnetOverride: IPv4Network?
  /// Whether a device seen for the first time has its common ports checked. A port stage
  /// limited to new devices is zhen-core 0.7.0's `PortStage.newHosts`.
  let deepScanNewDevices: Bool
  let retentionDays: Int
  /// How long a scan may take in all.
  let budget: Duration
  /// Whether a device seen for the first time is announced. Off unless asked for.
  let notifyNewDevices: Bool
  /// Whether Zhen stays in the menu bar, scanning, after its window closes. Off unless
  /// asked for.
  let keepInMenuBar: Bool

  init(_ defaults: UserDefaults) {
    scanIntervalMinutes = defaults.integer(forKey: Key.scanInterval)
    subnetOverride = defaults.string(forKey: Key.subnetOverride).flatMap(Self.network)
    deepScanNewDevices = defaults.bool(forKey: Key.deepScan)
    retentionDays = defaults.integer(forKey: Key.retentionDays)
    let seconds = defaults.integer(forKey: Key.budgetSeconds)
    budget = .seconds(Self.budgets.contains(seconds) ? seconds : Self.defaultBudgetSeconds)
    notifyNewDevices = defaults.bool(forKey: Key.notifyNewDevices)
    keepInMenuBar = defaults.bool(forKey: Key.keepInMenuBar)
  }

  /// The port stage a scan asks for.
  var portStage: PortStage { deepScanNewDevices ? .newHosts : .off }

  /// A typed subnet, or nil when it is empty or not a network this app will scan.
  static func network(_ text: String) -> IPv4Network? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, let network = IPv4Network(trimmed), network.isEnumerable else { return nil }
    return network
  }
}
