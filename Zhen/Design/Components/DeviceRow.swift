// DeviceRow.swift — the heart of the app.
//
// Two lines, five columns, 52pt minimum. The second line is the entire product for an
// unidentified device, and on a real network most of the rows ARE unidentified — so
// this row is designed for the empty case first and the full case second.

import SwiftUI

/// One device in the table.
public struct DeviceRow: View {
    private let device: DeviceRowModel
    private let isSelected: Bool

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - device: the flat model. The row does not fetch and does not know a store
    ///     exists.
    ///   - isSelected: whether to draw the selection fill.
    public init(_ device: DeviceRowModel, isSelected: Bool = false) {
        self.device = device
        self.isSelected = isSelected
    }

    public var body: some View {
        // Real spacing between columns, and it has to be here rather than in the
        // widths. When the columns were fixed constants each carried slack, so a
        // zero-spacing HStack looked fine; measured columns are exactly as wide as
        // their content, and at zero spacing "Identified" ran straight into
        // "10.10.20.2" with no gap at all.
        HStack(spacing: Metrics.unit * 4) {
            StatusDot(device.presence)
                .measuredColumn(.statusGutter)

            VStack(alignment: .leading, spacing: Metrics.unit / 2) {
                HStack(spacing: Metrics.unit + 2) {
                    Text(device.name)
                        .font(.rowTitle)
                        // Full strength EVEN OFFLINE. The artboards dim the whole row,
                        // which makes a sleeping laptop read as disabled rather than as
                        // "seen two hours ago". Only the secondary content dims below.
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                    if device.isGateway { Chip("gateway", style: .accent) }
                }
                Text(device.subtitle)
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                // Under the subtitle, not beside it, and not in either narrow column.
                //
                // A3 puts this in the name column's register: the subtitle is what IS
                // known about a device — "randomized MAC · no vendor · in ARP table, no
                // ping reply" — and an address that has since been taken is a fact of
                // exactly that kind. The IP column cannot hold it (104pt at its
                // minimum, a dotted quad and nothing else, so the address wrapped
                // mid-octet) and LAST SEEN is tighter still at 64.
                //
                // Its OWN LINE rather than sharing the subtitle's, because sharing
                // costs horizontal space the subtitle does not have. Measured: the row
                // wants 1046pt inline against a declared minimum window of 1000, so at
                // the minimum size the subtitle gives up about 46pt and truncates —
                // which is the defect `Column.nameMin = 200` was measured to close,
                // re-opened to pay for a chip. A line costs height, and this row is
                // built to grow in height rather than clip.
                if device.addressState == .reassigned {
                    Chip("reassigned")
                }
            }
            // The name column is the flexible one: everything else sizes to its
            // content and the name takes what is left, which is why the longest
            // subtitle truncates rather than forcing the window wider.
            //
            // Capped, though. A MEASURE limit — see `Metrics.Detail.nameMeasure` — so a
            // wide display does not run the subtitle across most of the window with the
            // data columns pushed out of the eye's reach. The `Spacer` after it is what
            // keeps those columns where they were: without it the cap would pull them
            // left and leave the row trailing off into nothing.
            .frame(minWidth: Metrics.Detail.nameMinMeasure,
                   maxWidth: Metrics.Detail.nameMeasure, alignment: .leading)
            .padding(.trailing, Metrics.unit * 3)

            // The row's only flexible child, and it has to be here.
            //
            // Once the name is capped, nothing in this HStack wants the leftover width.
            // An HStack with no flexible child takes its ideal size and is CENTRED in
            // what the parent offers, so every row drifted toward the middle of a wide
            // window while the header — which has this same spacer — stayed at the
            // leading edge. The columns sheared by a couple of hundred points.
            Spacer(minLength: 0)

            // Measured, not declared. Each of these sizes to the widest cell in its
            // own column across the whole table, header included, through
            // `deviceColumn`. The nine constants that used to live here are what
            // squeezed the sidebar from 228pt to 134pt.
            ConfidenceMeter(device.identification)
                .measuredColumn(.identity)

            // The address carries the row's visual weight, so it only gets that weight
            // when it is the device's address NOW. An absent device keeps its last
            // known address — dropping the row would silently shrink the network — but
            // drawn at full strength beside a live row holding the same address, it
            // reads as the scanner reporting one machine twice.
            //
            // The chip is the sentence a person needs and it is the only claim made:
            // this address moved, which the app watched happen. Whether the two
            // records are one device is a different question and nothing here answers
            // it.
            // Nothing but the address, at every width the window allows. The contrast
            // still carries which device holds it — full strength when the device
            // answered, secondary when this is where it last did — and that half was
            // never the problem.
            Text(device.ip)
                .font(.mono)
                .foregroundStyle(device.addressState == .current
                                 ? Palette.textPrimary : Palette.textSecondary)
                .measuredColumn(.ip)

            HStack(spacing: Metrics.unit + 2) {
                // An em dash, never an empty cell. A device with no neighbour-table
                // entry has an unknown MAC, and a blank there reads as a rendering bug.
                Text(device.mac ?? "—")
                    .font(.mono)
                    .foregroundStyle(Palette.textSecondary)
                if device.isPrivateMAC { Chip("private") }
            }
            .measuredColumn(.mac)

            Text(device.lastSeen)
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: true, vertical: false)
                .measuredColumn(.lastSeen, alignment: .trailing)
        }
        .padding(.horizontal, Metrics.rowInset)
        .padding(.vertical, Metrics.unit * 2)
        // No minimum height. The row is padding plus content, so it is as tall as what
        // it holds — two lines for most devices, three for one carrying a chip — and it
        // grows rather than clipping when the content does. The 52pt floor that was
        // here came from the artboards and was doing nothing that the padding was not
        // already doing, except deciding the answer in advance.
        .background(
            RoundedRectangle(cornerRadius: Metrics.selectionRadius)
                .fill(isSelected ? Palette.selection : PaletteColor.clear)
        )
        // Secondary content only. The name stays at full contrast — see above.
        .opacity(device.presence == .offline ? 0.75 : 1)
        .contentShape(Rectangle())
        // One element reading one sentence, not five the user has to swipe through.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(device.accessibilityDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The column header row above the table.
///
/// **Plainly static, and that is a decision.** These look sortable and are not, so they
/// carry no chevron and no hover affordance. A header that invites a click and swallows
/// it is worse than one that never suggested it could be clicked.
///
/// It sizes through the same `deviceColumn` mechanism the rows do, so a header that
/// resolves to a different width than the rows beneath it is no longer possible. It
/// used to be possible and was prevented by writing the same nine constants out twice.
public struct DeviceTableHeader: View {
    /// Creates the header row.
    public init() {}

