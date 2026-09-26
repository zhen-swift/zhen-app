// DeviceDetailView.swift — one device, one column of cards.
//
// ── The layout without Omada ─────────────────────────────────────────────────────
//
// The artboards use two columns: cards on the left, an Omada panel and recent events on
// the right. Omada is dropped from the project, and with its panel gone the right column
// is half empty — so this reflows to a SINGLE column of cards at content width. A
// two-column layout with one column holding a single short card looks like something
// failed to load.

import SwiftUI

/// The detail screen for one device.
public struct DeviceDetailView: View {
    private let device: DeviceDetailModel
    private let onBack: () -> Void

    /// Creates the screen.
    public init(_ device: DeviceDetailModel, onBack: @escaping () -> Void = {}) {
        self.device = device
        self.onBack = onBack
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Palette.separator)
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.unit * 5) {
                    headerBlock
                    identityCard
                    knownByCard
                    portsCard
                    eventsCard
                }
                .padding(Metrics.contentInset)
                // A MEASURE limit, not a box. Prose stops being readable past roughly 70
                // characters a line however wide the window is, so this is a typographic
                // constraint on line length. The plan names it as the other kind that stays.
                .frame(maxWidth: Metrics.Detail.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Palette.surface)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: Metrics.unit * 3) {
            Button(action: onBack) {
                HStack(spacing: Metrics.unit) {
                    Image(systemName: Symbols.back).imageScale(.small)
                    Text("Devices").font(.control)
                }
                .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
            .zhenFocusRing(.rounded(Metrics.chipRadius))
            .accessibilityLabel("Back to devices")

            Spacer(minLength: 0)
            // Rename is LOCAL ONLY — there is no controller to write back to. The value
            // is stored as a user-supplied name that outranks every discovered source,
            // and "Known by" shows it as source "You", always the winner. Making that
            // visible is what stops a person wondering why their name stuck.
            SecondaryButton("Rename…")
            SecondaryButton("Rescan Device")
        }
        .padding(.horizontal, Metrics.contentInset)
        .padding(.vertical, Metrics.unit * 3)
    }

    // MARK: Header

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: Metrics.unit * 4) {
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .fill(Palette.surfaceRaised)
                .overlay(
                    Image(systemName: device.symbol)
                        .imageScale(.large)
                        .foregroundStyle(Palette.accent)
                )
                // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
                // something — so it carries a size and scales with the type scale rather than
                // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
                // size that stay.
                .frame(width: Metrics.deviceTileSize, height: Metrics.deviceTileSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.unit) {
                HStack(spacing: Metrics.unit * 2) {
                    Text(device.name)
                        .font(.screenTitle)
                        .foregroundStyle(Palette.textPrimary)
                    StatusDot(device.presence)
                    Text(device.presence == .offline ? "Offline" : "Online")
                        .font(.control)
                        .foregroundStyle(Palette.textSecondary)
                }
                Text(device.summary)
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Metrics.unit * 4)

            VStack(alignment: .trailing, spacing: Metrics.unit * 2) {
                KeyValueGrid(device.headerFacts, alignment: .trailing)
                if device.isPrivateMAC { Chip("private") }
            }
        }
    }

    // MARK: Cards

    /// Its own resolver: this card's table and the ports card's are different
    /// tables, and sharing one would make both as wide as the wider.
    private var identityCard: some View {
        Card(
            title: "Identity history",
            // The ONE place identity-key stability appears in the whole app.
            caption: device.identityCaption
        ) {
            CardRows(device.identityHistory) { record in
                HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 3) {
                    Circle()
                        .fill(record.isCurrent ? Palette.accent : Palette.textSecondary)
                        // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
                        // something — so it carries a size and scales with the type scale rather than
                        // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
                        // size that stay.
                        .frame(width: Metrics.unit + 2, height: Metrics.unit + 2)
                        .accessibilityHidden(true)
                    Text(record.mac)
                        .font(.mono)
                        .foregroundStyle(Palette.textPrimary)
                        .measuredColumn(.detailMAC)
                    Text(record.reason)
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Metrics.unit * 2)
                    Text(record.range)
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(Metrics.cardPadding)
                .accessibilityElement(children: .combine)
            }
        }
        .resolvesColumns()
    }

    private var knownByCard: some View {
        Card(title: "Known by", caption: "competing names by source — highest-trust source wins") {
            CardRows(device.names) { candidate in
                HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 3) {
                    Text(candidate.source)
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                        .measuredColumn(.detailSource)
                    // A source that offered nothing is SHOWN, not hidden. The absence is
                    // information: it is how a person sees that we asked and got no
                    // answer, rather than that we never asked.
                    Text(candidate.candidate ?? candidate.absenceNote)
                        .font(.control)
                        .foregroundStyle(candidate.candidate == nil
                                         ? Palette.textSecondary : Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Metrics.unit * 2)
                    if candidate.isWinner { Chip("winner", style: .accent) }
                }
                .padding(Metrics.cardPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(candidate.source): \(candidate.candidate ?? candidate.absenceNote)"
                    + (candidate.isWinner ? ", winner" : "")
                )
            }
        }
    }

    /// Its own resolver. See `identityCard`.
    @ViewBuilder private var portsCard: some View {
        Card(title: "Open ports", caption: device.portsCaption ?? "no port scan yet") {
            if device.ports.isEmpty {
                VStack(spacing: Metrics.unit * 3) {
                    Text("No port scan yet")
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                    PrimaryButton("Scan ports")
                }
                .frame(maxWidth: .infinity)
                .padding(Metrics.contentInset)
            } else {
                CardRows(device.ports) { port in
                    HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 3) {
                        Text(port.port)
                            .font(.mono)
                            .foregroundStyle(Palette.textPrimary)
                            .measuredColumn(.portNumber)
                        Text(port.service)
                            .font(.control)
                            .foregroundStyle(Palette.textPrimary)
                            .measuredColumn(.portService)
                        Text(port.detail ?? "—")
                            .font(.rowSubtitle)
                            .foregroundStyle(Palette.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(Metrics.cardPadding)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .resolvesColumns()
    }

    @ViewBuilder private var eventsCard: some View {
        Card(title: "Recent events", caption: "what has changed about this device") {
            if device.events.isEmpty {
                Text("Nothing has changed since this device was first seen.")
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Metrics.cardPadding)
            } else {
                CardRows(device.events) { EventRow($0) }
            }
        }
    }
}

#Preview("Detail — dark") {
    DeviceDetailView(.jcMacBookPro)
        .frame(width: 954, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("Detail — light") {
    DeviceDetailView(.salaDeEntretenimiento)
        .frame(width: 954, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Detail — the acceptance case") {
    // An address, a hardware address, and nothing else. Every card empty or nearly so,
    // and the screen still has to read as an answer rather than as a failure.
    DeviceDetailView(.unidentified)
        .frame(width: 954, height: 760)
        .preferredColorScheme(.dark)
}
