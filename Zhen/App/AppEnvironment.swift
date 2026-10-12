import Foundation
import SwiftUI

/// What this launch was asked to be, read once from the process and injected.
///
/// The house rules' one reader of `ProcessInfo`: nothing else in the app looks at launch
/// arguments or the environment. Tests and screenshots select fixtures here, so they can
/// never see or damage the history file the command line shares with the app.
nonisolated struct AppEnvironment: Sendable {
  /// Where devices, events and scans come from.
  enum DataSource: Sendable, Equatable {
    /// The shared history file and the real network.
    case live
    /// A fixture network in memory, and a scanner that replays it.
    case fixture(FixtureNetwork.Variant)
  }

  var dataSource: DataSource
  /// `-UITesting`: fixtures, fake side effects, a throwaway defaults domain.
  var isUITesting: Bool
  /// `-ShowcaseData`: the same, seeded with the marketing dataset.
  var isShowcase: Bool
  /// Whether the window puts back its last room, device and selection. Always, except
  /// under fixtures, where only `-RestoreState` asks for it: AppKit keeps writing window
  /// state even with `-ApplePersistenceIgnoreState`, and one test's open device must not
  /// become the next test's starting screen.
  var restoresState: Bool
  /// `-Appearance light|dark`: pins the window's appearance for screenshots.
  var colorScheme: ColorScheme?
  /// `-Contrast increased`: Increase Contrast without the system setting.
  var increasedContrast: Bool
  /// How long the fixture scanner waits between events. `-ScanPace <milliseconds>`.
  var scanPace: Duration
  /// `-WindowSize 1440x900`: the window's content size at launch, for App Store captures
  /// (AGENTS.md: the Mac capture is a 1440 × 900 window on a Retina display).
  var windowSize: CGSize?
  /// The process environment, handed to `HistoryLocation` so `ZHEN_HISTORY` still works.
  var processEnvironment: [String: String]
  /// When this launch began; fixtures are laid out relative to it.
  var launchedAt: Date

  var usesFixtures: Bool { dataSource != .live }

  /// Parses launch arguments. Unknown arguments are ignored: AppKit and XCTest add their own.
  static func parse(
    arguments: [String], environment: [String: String], now: Date
  ) -> AppEnvironment {
    func value(after flag: String) -> String? {
      guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
      }
      return arguments[index + 1]
    }
    // The unit-test host is this app, launched with no arguments. Without this it would
    // open the history file the command line shares — tests must never see real data.
    let unitTestHost = environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil
    let uiTesting = arguments.contains("-UITesting") || unitTestHost
    let showcase = arguments.contains("-ShowcaseData")
    let variant = value(after: "-Fixture").flatMap(FixtureNetwork.Variant.init(rawValue:)) ?? .home
    let pace = value(after: "-ScanPace").flatMap(Int.init) ?? 60
    let size = value(after: "-WindowSize").flatMap { text -> CGSize? in
      let parts = text.split(separator: "x").compactMap { Double($0) }
      return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
    }

    return AppEnvironment(
      dataSource: uiTesting || showcase ? .fixture(variant) : .live,
      isUITesting: uiTesting,
      isShowcase: showcase,
      restoresState: !(uiTesting || showcase) || arguments.contains("-RestoreState"),
      colorScheme: value(after: "-Appearance").flatMap {
        switch $0 {
        case "light": .light
        case "dark": .dark
        default: nil
        }
      },
      increasedContrast: value(after: "-Contrast") == "increased",
      scanPace: .milliseconds(pace),
      windowSize: size,
      processEnvironment: environment,
      launchedAt: now
    )
  }

  /// This process's launch, parsed once.
  static let current = parse(
    arguments: ProcessInfo.processInfo.arguments,
    environment: ProcessInfo.processInfo.environment,
    now: .now
  )
}
