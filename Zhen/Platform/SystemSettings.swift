import Foundation

/// System Settings panes the app sends people to, so a claim can be checked against the OS.
nonisolated enum SystemSettings {
  /// Privacy & Security › Local Network.
  static let localNetwork = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")
}
