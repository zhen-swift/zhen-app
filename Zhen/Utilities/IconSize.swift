import SwiftUI

/// Sizes of marks and glyphs, measured as bounding boxes on the artboards.
///
/// These are the default-size values. A view that draws one scales it with
/// `@ScaledMetric(relativeTo:)` so it follows Dynamic Type with the text beside it.
nonisolated enum IconSize {
  /// The sidebar footer's scan dot.
  static let xSmall: CGFloat = 6
  /// A status dot in a row.
  static let small: CGFloat = 8
  /// The signal meter; a sidebar glyph.
  static let medium: CGFloat = 12
  /// A stage's check or spinner.
  static let large: CGFloat = 16
  /// The device tile in the detail header.
  static let xLarge: CGFloat = 40
}

nonisolated extension CGFloat {
  /// `.frame(width: .iconSize.small, height: .iconSize.small)`.
  static var iconSize: IconSize.Type { IconSize.self }
}
