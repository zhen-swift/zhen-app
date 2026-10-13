import SwiftUI

extension Chip {
  /// The two chips the artboards draw.
  enum Style {
    /// A quiet fact: `private` beside a randomised MAC.
    case neutral
    /// The app's own classification: `GATEWAY`, `WINNER`. Capitals, in the accent.
    case accent

    var fill: Color {
      switch self {
      case .neutral: .surfaceField
      case .accent: .accentFill
      }
    }

    var foreground: Color {
      switch self {
      case .neutral: .textTertiary
      case .accent: .accent
      }
    }

    var font: Font {
      switch self {
      case .neutral: .caption
      case .accent: .caption.bold()
      }
    }

    var textCase: Text.Case? {
      switch self {
      case .neutral: nil
      case .accent: .uppercase
      }
    }
  }
}
