import SwiftUI

/// Corner radii, measured from the pixels of the original artboards.
///
/// A1 recorded cards at 10 and chips at 5; the pixels say 8 and 4. A capsule — the filter
/// pills, a toggle — is `Capsule()`, not a radius.
nonisolated enum CornerRadius {
  /// Chips: `private`, `GATEWAY`, `WINNER`.
  static let small: CGFloat = 4
  /// Fields, buttons, the sidebar selection.
  static let medium: CGFloat = 6
  /// Cards.
  static let large: CGFloat = 8
  /// The device tile in the detail header.
  static let xLarge: CGFloat = 10
}

nonisolated extension CGFloat {
  /// `.clipShape(.rect(cornerRadius: .cornerRadius.large))`.
  static var cornerRadius: CornerRadius.Type { CornerRadius.self }
}
