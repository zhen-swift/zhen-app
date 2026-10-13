import AppIntents
import Foundation

/// Scan Now, for Shortcuts, Spotlight and Siri. The house rules ask for the primary action
/// to be an App Intent on macOS too; this is that action, through the same model call the
/// toolbar and ⌘R make, so it scans with the person's settings and nothing else.
struct ScanNetworkIntent: AppIntent {
  // Spelled out, not the generated `.scanNetwork`: the App Intents metadata processor reads
  // these at build time and accepts only a literal or an explicit initializer.
  static let title = LocalizedStringResource("scanNetwork", defaultValue: "Scan Network")
  static let description = IntentDescription(LocalizedStringResource(
    "scansYourNetworkNowScanNow", defaultValue: "Scans your network now, as Scan Now does in Zhen."
  ))
  /// The scan runs from the window, and its progress is the window: open it.
  static let openAppWhenRun = true

  @Dependency private var model: NetworkModel

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    .result(dialog: IntentDialog(stringLiteral: Self.run(on: model)))
  }

  /// What the intent does, on a model a test can hand it: the sentence it answers with.
  @MainActor
  static func run(on model: NetworkModel) -> String {
    guard !model.isBusy else { return String(localized: .zhenAlreadyScanning) }
    model.startScan()
    return String(localized: .scanningYourNetwork)
  }
}

/// How many devices answered the latest scan, as a number a shortcut can use.
struct OnlineDevicesIntent: AppIntent {
  static let title = LocalizedStringResource("countOnlineDevices", defaultValue: "Count Online Devices")
  static let description = IntentDescription(LocalizedStringResource(
    "howManyDevicesAnsweredZhensMost",
    defaultValue: "How many devices answered Zhen's most recent scan. Reads history; does not scan."
  ))

  @Dependency private var model: NetworkModel

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
    let online = await Self.run(on: model)
    return .result(value: online, dialog: IntentDialog(.devicesAnsweredLatestScan(online)))
  }

  /// The count, from history — loading it first if the app has only just been launched.
  @MainActor
  static func run(on model: NetworkModel) async -> Int {
    if !model.hasLoaded { await model.load() }
    return model.onlineCount
  }
}

/// The phrases Siri and Spotlight offer without any setup.
struct ZhenShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: ScanNetworkIntent(),
      phrases: ["Scan my network with \(.applicationName)", "Scan the network in \(.applicationName)"],
      shortTitle: LocalizedStringResource("scanNetwork", defaultValue: "Scan Network"),
      systemImageName: "dot.radiowaves.left.and.right"
    )
    AppShortcut(
      intent: OnlineDevicesIntent(),
      phrases: ["How many devices are online in \(.applicationName)"],
      shortTitle: LocalizedStringResource("onlineDevices", defaultValue: "Online Devices"),
      systemImageName: "square.grid.2x2"
    )
  }
}
