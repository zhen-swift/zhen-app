// ConfidenceMeter.swift — the one piece of iconography that is not an SF Symbol.
//
// Three ascending bars whose fill count is the information. That is data, not
// decoration, which is why it is a real view rather than a named glyph: a symbol would
// need three variants and could not be interpolated, and the bar count is the whole
// point.

import SwiftUI

/// Three ascending bars and a word, showing how well we know what a device is.
///
/// **Bound to ``Identification`` and never to identity-key stability.** See that type
/// for why the two are different questions. The view takes a level from its caller
/// either way, so neither definition leaks into it.
public struct ConfidenceMeter: View {
    private let level: Identification

    /// Creates a meter for a level.
    public init(_ level: Identification) { self.level = level }

    public var body: some View {
        HStack(spacing: Metrics.Meter.labelGap) {
            HStack(alignment: .bottom, spacing: Metrics.Meter.barGap) {
                ForEach(1...3, id: \.self) { bar in
                    RoundedRectangle(cornerRadius: Metrics.Meter.barRadius)
                        .fill(bar <= level.rawValue ? Palette.accent : Palette.separator)
                        // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
                        // something — so it carries a size and scales with the type scale rather than
                        // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
                        // size that stay.
                        .frame(width: Metrics.Meter.barWidth, height: Metrics.Meter.barHeight(bar))
                }
            }
            // The word is not optional. Bars alone would be a colour-and-count signal
            // with no text equivalent, which fails A1's accessibility floor — and "two
            // bars" means nothing to someone who has not learned the scale.
            Text(level.label)
                .font(.rowSubtitle)
                .foregroundStyle(level == .identified ? Palette.textPrimary : Palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Identity confidence: \(level.label)")
    }
}

#Preview("ConfidenceMeter — dark") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(Identification.allCases.reversed(), id: \.self) { ConfidenceMeter($0) }
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("ConfidenceMeter — light") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(Identification.allCases.reversed(), id: \.self) { ConfidenceMeter($0) }
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.light)
}

#Preview("ConfidenceMeter — large type") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(Identification.allCases.reversed(), id: \.self) { ConfidenceMeter($0) }
    }
    .padding()
    .background(Palette.surface)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