    public var body: some View {
        HStack(spacing: Metrics.unit * 4) {
            // Zero in BOTH axes. `Color` has no intrinsic size and takes whatever it is
            // offered, so the height matters first: a width-only spacer stretched the
            // header row to the full height of the screen, which read as a mysterious
            // 200pt gap above the column titles.
            //
            // The width is worth less than it looks. The measurement copy inside
            // `measuredColumn` uses `fixedSize(horizontal: true)`, and an unpinned
            // `Color` under that reports more than nothing — measured at 1600pt, the
            // gutter resolves 2pt wider and every name in the table, header included,
            // starts 2pt further right. Aligned either way; pinned so the column is the
            // width of the only real cell in it, the dot.
            Color.clear.frame(width: 0, height: 0).measuredColumn(.statusGutter)
            // Identical to the row's name column — the cap AND the spacer after it, not
            // one of the two. Giving the header a spacer the row lacked left the row
            // with no flexible child at all, so it centred itself in a wide window and
            // the columns sheared 240pt from their own heading.
            label("Name")
                .frame(minWidth: Metrics.Detail.nameMinMeasure,
                   maxWidth: Metrics.Detail.nameMeasure, alignment: .leading)
                .padding(.trailing, Metrics.unit * 3)
            Spacer(minLength: 0)
            label("Identity").measuredColumn(.identity)
            label("IP address").measuredColumn(.ip)
            label("MAC address").measuredColumn(.mac)
            label("Last seen").measuredColumn(.lastSeen, alignment: .trailing)
        }
        .padding(.horizontal, Metrics.rowInset)
        .padding(.vertical, Metrics.unit * 2)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.columnHeader)
            .textCase(.uppercase)
            .tracking(Tracking.label)
            .foregroundStyle(Palette.textSecondary)
    }
}

#Preview("DeviceRow — dark") {
    VStack(spacing: 0) {
        DeviceTableHeader()
        Divider().overlay(Palette.separator)
        ForEach(DeviceRowModel.sampleNetwork) { device in
            DeviceRow(device)
            Divider().overlay(Palette.separator)
        }
    }
    .frame(width: 1000)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("DeviceRow — light") {
    VStack(spacing: 0) {
        DeviceTableHeader()
        Divider().overlay(Palette.separator)
        ForEach(DeviceRowModel.sampleNetwork) { device in
            DeviceRow(device)
            Divider().overlay(Palette.separator)
        }
    }
    .frame(width: 1000)
    .background(Palette.surface)
    .preferredColorScheme(.light)
}

#Preview("DeviceRow — selected and large type") {
    VStack(spacing: 0) {
        DeviceRow(.jcMacBookPro, isSelected: true)
        Divider().overlay(Palette.separator)
        DeviceRow(.anonymousNeighbourOnly)
        Divider().overlay(Palette.separator)
        DeviceRow(.offlineSample)
    }
    .frame(width: 1100)
    .background(Palette.surface)
    .environment(\.dynamicTypeSize, .accessibility2)
    .preferredColorScheme(.dark)
}

// ── A narrow variant ───────────────────────────────────────────────────────────
//
// Added in stage 3. The previews were pairs of the same layout at the same width, so
// none of them could show the table failing. Width and not type size: stage 1 measured
// Dynamic Type to be inert on macOS, so a type variant is a second copy of the first.
#Preview("DeviceRow — narrow") {
    VStack(spacing: 0) {
        DeviceTableHeader()
        Divider().overlay(Palette.separator)
        ForEach(DeviceRowModel.sampleNetwork.prefix(4)) { device in
            DeviceRow(device)
            Divider().overlay(Palette.separator)
        }
    }
    .resolvesColumns()
    .frame(width: 620)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}
