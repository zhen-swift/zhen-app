import SwiftUI

/// The main window's bounds.
///
/// The minimum is measured, not chosen: the sidebar at its own minimum plus the Devices
/// table with every column at its widest cell and NAME at `nameMinimum`. See the ledger,
/// stage A, "Window size range".
nonisolated enum WindowSize {
  static let minimumWidth: CGFloat = 860
  static let minimumHeight: CGFloat = 480
  static let defaultWidth: CGFloat = 1180
  static let defaultHeight: CGFloat = 720
  /// The Settings window, which is fixed-width like every Mac settings window.
  static let settingsWidth: CGFloat = 560
  static let settingsHeight: CGFloat = 640
  /// The sidebar's width range. Its ideal is the artboards' 228 less the 8 pt inset the
  /// system list already draws.
  static let sidebarMinimum: CGFloat = 180
  static let sidebarIdeal: CGFloat = 220
  /// The narrowest the NAME column may get before the subtitle loses its meaning.
  static let nameMinimum: CGFloat = 200
}

nonisolated extension CGFloat {
  /// `.frame(minWidth: .windowSize.minimumWidth)`.
  static var windowSize: WindowSize.Type { WindowSize.self }
}
