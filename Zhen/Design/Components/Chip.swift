// Chip.swift — the small uppercase pill.

import SwiftUI

/// A small uppercase pill: `GATEWAY`, `private`, `WINNER`.
public struct Chip: View {
    /// How much attention the chip should draw.
    public enum Style {
        /// A qualifier on something else — `private` next to a MAC.
        case neutral
        /// A finding worth the eye — `GATEWAY`, `WINNER`.
        case accent
    }

    private let text: String
    private let style: Style

    /// Creates a chip.
    ///
    /// - Parameters:
    ///   - text: the label, in its natural case. Case is applied at render time so the
    ///     underlying value stays intact for VoiceOver — a chip that reads
    ///     "G-A-T-E-W-A-Y" is a real bug.
    ///   - style: neutral or accent. **Style decides case**, which is not arbitrary:
    ///     A2's sample code uppercases every chip, and the artboards do not — `GATEWAY`
    ///     and `WINNER` shout, `private` does not. That difference is doing work. An
    ///     accent chip is a FINDING about the device and wants the eye; a neutral chip
    ///     is a QUALIFIER on the value beside it, and a second shouting label next to a
    ///     MAC address competes with the address for attention when its whole job is to
    ///     annotate it.
    public init(_ text: String, style: Style = .neutral) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(.badge)
            .textCase(style == .accent ? .uppercase : nil)
            .tracking(Tracking.badge)
            .foregroundStyle(style == .accent ? Palette.accent : Palette.textSecondary)
            .padding(.horizontal, Metrics.unit + 2)
            .padding(.vertical, Metrics.unit / 2)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius)
                    .fill(style == .accent ? Palette.accent.opacity(0.2) : Palette.surfaceField)
            )
            .fixedSize()
    }
}

// The `private` chip is doing real work: it tells a person this hardware address is
// randomised and therefore not a stable identity. Keep it beside the address it
// qualifies — in its own column it becomes a mystery.

#Preview("Chip — dark") {
    HStack(spacing: 8) {
        Chip("gateway", style: .accent)
        Chip("winner", style: .accent)
        Chip("private")
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Chip — light") {
    HStack(spacing: 8) {
        Chip("gateway", style: .accent)
        Chip("winner", style: .accent)
        Chip("private")
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.light)
}
