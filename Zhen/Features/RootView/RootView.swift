import SwiftUI
import ZhenCore

/// The main window: the sidebar's two rooms, and a stack in the detail column that pushes a
/// device. Owns the window's navigation state and restores it on relaunch.
struct RootView: View {
  @Environment(NetworkModel.self) var model
  @SceneStorage("room") var room: Room = .devices
  @SceneStorage("selection") var storedSelection = ""
  @SceneStorage("path") var storedPath = ""
  @SceneStorage("activityFilter") var activityFilter: ActivityFilter = .all
  @State var selection: Set<DeviceItem.ID> = []
  @State var path: [Route] = []
  @State var search = ""
  @State var renaming: RenameRequest?
  @State var restored = false
  @FocusState var searchFocused: Bool
  @AppStorage(Preferences.Key.scanInterval) var scanInterval = 0

  var body: some View {
    NavigationSplitView {
      SidebarView(room: $room)
        .navigationSplitViewColumnWidth(min: .windowSize.sidebarMinimum, ideal: .windowSize.sidebarIdeal)
    } detail: {
      NavigationStack(path: $path) {
        RoomContentView(
          room: room, selection: $selection, path: $path, search: $search,
          activityFilter: $activityFilter, searchFocused: $searchFocused, onRename: rename,
          onShowActivity: showActivity
        )
          .navigationDestination(for: Route.self) { route in
            switch route {
            case .device(let id):
              DeviceDetailView(id: id, onRename: rename, onShowActivity: showActivity)
            }
          }
      }
    }
    // The window's minimum is measured: the sidebar plus the device table with every
    // column whole. A constant here let the split view take the difference out of the
    // sidebar, pushing it off the window — old defect F2, caught again by the gate.
    .frame(minWidth: minimumWidth, minHeight: .windowSize.minimumHeight)
    .task {
      // Before the first await: anything the person (or a test) does while history loads
      // must not be undone by a late reset.
      startFresh()
      await model.load()
      restore()
    }
    .task(id: model.scan.runToken) { await model.performScan() }
    .task(id: model.portScanTarget) { await model.performPortScan() }
    .task { await model.watchHistory() }
    .task(id: scanInterval) { await model.scanAutomatically(every: scanInterval) }
    .onChange(of: selection) { storedSelection = Self.encode(selection) }
    .onChange(of: path) { storedPath = Self.encode(path) }
    .onChange(of: room) {
      path = []
      search = ""
    }
    .sheet(item: $renaming) { request in
      RenameSheet(id: request.id)
    }
    .focusedSceneValue(\.windowActions, actions)
  }
}

#Preview("Window — dark") {
  RootView()
    .environment(PreviewContainer.model(.home))
    .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
    .preferredColorScheme(.dark)
}

#Preview("Window — unidentified, light") {
  RootView()
    .environment(PreviewContainer.model(.unidentified))
    .frame(width: .windowSize.minimumWidth, height: .windowSize.minimumHeight)
    .preferredColorScheme(.light)
}
