import SwiftUI

/// Gaps and padding, on the 4 pt grid the artboards are drawn on.
///
/// Measured at 2x from `Docs/Design/` (`Docs/process/evidence/runs-artboard.swift`):
/// content inset 20, card padding 16, the gap between cards 16 (03-device-detail). The
/// smaller steps are the grid's. A value that is missing is added here, never inlined.
nonisolated enum Spacing {
  static let xxSmall: CGFloat = 2
  static let xSmall: CGFloat = 4
  static let small: CGFloat = 8
  static let medium: CGFloat = 12
  /// Card padding; the gap between cards.
  static let large: CGFloat = 16
  /// The content column's inset from the sidebar and the window edge.
  static let xLarge: CGFloat = 20
  static let xxLarge: CGFloat = 24
}

nonisolated extension CGFloat {
  /// `.padding(.spacing.medium)`, `VStack(spacing: .spacing.small)`.
  static var spacing: Spacing.Type { Spacing.self }
}
