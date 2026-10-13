import SwiftUI
import ZhenCore

extension DerivedEvent.Kind {
  /// The small capitals beside an event.
  var label: LocalizedStringResource {
    switch self {
    case .appeared: .appeared
    case .disappeared: .left
    case .ipChanged: .addressChanged
    case .renamed: .renamed
    case .merged: .merged
    case .portOpened: .portOpened
    case .portClosed: .portClosed
    }
  }

  /// Port events are A2's warning amber, both ways: a port changing is the thing on this
  /// screen most likely to need doing something about.
  var tone: StatusDot.Tone {
    switch self {
    case .appeared: .online
    case .disappeared: .neutral
    case .ipChanged: .info
    case .renamed, .merged: .accent
    case .portOpened, .portClosed: .warning
    }
  }

  /// The text variant of the tone: the vivid marks are unreadable as words on white.
  var textColor: Color {
    switch self {
    case .appeared: .statusOnlineText
    case .disappeared: .textSecondary
    case .ipChanged: .statusInfoText
    case .renamed, .merged: .accent
    case .portOpened, .portClosed: .statusWarningText
    }
  }
}

extension DerivedEvent {
  var date: Date { Date(timeIntervalSince1970: at.timeIntervalSince1970) }
}
