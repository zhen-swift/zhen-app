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

    var label: LocalizedStringKey {
      switch self {
      case .online: "Online"
      case .offline: "Offline"
      case .warning: "Warning"
      case .info: "Changed"
      case .accent: "Merged"
      case .neutral: "Gone"
      }
    }
  }
}
