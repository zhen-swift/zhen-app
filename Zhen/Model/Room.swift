import SwiftUI

/// The sidebar's rooms. Settings is a scene (⌘,), not a room.
enum Room: String, CaseIterable, Identifiable, Hashable, Codable {
  case devices
  case activity

  var id: Self { self }

  var title: LocalizedStringResource {
    switch self {
    case .devices: .devices
    case .activity: .activity
    }
  }

  var symbol: String {
    switch self {
    case .devices: "square.grid.2x2.fill"
    case .activity: "waveform.path.ecg"
    }
  }

  /// ⌘1, ⌘2: the only keyboard route between rooms, since the split view keeps the
  /// sidebar out of the Tab loop (DESIGN-FINDINGS §3).
  var shortcut: KeyEquivalent {
    switch self {
    case .devices: "1"
    case .activity: "2"
    }
  }
}
