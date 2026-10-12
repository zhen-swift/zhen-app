import AppKit

/// Whether closing the window quits the app.
///
/// It does, as a single-window app should — unless the person asked Zhen to keep watching
/// from the menu bar, where it hosts the scans and has to outlive the window.
final class AppDelegate: NSObject, NSApplicationDelegate {
  /// The model's preferences, handed over by `ZhenApp` — the fixture domain under test.
  static var preferences: UserDefaults = .standard

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    !Preferences(Self.preferences).keepInMenuBar
  }
}
