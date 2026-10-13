import SwiftUI

/// Stroke widths.
nonisolated enum BorderWidth {
  /// Separators and card borders: 2 px at 2x in every artboard.
  static let hairline: CGFloat = 1
  /// A focus ring. Thinner is "a hairline halo on a dark surface … a thing you hunt for"
  /// (the old app's keyboard tests, which measured it).
  static let focus: CGFloat = 2
}

nonisolated extension CGFloat {
  /// `.stroke(.separator, lineWidth: .borderWidth.hairline)`.
  static var borderWidth: BorderWidth.Type { BorderWidth.self }
}
