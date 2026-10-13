import SwiftUI
import UniformTypeIdentifiers
import ZhenCore

/// The main window: the sidebar's two rooms, and a stack in the detail column that pushes a
/// device. Owns the window's navigation state and restores it on relaunch.
struct RootView: View {
  @Environment(NetworkModel.self) var model
  @SceneStorage("room") var room: Room = .devices
  @SceneStorage("selection") var storedSelection = ""
  @SceneStorage("path") var storedPath = ""
  @SceneStorage("activityFilter") var activityFilter: ActivityFilter = .all
  // The Devices table's, declared here only so a launch that does not restore can clear
  // them with the rest (`startFresh`): same keys, same scene, same values.
  @SceneStorage("deviceSort") var storedSort = ""
  @SceneStorage("deviceColumns") var columnCustomization: TableColumnCustomization<DeviceItem>
  @State var selection: Set<DeviceItem.ID> = []
  @State var path: [Route] = []
  @State var search = ""
  @State var renaming: RenameRequest?
  @State var restored = false
  /// The export being saved, while its panel is up.
  @State var exporting: HistoryDocument?
  @FocusState var searchFocused: Bool
  @AppStorage(Preferences.Key.keepInMenuBar) var keepInMenuBar = false

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
    // The window runs scans unless the menu bar item does (`ScanHost`).
    .scanHost(model, isActive: !keepInMenuBar)
    .onChange(of: selection) { storedSelection = Self.encode(selection) }
    .onChange(of: path) { storedPath = Self.encode(path) }
    .onChange(of: room) {
      path = []
      search = ""
    }
    .sheet(item: $renaming) { request in
      RenameSheet(id: request.id)
    }
    .fileExporter(
      isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }),
      document: exporting, contentType: .json, defaultFilename: NetworkModel.exportFilename
    ) { _ in exporting = nil }
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
