// Sidebar.swift — three rooms and the only always-visible proof the app is alive.

import SwiftUI

/// The sidebar: a section label, the rooms, and a pinned scan-status footer.
public struct Sidebar: View {
    @Binding private var selection: Room
    private let deviceCount: Int
    private let eventCount: Int
    private let activity: ScanActivity
    private let target: String

    /// Creates a sidebar.
    ///
    /// - Parameters:
    ///   - selection: the current room.
    ///   - deviceCount: the badge beside Devices.
    ///   - eventCount: the badge beside Activity.
    ///   - activity: what the footer says.
    ///   - target: "10.10.20.0/24 · en0".
    public init(
        selection: Binding<Room>,
        deviceCount: Int,
        eventCount: Int,
        activity: ScanActivity,
        target: String
    ) {
        self._selection = selection
        self.deviceCount = deviceCount
        self.eventCount = eventCount
        self.activity = activity
        self.target = target
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Zhen")
                .padding(.horizontal, Metrics.sidebarTextInset)
                .padding(.bottom, Metrics.unit * 2)

            // One resolver over the room list, so every icon slot is the width of the
            // widest symbol and every label starts at the same x. It was a constant,
            // which meant the slot was right for the symbols that existed when somebody
            // measured it.
            VStack(spacing: 0) {
                ForEach(Room.allCases) { room in
                    SidebarRow(
                        room: room,
                        badge: badge(for: room),
                        isSelected: selection == room
                    ) { selection = room }
                }
            }
            .resolvesColumns()

            Spacer(minLength: 0)

            Divider().overlay(Palette.separator)
            ScanStatusFooter(activity: activity, target: target)
        }
        .padding(.top, Metrics.unit * 3)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func badge(for room: Room) -> Int? {
        switch room {
        case .devices: deviceCount
        case .activity: eventCount
        case .settings: nil
        }
    }
}

/// One sidebar room.
struct SidebarRow: View {
    let room: Room
    let badge: Int?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: Metrics.unit * 3) {
                Image(systemName: room.symbol)
                    .imageScale(.medium)
                    .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                    .measuredColumn(.sidebarIcon, alignment: .center)
                    .accessibilityHidden(true)
                Text(room.title)
                    .font(.sidebarRow)
                    .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                Spacer(minLength: 0)
                if let badge {
                    Text("\(badge)")
                        .font(.rowSubtitle)
                        // Monospaced digits so the badge does not jitter as the count
                        // changes during a scan. Without it the whole row twitches, and
                        // people notice without being able to name why.
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.horizontal, Metrics.sidebarPillTextInset)
            
            .background(
                RoundedRectangle(cornerRadius: Metrics.selectionRadius)
                    .fill(isSelected ? Palette.selection : PaletteColor.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Inset, and the pill's inset moved OUTSIDE the button to get it there.
        //
        // The ring was first drawn around the button at its old bounds, which included
        // the 8pt pill inset, so it ran to both edges of a 228pt sidebar and was cut
        // off on both sides. With the inset outside the button, the button's bounds ARE
        // the pill, and the ring is drawn just inside them: no clipping horizontally,
        // and no bleed into the row above and below, which have no vertical gap between
        // them for a ring to sit in.
        .zhenFocusRing(.inset(Metrics.selectionRadius))
        // Command-1, Command-2, Command-3. See `Room.shortcut` for why this is not a
        // convenience: it is the only way to change rooms without a mouse.
        .keyboardShortcut(room.shortcut, modifiers: .command)
        .padding(.horizontal, Metrics.sidebarPillInset)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge.map { "\(room.title), \($0)" } ?? room.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The pinned footer: a dot, a relative time, and the target.
///
/// **Never empty.** This is the only always-visible proof the app is alive, so before
/// the first scan it reads "Never scanned" rather than showing nothing.
struct ScanStatusFooter: View {
    let activity: ScanActivity
    let target: String

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.unit) {
            HStack(spacing: Metrics.unit * 2) {
                dot
                Text(headline)
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(target)
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Metrics.sidebarTextInset)
        .padding(.vertical, Metrics.unit * 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headline), \(target)")
    }

    @ViewBuilder private var dot: some View {
        switch activity {
        case .never:
            StatusDot(.offline)
        case .scanning:
            StatusDot(.scanning)
        case .idle:
            StatusDot(.online)
        case .partial:
            // Amber, because the run finished but did not finish completely. A green dot
            // over an incomplete scan is a lie of omission.
            Circle()
                .fill(Palette.Status.warning)
                // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
                // something — so it carries a size and scales with the type scale rather than
                // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
                // size that stay.
                .frame(width: Metrics.dotSize, height: Metrics.dotSize)
                .accessibilityHidden(true)
        }
    }

    private var headline: String {
        switch activity {
        case .never: "Never scanned"
        case .scanning: "Scanning…"
        case .idle(let relative): "Last scan \(relative)"
        case .partial(let relative, _): "Last scan \(relative) · partial"
        }
    }
}

#Preview("Sidebar — dark") {
    HStack(spacing: 0) {
        Sidebar(selection: .constant(.devices), deviceCount: 10, eventCount: 8,
                activity: .idle(relative: "4 min ago"), target: "10.10.20.0/24 · en0")
            .frame(width: Metrics.sidebarWidth)
            .background(Palette.surfaceRaised)
        Divider().overlay(Palette.separator)
        Sidebar(selection: .constant(.activity), deviceCount: 10, eventCount: 8,
                activity: .scanning(target: "10.10.20.0/24"), target: "10.10.20.0/24 · en0")
            .frame(width: Metrics.sidebarWidth)
            .background(Palette.surfaceRaised)
        Divider().overlay(Palette.separator)
        Sidebar(selection: .constant(.settings), deviceCount: 0, eventCount: 0,
                activity: .never, target: "10.10.20.0/24 · en0")
            .frame(width: Metrics.sidebarWidth)
            .background(Palette.surfaceRaised)
    }
    .frame(height: 520)
    .preferredColorScheme(.dark)
}

#Preview("Sidebar — light") {
    Sidebar(selection: .constant(.devices), deviceCount: 10, eventCount: 8,
            activity: .partial(relative: "4 min ago", unavailableSources: 2),
            target: "10.10.20.0/24 · en0")
        .frame(width: Metrics.sidebarWidth, height: 520)
        .background(Palette.surfaceRaised)
        .preferredColorScheme(.light)
}
