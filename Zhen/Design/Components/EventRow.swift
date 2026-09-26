// EventRow.swift — one line of the activity log.

import SwiftUI

/// Time, kind, and a sentence with the device name at full strength.
///
/// Mixing weights inside one description is what makes the list scannable — the device
/// name is what the eye hunts for, and a uniformly grey sentence gives it nothing to
/// land on.
public struct EventRow: View {
    private let event: EventModel

    /// Creates a row.
    public init(_ event: EventModel) { self.event = event }

    private var subjectText: Text {
        Text(event.subject).font(.rowTitle).foregroundStyle(Palette.textPrimary)
    }

    private var detailText: Text {
        Text(event.detail).font(.rowSubtitle).foregroundStyle(Palette.textSecondary)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 3) {
            Text(event.time)
                .font(.mono)
                .foregroundStyle(Palette.textSecondary)
                .measuredColumn(.eventTime)

            HStack(spacing: Metrics.unit + 2) {
                Circle()
                    .fill(EventPalette.mark(event.kind))
                    // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
                    // something — so it carries a size and scales with the type scale rather than
                    // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
                    // size that stay.
                    .frame(width: Metrics.dotSize, height: Metrics.dotSize)
                    .accessibilityHidden(true)
                Text(event.kind.label)
                    .font(.columnHeader)
                    .textCase(.uppercase)
                    .tracking(Tracking.label)
                    // The text variant, not the mark variant. The vivid dot colour is
                    // 1.96:1 on white and unreadable as a word.
                    .foregroundStyle(EventPalette.label(event.kind))
            }
            .measuredColumn(.eventKind)

            // Interpolated rather than concatenated: `Text + Text` is deprecated from
            // macOS 26, and interpolation keeps the same property that matters — one
            // text run that wraps as a sentence, with two different styles inside it.
            Text("\(subjectText) \(detailText)")
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.contentInset)
        .padding(.vertical, Metrics.unit * 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.accessibilityDescription)
    }
}

/// Which colour an event kind gets, split by whether it marks or spells.
///
/// The split exists because the same semantic colour cannot do both jobs on a light
/// background: the vivid green that reads perfectly as an 8pt dot is 1.96:1 as a word.
/// See ``Palette/Status`` and <doc:Corrections>.
public enum EventPalette {
    /// The dot beside the kind.
    public static func mark(_ kind: EventKind) -> PaletteColor {
        switch kind {
        case .appeared: Palette.Status.online
        case .disappeared: Palette.textSecondary
        case .ipChanged: Palette.Status.info
        case .merged, .renamed: Palette.accent
        case .portOpened, .portClosed: Palette.Status.warning
        }
    }

    /// The kind label, which is text and therefore has to pass 4.5:1.
    public static func label(_ kind: EventKind) -> PaletteColor {
        switch kind {
        case .appeared: Palette.Status.onlineText
        case .disappeared: Palette.textSecondary
        case .ipChanged: Palette.Status.infoText
        case .merged, .renamed: Palette.accent
        case .portOpened, .portClosed: Palette.Status.warningText
        }
    }
}

#Preview("EventRow — dark") {
    VStack(spacing: 0) {
        ForEach(EventDayModel.today.events) { EventRow($0) }
        ForEach(EventDayModel.yesterday.events) { EventRow($0) }
    }
    .frame(width: 1000)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("EventRow — light") {
    VStack(spacing: 0) {
        ForEach(EventDayModel.today.events) { EventRow($0) }
        ForEach(EventDayModel.yesterday.events) { EventRow($0) }
    }
    .frame(width: 1000)
    .background(Palette.surface)
    .preferredColorScheme(.light)
}

#Preview("EventRow — large type") {
    VStack(spacing: 0) {
        ForEach(EventDayModel.today.events.prefix(3)) { EventRow($0) }
    }
    .frame(width: 1000)
    .background(Palette.surface)
    .environment(\.dynamicTypeSize, .accessibility2)
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

#Preview("EventRow — narrow") {
    VStack(spacing: 0) {
        ForEach(EventDayModel.today.events) { EventRow($0) }
    }
    .resolvesColumns()
    .frame(width: 620)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}
