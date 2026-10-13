import AppKit
import UserNotifications

/// Whether closing the window quits the app, and how notifications present.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  /// The model's preferences, handed over by `ZhenApp` — the fixture domain under test.
  static var preferences: UserDefaults = .standard
  /// Whether this launch posts real notifications (not a fixture launch or a test host).
  static var postsNotifications = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Without a delegate, macOS drops a notification while its app is frontmost — every
    // notice from a scan started with Scan Now was lost (review, part 7).
    if Self.postsNotifications { UNUserNotificationCenter.current().delegate = self }
  }

  /// It closes the app, as a single-window app should — unless the person asked Zhen to
  /// keep watching from the menu bar, where it hosts the scans and has to outlive the window.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    !Preferences(Self.preferences).keepInMenuBar
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }
}
