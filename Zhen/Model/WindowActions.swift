import SwiftUI

/// What the menu bar can ask the front window to do, published with `.focusedSceneValue`.
///
/// Menu commands reach the window through this and nothing else — no global singleton —
/// so a command always acts on the window the person is looking at.
struct WindowActions {
  var room: Room
  var isScanning: Bool
  var selectionCount: Int
  var canGoBack: Bool
  var showRoom: (Room) -> Void
  var activityFilter: ActivityFilter
  var setActivityFilter: (ActivityFilter) -> Void
  var openSelection: () -> Void
  var scanSelectionPorts: () -> Void
  var renameSelection: () -> Void
  var goBack: () -> Void
  var focusSearch: () -> Void
  var copyAddresses: () -> Void
  var copyMACAddresses: () -> Void
  var showSelectionInActivity: () -> Void
}

extension FocusedValues {
  @Entry var windowActions: WindowActions?
}
