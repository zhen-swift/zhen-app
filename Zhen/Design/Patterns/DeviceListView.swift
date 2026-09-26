// DeviceListView.swift — the default room.

import SwiftUI

/// What the device list is currently showing.
public enum DeviceListState: Sendable, Hashable {
    /// No scan has ever run.
    case neverScanned
    /// A scan ran and nothing replied — most likely a denied permission.
    case nothingAnswered
    /// Devices, with an optional partial-run notice carried over from the last scan.
    case loaded(devices: [DeviceRowModel], degradations: [DegradationModel])
}

/// The device table, its header block, and every empty state it can land in.
public struct DeviceListView: View {
    private let state: DeviceListState
    @Binding private var searchText: String
    @Binding private var selection: DeviceRowModel.ID?
    private let onScan: () -> Void

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - state: what to show.
    ///   - searchText: the live search term, which filters the rows.
    ///   - selection: the selected row's id.
    ///   - onScan: invoked by "Scan Now" and by the empty state's button.
    public init(
        state: DeviceListState,
        searchText: Binding<String> = .constant(""),
        selection: Binding<DeviceRowModel.ID?> = .constant(nil),
        onScan: @escaping () -> Void = {}
    ) {
        self.state = state
        self._searchText = searchText
        self._selection = selection
        self.onScan = onScan
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            if case .loaded(_, let degradations) = state, !degradations.isEmpty {
                // Degradations do not evaporate when the scan ends.
                PartialRunStrip(unavailableSources: degradations.count, degradations: degradations)
                Divider().overlay(Palette.separator)
            }
            content
        }
        .background(Palette.surface)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader("Devices", subtitle: summary) {
                if case .loaded = state {
                    SearchField(text: $searchText)
                }
                PrimaryButton("Scan Now", action: onScan)
                    // Command-R, the Mac's refresh. Reachable by Tab as well — it is
                    // the second stop in this room — so this is convenience rather
                    // than access, unlike the room shortcuts.
                    .keyboardShortcut("r", modifiers: .command)
            }

            // The column header moved INTO the table, as a pinned section header. It
            // was here, above the scroll view, which put it in a different view tree
            // from the rows it heads — so the two could only agree on column widths by
            // both being told the same numbers. See `ColumnWidths`.
            Divider().overlay(Palette.separator)
        }
    }

    private var summary: String {
        switch state {
        case .neverScanned:
            return "Not scanned yet"
        case .nothingAnswered:
            return "0 devices"
        case .loaded(let devices, _):
            let online = devices.filter(\.isOnline).count
            let unidentified = devices.filter { $0.identification != .identified }.count
            return "\(devices.count) devices · \(online) online · \(unidentified) unidentified"
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch state {
        // Every branch scrolls, including the ones with nothing in them. See
        // `ScreenScroll`: the window draws its top and bottom bars only over a scrolling
        // detail column, so a screen that stops being one takes the chrome with it.
        case .neverScanned:
            ScreenScroll { EmptyStateView.neverScanned }
        case .nothingAnswered:
            ScreenScroll { EmptyStateView.nothingAnswered }
        case .loaded(let devices, _):
            let filtered = filter(devices)
            if filtered.isEmpty {
                // The header counts stay as they were: the network did not change
                // because somebody typed in a box.
                ScreenScroll { EmptyStateView.noMatches(for: searchText) }
            } else {
                table(filtered)
            }
        }
    }

    private func table(_ devices: [DeviceRowModel]) -> some View {
        ScrollView {
            // `LazyVStack` with a pinned section header, which buys two things at once.
            //
            // The header stays put while the rows scroll, which is A3's rule — the
            // header and anything describing the whole screen are pinned, only the
            // collection moves — and it now does so from INSIDE the scroll view, so
            // header and rows share one tree and one set of measured column widths.
            //
            // And it is lazy. The comment here used to argue the opposite: that a table
            // bounded by a /24 is at most 254 rows, so laziness buys nothing and costs
            // measurability. The bound is the wrong one — this is meant to hold bigger
            // networks than one subnet, and at that size materialising every row to
            // scroll past four of them is the cost.
            //
            // What laziness does cost is `fittingSize`: a lazy container cannot report
            // the width of children it has not built, so it under-reports. The layout
            // gate measures the resolved column widths instead, which are exact and do
            // not depend on what happens to be on screen.
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(devices) { device in
                        Button { selection = device.id } label: {
                            DeviceRow(device, isSelected: selection == device.id)
                        }
                        .buttonStyle(.plain)
                        .zhenFocusRing(.inset(Metrics.selectionRadius))
                        Divider().overlay(Palette.separator)
                    }
                } header: {
                    VStack(spacing: 0) {
                        DeviceTableHeader()
                        Divider().overlay(Palette.separator)
                    }
                    // Opaque, or the rows scroll visibly underneath it.
                    .background(Palette.surface)
                }
            }
        }
        .resolvesColumns()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func filter(_ devices: [DeviceRowModel]) -> [DeviceRowModel] {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return devices }
        return devices.filter {
            $0.name.localizedCaseInsensitiveContains(term)
                || $0.ip.localizedCaseInsensitiveContains(term)
                || ($0.mac?.localizedCaseInsensitiveContains(term) ?? false)
                || $0.subtitle.localizedCaseInsensitiveContains(term)
        }
    }
}

#Preview("Devices — dark") {
    DeviceListView(state: .loaded(devices: DeviceRowModel.sampleNetwork, degradations: []))
        .frame(width: 1182, height: 700)
        .preferredColorScheme(.dark)
}

#Preview("Devices — light") {
    DeviceListView(state: .loaded(devices: DeviceRowModel.sampleNetwork, degradations: []))
        .frame(width: 1182, height: 700)
        .preferredColorScheme(.light)
}

#Preview("Devices — partial run") {
    DeviceListView(state: .loaded(devices: DeviceRowModel.sampleNetwork,
                                  degradations: DegradationModel.sampleDegradations))
        .frame(width: 1182, height: 700)
        .preferredColorScheme(.dark)
}

#Preview("Devices — never scanned") {
    DeviceListView(state: .neverScanned)
        .frame(width: 1182, height: 520)
        .preferredColorScheme(.dark)
}

#Preview("Devices — nothing answered") {
    DeviceListView(state: .nothingAnswered)
        .frame(width: 1182, height: 520)
        .preferredColorScheme(.light)
}

#Preview("Devices — no matches") {
    DeviceListView(state: .loaded(devices: DeviceRowModel.sampleNetwork, degradations: []),
                   searchText: .constant("printer"))
        .frame(width: 1182, height: 520)
        .preferredColorScheme(.dark)
}

// ── Narrow variants ────────────────────────────────────────────────────────────
//
// Added in stage 3. The previews were 59 canvases each showing one condition: a light
// and a dark copy of the same layout at the same width. A design system whose previews
// all agree cannot show a layout failing.
//
// Width, and not type size. `RESPONSIVE-plan.md` asks for both, and stage 1 measured
// Dynamic Type to be inert on macOS — `@ScaledMetric` and text styles both return the
// same value at `.large` and `.accessibility3`, so a type variant would be a second
// copy of the first. Width is what a Mac window actually varies.

#Preview("Devices — narrow") {
    DeviceListView(state: .loaded(devices: DeviceRowModel.sampleNetwork, degradations: []))
        .frame(width: 620, height: 640)
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}
