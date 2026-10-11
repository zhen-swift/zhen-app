import SwiftUI

extension RootView {
  /// Whichever room the sidebar has selected.
  struct RoomContentView: View {
    let room: Room
    @Binding var selection: Set<DeviceItem.ID>
    @Binding var path: [Route]
    @Binding var search: String
    @Binding var activityFilter: ActivityFilter
    var searchFocused: FocusState<Bool>.Binding
    let onRename: (DeviceItem.ID) -> Void
    let onShowActivity: (String) -> Void

    var body: some View {
      switch room {
      case .devices:
        DevicesView(
          selection: $selection, path: $path, search: $search,
          onRename: onRename, onShowActivity: onShowActivity
        )
          .searchFocused(searchFocused)
      case .activity:
        ActivityView(search: $search, filter: $activityFilter)
          .searchFocused(searchFocused)
      }
    }
  }
}
