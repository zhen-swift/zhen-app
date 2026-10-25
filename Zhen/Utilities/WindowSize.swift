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
  /// The sidebar's share of the window's width. The floating sidebar occupies its ideal
  /// plus an 8 pt inset: the splitter reports 228 for an ideal of 220.
  static var sidebarShare: CGFloat { sidebarIdeal + Spacing.small + BorderWidth.hairline }
  /// The width of the screen the window is on, less the Dock. A 13-inch Mac at "Larger
  /// Text", and CI's display, are 1024 pt wide: narrower than the measured minimum can be.
  /// There the minimum gives way and the table scrolls sideways, rather than the window's
  /// edge, and what sits on it, being off screen.
  @MainActor static var screenWidth: CGFloat { NSScreen.main?.visibleFrame.width ?? .infinity }
  /// The unified toolbar above the content, which the window's frame includes and its
  /// content size does not. Measured: a 900 pt content size made a 952 pt window.
  static let toolbarHeight: CGFloat = 52
}

nonisolated extension CGFloat {
  /// `.frame(minWidth: .windowSize.minimumWidth)`.
  static var windowSize: WindowSize.Type { WindowSize.self }
}
