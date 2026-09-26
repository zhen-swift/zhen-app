// StatusDot.swift — the smallest thing in the app and the one people read first.

import SwiftUI

/// An 8pt presence dot.
///
/// **Shape carries the meaning so colour does not have to.** Online is a filled circle,
/// offline is a hollow ring. That difference is the accessible signal and the colour is
/// a bonus — which is what lets this pass A1's "no state is colour-only" rule
/// without a text label beside every dot.
public struct StatusDot: View {
    private let presence: Presence

    /// Creates a dot for a presence.
    public init(_ presence: Presence) { self.presence = presence }

    public var body: some View {
        Group {
            switch presence {
            case .online:
                Circle().fill(Palette.Status.online)
            case .offline:
                Circle().strokeBorder(Palette.offlineRing, lineWidth: Metrics.dotRingWidth)
            case .scanning:
                Circle().fill(Palette.accent)
            }
        }
        // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
        // something — so it carries a size and scales with the type scale rather than
        // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
        // size that stay.
        .frame(width: Metrics.dotSize, height: Metrics.dotSize)
        // Hidden, not labelled. Every place this appears, the containing row already
        // says "online" or "offline" in its combined label — a labelled dot would make
        // VoiceOver stutter the state twice.
        .accessibilityHidden(true)
    }
}

// Deliberately not animated. A pulsing scanning state sounds appealing until there are
// nine of them on screen at once and the window looks like a Christmas tree.

#Preview("StatusDot — dark") {
    HStack(spacing: 16) {
        StatusDot(.online)
        StatusDot(.offline)
        StatusDot(.scanning)
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("StatusDot — light") {
    HStack(spacing: 16) {
        StatusDot(.online)
        StatusDot(.offline)
        StatusDot(.scanning)
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.light)
}
