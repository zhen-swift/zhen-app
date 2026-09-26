// Card.swift — the container used throughout device detail and settings.

import SwiftUI

/// A raised, bordered container with an optional title and caption.
///
/// The caption pattern is worth copying everywhere: "Known by · competing names by
/// source — highest-trust source wins" teaches a person what they are looking at
/// without a tooltip, a help button, or a manual.
public struct Card<Content: View>: View {
    private let title: String?
    private let caption: String?
    private let content: () -> Content

    /// Creates a card.
    ///
    /// - Parameters:
    ///   - title: the header title, or nil for a plain container.
    ///   - caption: the explanatory phrase beside the title.
    ///   - content: the body, laid out by the caller — the card adds no padding of its
    ///     own around it, because a card full of rows and a card full of prose want
    ///     different insets.
    public init(
        title: String? = nil,
        caption: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.caption = caption
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 2) {
                    Text(title)
                        .font(.rowTitle)
                        .foregroundStyle(Palette.textPrimary)
                    if let caption {
                        Text(caption)
                            .font(.rowSubtitle)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Metrics.cardPadding)
                Divider().overlay(Palette.separator)
            }
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius).fill(Palette.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .strokeBorder(Palette.separator, lineWidth: Metrics.hairline)
        )
    }
}

/// A hairline-separated list of rows inside a ``Card``.
///
/// Exists so no caller has to remember to leave the separator off the last row, which
/// is the single most common way a card ends up with a stray line above its bottom edge.
public struct CardRows<Item: Identifiable, Row: View>: View {
    private let items: [Item]
    private let row: (Item) -> Row

    /// Creates a separated list.
    public init(_ items: [Item], @ViewBuilder row: @escaping (Item) -> Row) {
        self.items = items
        self.row = row
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item)
                if index < items.count - 1 {
                    Divider().overlay(Palette.separator)
                }
            }
        }
    }
}

#Preview("Card — dark") {
    VStack(spacing: 16) {
        Card(title: "Known by", caption: "competing names by source — highest-trust source wins") {
            Text("Rows go here")
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
                .padding(Metrics.cardPadding)
        }
        Card {
            Text("A card with no header at all")
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
                .padding(Metrics.cardPadding)
        }
    }
    .padding()
    .frame(width: 620)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Card — light") {
    Card(title: "Identity history", caption: "1 MAC address — no identity changes seen") {
        Text("Rows go here")
            .font(.rowSubtitle)
            .foregroundStyle(Palette.textSecondary)
            .padding(Metrics.cardPadding)
    }
    .padding()
    .frame(width: 620)
    .background(Palette.surface)
    .preferredColorScheme(.light)
}
