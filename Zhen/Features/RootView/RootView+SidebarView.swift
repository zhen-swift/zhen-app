import SwiftUI

extension RootView {
  /// The two rooms, with counts, and the scan status pinned underneath.
  ///
  /// Selection is the system highlight, not the artboards' `#373548` tint: tertiary text
  /// measures 3.89:1 on that tint, and the system's follows the person's accent colour.
  struct SidebarView: View {
    @Binding var room: Room
    @Environment(NetworkModel.self) private var model

    var body: some View {
      List(selection: Binding(get: { room }, set: { if let new = $0 { room = new } })) {
        Section {
          ForEach(Room.allCases) { item in
            Label(item.title, systemImage: item.symbol)
              .badge(count(for: item))
              .tag(item)
              .accessibilityIdentifier("sidebarRoom-\(item.rawValue)")
          }
        } header: {
          Text(.zhen).sectionLabel()
        }
      }
      .listStyle(.sidebar)
      .accessibilityIdentifier("sidebar")
      .safeAreaInset(edge: .bottom, spacing: .zero) {
        SidebarFooterView()
      }
    }

    private func count(for room: Room) -> Int {
      switch room {
      case .devices: model.devices.count
      case .activity: model.eventsInWindow.count
      }
    }
  }
}
