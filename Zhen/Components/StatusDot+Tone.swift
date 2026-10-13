import SwiftUI

extension StatusDot {
  /// What the dot says. Colours are the asset catalogue's status marks.
  enum Tone: CaseIterable {
    /// Answering now; an appearance.
    case online
    /// Not answering. A ring, not a dot.
    case offline
    /// Partial results; a port opened or closed.
    case warning
    /// An address changed.
    case info
    /// An identity merged or renamed: the app's own judgement, in the accent.
    case accent
    /// A device that disappeared.
    case neutral

    var color: Color {
      switch self {
      case .online: .statusOnline
      case .offline: .offlineRing
      case .warning: .statusWarning
      case .info: .statusInfo
      case .accent: .accent
      case .neutral: .textTertiary
      }
    }

    var isFilled: Bool { self != .offline }

    /// The mark drawn when the person has asked for Differentiate Without Colour: every
    /// tone a different shape, so none depends on telling a green from an amber. Offline
    /// keeps its ring, which is already a shape.
    var symbol: String? {
      switch self {
      case .online: "checkmark.circle.fill"
      case .offline: nil
      case .warning: "exclamationmark.triangle.fill"
      case .info: "arrow.left.arrow.right.circle.fill"
      case .accent: "link.circle.fill"
      case .neutral: "minus.circle.fill"
      }
    }

    var label: LocalizedStringResource {
      switch self {
      case .online: .online
      case .offline: .offline
      case .warning: .warning
      case .info: .changed
      case .accent: .merged
      case .neutral: .gone
      }
    }
  }
}
