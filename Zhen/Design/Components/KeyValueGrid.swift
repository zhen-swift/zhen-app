// KeyValueGrid.swift — the two-column label/value block.

import SwiftUI

/// Labels and values in two aligned columns.
///
/// A `Grid` rather than stacked `HStack`s so values line up across rows — with an
/// `HStack` per row the value column wanders with the label length, and a block of
/// facts that does not align reads as unconsidered.
public struct KeyValueGrid: View {
    private let pairs: [KeyValuePair]
    private let alignment: HorizontalAlignment

    /// Creates a grid.
    ///
    /// - Parameters:
    ///   - pairs: the label/value pairs, in display order.
    ///   - alignment: leading in cards, trailing in the detail header block.
    public init(_ pairs: [KeyValuePair], alignment: HorizontalAlignment = .leading) {
        self.pairs = pairs
        self.alignment = alignment
    }

    public var body: some View {
        Grid(alignment: alignment == .leading ? .leading : .trailing,
             horizontalSpacing: Metrics.unit * 6,
             verticalSpacing: Metrics.unit * 3) {
            ForEach(pairs) { pair in
                GridRow {
                    Text(pair.label)
                        .font(.columnHeader)
                        .textCase(.uppercase)
                        .tracking(Tracking.label)
                        .foregroundStyle(Palette.textTertiary)
                        .gridColumnAlignment(alignment == .leading ? .leading : .trailing)
                    // A missing value is an em dash, never an empty cell. An empty cell
                    // looks like a bug; a dash looks like an answer.
                    Text(pair.value ?? "—")
                        .font(pair.isAddress ? .mono : .rowTitle)
                        .foregroundStyle(pair.value == nil ? Palette.textSecondary : Palette.textPrimary)
                        .gridColumnAlignment(alignment == .leading ? .leading : .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(pair.label): \(pair.value ?? "not known")")
            }
        }
    }
}

#Preview("KeyValueGrid — dark") {
    KeyValueGrid([
        KeyValuePair("IP address", "10.10.20.8", isAddress: true),
        KeyValuePair("Current MAC", "52:A1:8A:E0:7A:8A", isAddress: true),
        KeyValuePair("Vendor", nil),
        KeyValuePair("First seen", "Sep 3, 2026"),
    ])
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("KeyValueGrid — light, large type") {
    KeyValueGrid([
        KeyValuePair("IP address", "10.10.20.12", isAddress: true),
        KeyValuePair("Vendor", nil),
        KeyValuePair("Model", nil),
    ])
    .padding()
    .background(Palette.surface)
    .environment(\.dynamicTypeSize, .accessibility2)
    .preferredColorScheme(.light)
}
