import SwiftUI
import ZhenCore

extension DerivedEvent.Kind {
  /// The small capitals beside an event.
  var label: LocalizedStringKey {
    switch self {
    case .appeared: "Appeared"
    case .disappeared: "Left"
    case .ipChanged: "Address changed"
    case .renamed: "Renamed"
    case .merged: "Merged"
    }
  }

  var tone: StatusDot.Tone {
    switch self {
    case .appeared: .online
    case .disappeared: .neutral
    case .ipChanged: .info
    case .renamed, .merged: .accent
    }
  }

  /// The text variant of the tone: the vivid marks are unreadable as words on white.
  var textColor: Color {
    switch self {
    case .appeared: .statusOnlineText
    case .disappeared: .textSecondary
    case .ipChanged: .statusInfoText
    case .renamed, .merged: .accent
    }
  }
}

extension DerivedEvent {
  var date: Date { Date(timeIntervalSince1970: at.timeIntervalSince1970) }
}
