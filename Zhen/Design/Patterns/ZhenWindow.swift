// ZhenWindow.swift — the whole window, composed from fixtures.
//
// `NavigationSplitView`, not a hand-rolled `HStack`. The sidebar toggle, the correct
// material behind the traffic lights, keyboard traversal and state restoration all come
// free, and any hand-rolled version is subtly wrong on at least one of them.
//
// ── One window, previewed and shipped ───────────────────────────────────────────
//
// There used to be two. This file built a `NavigationSplitView` for the previews and
// the app built its own for the product, and they had already drifted — the app's
// sidebar had a background this one did not.
//
// That is not a tidiness complaint. It is the direct reason a real layout defect
// survived a design review with 57 previews behind it: the sidebar shrank from 228pt to
// 134pt as the window narrowed, in the window that ships, while every preview exercised
// a different object. A defect you cannot see is a defect you cannot fix.
//
// So `ZhenWindow` owns the split-view CONFIGURATION — the pinned column width, the
// style — and takes its two columns as parameters. The previews pass fixtures through
// `FixtureWindow` below; the app passes live views. Both get the same window.

import SwiftUI

/// The window: a pinned sidebar, a detail column, and nothing else.
///
/// `NavigationSplitView`, not a hand-rolled `HStack`. The sidebar toggle, the correct
/// material behind the traffic lights, keyboard traversal and state restoration all come
/// free, and a hand-rolled version is subtly wrong on at least one of them.
public struct ZhenWindow<SidebarContent: View, DetailContent: View>: View {
    private let sidebar: () -> SidebarContent
    private let detail: () -> DetailContent

    /// Creates the window from its two columns.
    public init(
        @ViewBuilder sidebar: @escaping () -> SidebarContent,
        @ViewBuilder detail: @escaping () -> DetailContent
    ) {
        self.sidebar = sidebar
        self.detail = detail
    }

    public var body: some View {
        NavigationSplitView {
            sidebar()
                .background(Palette.surfaceRaised)
                // **Pinned, not preferred.** A single-value column width is a
                // PREFERENCE: under `.balanced`, a detail column that cannot meet its
                // minimum takes the difference from here, and the navigation is what
                // silently gets smaller. Equal min, ideal and max removes the give, so
                // the pressure has to land somewhere it can be refused — the window's
                // own minimum, `Metrics.windowMinWidth`, which is measured by rendering
                // this window and finding where the table stops fitting the pane this
                // pinning leaves it.
                .navigationSplitViewColumnWidth(
                    min: Metrics.sidebarWidth,
                    ideal: Metrics.sidebarWidth,
                    max: Metrics.sidebarWidth
                )
        } detail: {
            detail()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// The fixture-driven window, for previews and for looking at a whole screen at once.
///
/// Owns the navigation state the app's view model owns in the product, and passes the
/// same two columns through the same ``ZhenWindow``. What is previewed here is the
/// window that ships; only the contents differ.
public struct FixtureWindow: View {
    @State private var room: Room
    @State private var searchText = ""
    @State private var selection: DeviceRowModel.ID?
    @State private var category: EventCategory = .all
    private let devices: [DeviceRowModel]
    private let degradations: [DegradationModel]

    /// Creates the window.
    public init(
        room: Room = .devices,
        devices: [DeviceRowModel] = DeviceRowModel.sampleNetwork,
        degradations: [DegradationModel] = []
    ) {
        self._room = State(initialValue: room)
        self.devices = devices
        self.degradations = degradations
    }

    public var body: some View {
        ZhenWindow {
            Sidebar(
                selection: $room,
                deviceCount: devices.count,
                eventCount: EventDayModel.sampleDays.flatMap(\.events).count,
                activity: degradations.isEmpty
                    ? .idle(relative: "4 min ago")
                    : .partial(relative: "4 min ago", unavailableSources: degradations.count),
                target: "10.10.20.0/24 · en0"
            )
        } detail: {
            detail
        }
    }

    @ViewBuilder private var detail: some View {
        switch room {
        case .devices:
            if let selection, let device = Self.detailModel(for: selection) {
                DeviceDetailView(device) { self.selection = nil }
            } else {
                DeviceListView(
                    state: .loaded(devices: devices, degradations: degradations),
                    searchText: $searchText,
                    selection: $selection
                )
            }
        case .activity:
            ActivityView(days: EventDayModel.sampleDays,
                         buckets: HistogramBucket.sampleWindow,
                         category: $category)
        case .settings:
            SettingsView()
        }
    }

    /// The fixture detail for a row, where one exists.
    private static func detailModel(for id: DeviceRowModel.ID) -> DeviceDetailModel? {
        switch id {
        case "10.10.20.8": .jcMacBookPro
        case "10.10.20.2": .salaDeEntretenimiento
        case "10.10.20.12": .unidentified
        default: nil
        }
    }
}

#Preview("Window — dark") {
    FixtureWindow()
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("Window — light") {
    FixtureWindow()
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Window — partial run") {
    FixtureWindow(degradations: DegradationModel.sampleDegradations)
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("Window — activity") {
    FixtureWindow(room: .activity)
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("Window — settings") {
    FixtureWindow(room: .settings)
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Window — at the minimum width") {
    // The size the window refuses to go below. Every column is at its minimum here and
    // the sidebar is still 228pt, which is the whole point of the fix.
    FixtureWindow()
        .frame(width: Metrics.windowMinWidth, height: 620)
        .preferredColorScheme(.dark)
}
