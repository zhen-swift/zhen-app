import SwiftUI
import ZhenCore

/// The default room: every device history knows, present and absent.
///
/// A `Table` — sortable columns, multi-selection, a context menu — because on a Mac a list
/// of records is a table. While a scan runs the live scan takes over this room, then hands
/// it back.
struct DevicesView: View {
  @Binding var selection: Set<DeviceItem.ID>
  @Binding var path: [Route]
  @Binding var search: String
  let onRename: (DeviceItem.ID) -> Void
  var onShowActivity: (String) -> Void = { _ in }
  @Environment(NetworkModel.self) var model
  @State var sortOrder = DeviceItem.defaultOrder
  /// The sort, and which columns show in what order, kept with the window across launches
  /// like the room and the selection.
  @SceneStorage("deviceSort") var storedSort = ""
  @SceneStorage("deviceColumns") var columnCustomization: TableColumnCustomization<DeviceItem>
  /// The table holds focus when the room opens, so arrows select and Return opens at once.
  @FocusState var tableFocused: Bool

  var body: some View {
    Group {
      if model.scan.phase != .idle {
        LiveScanView()
      } else if !model.hasLoaded {
        // Never a spinner over an empty table: history loads in milliseconds, and the
        // first thing a person sees should be devices, not a wait.
        Color.clear
      } else if model.latestRun == nil, model.devices.isEmpty {
        NeverScannedView()
      } else if model.devices.isEmpty {
        NothingAnsweredView()
      } else {
        DeviceTableView(
          rows: rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization,
          onOpen: open, onRename: onRename, onShowActivity: onShowActivity
        )
        .focused($tableFocused)
        .defaultFocus($tableFocused, true)
        // Coming back from a device, the table takes focus again: Return and the arrows
        // should act on the list the person is looking at, not on the search field.
        .onAppear {
          tableFocused = true
          sortOrder = SortStorage.decode(storedSort)
        }
        .onChange(of: sortOrder) { storedSort = SortStorage.encode(sortOrder) }
        .overlay {
          if rows.isEmpty {
            ContentUnavailableView(
              String(localized: .noMatches), systemImage: "magnifyingglass",
              description: Text(.noDeviceMatches(search))
            )
            .accessibilityIdentifier("noMatches")
          }
        }
        .safeAreaInset(edge: .top, spacing: .zero) {
          if model.latestRunIsPartial {
            PartialRunNoticeView()
          }
        }
      }
    }
    .navigationTitle(String(localized: .devices))
    .navigationSubtitle(model.devicesSummary)
    .searchable(text: $search, placement: .toolbar, prompt: .searchDevices)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        ScanControlView()
      }
    }
  }

  private func open(_ id: DeviceItem.ID) {
    path.append(.device(id))
  }
}

#Preview("Devices — dark") {
  NavigationStack {
    DevicesView(selection: .constant([]), path: .constant([]), search: .constant(""), onRename: { _ in })
  }
  .environment(PreviewContainer.model(.home))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
  .preferredColorScheme(.dark)
}

#Preview("Devices — every host unidentified") {
  NavigationStack {
    DevicesView(selection: .constant([]), path: .constant([]), search: .constant(""), onRename: { _ in })
  }
  .environment(PreviewContainer.model(.unidentified))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
  .preferredColorScheme(.light)
}

#Preview("Devices — partial run") {
  NavigationStack {
    DevicesView(selection: .constant([]), path: .constant([]), search: .constant(""), onRename: { _ in })
  }
  .environment(PreviewContainer.model(.partial))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
}

#Preview("Devices — never scanned") {
  NavigationStack {
    DevicesView(selection: .constant([]), path: .constant([]), search: .constant(""), onRename: { _ in })
  }
  .environment(PreviewContainer.model(.empty))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
}
