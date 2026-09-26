// EmptyStateView.swift — every list needs one, and the artboards do not show any.
//
// Same skeleton each time: a symbol, a title, one line of explanation, and an action
// when there is something useful to do.
//
// The "nothing answered" case is doing real work. An empty device list with no
// explanation is the single most likely way a new user concludes the app is broken,
// when in fact the OS withheld a permission nobody told them about.

import SwiftUI

/// A centred symbol, title, explanation and optional action.
public struct EmptyStateView: View {
    private let symbol: String
    private let title: String
    private let explanation: String
    private let actionTitle: String?
    private let action: () -> Void

    /// Creates an empty state.
    public init(
        symbol: String,
        title: String,
        explanation: String,
        actionTitle: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.symbol = symbol
        self.title = title
        self.explanation = explanation
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Metrics.unit * 3) {
            Image(systemName: symbol)
                .imageScale(.large)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
            Text(explanation)
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                // A MEASURE limit, not a box: prose is unreadable past about 70 characters
            // a line whatever the window does. The same limit the settings and
            // detail copy use, rather than a second number for the same rule.
            .frame(maxWidth: Metrics.Detail.proseMaxWidth)
            if let actionTitle {
                PrimaryButton(actionTitle, action: action).padding(.top, Metrics.unit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Metrics.contentInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(explanation)")
    }
}

public extension EmptyStateView {
    /// Devices, before the first scan.
    static var neverScanned: EmptyStateView {
        EmptyStateView(
            symbol: Symbols.noScan,
            title: "No scan yet",
            explanation: "Run a scan to see what\u{2019}s on your network.",
            actionTitle: "Scan Now"
        )
    }

    /// Devices, when a scan completed and found nothing.
    ///
    /// The most important empty state in the app: this is the one that stops a denied
    /// permission from reading as a broken application.
    static var nothingAnswered: EmptyStateView {
        EmptyStateView(
            symbol: Symbols.warning,
            title: "Nothing answered",
            explanation: "The scan completed but no devices replied. This usually means the "
                + "Local Network permission is denied.",
            actionTitle: "Open System Settings…"
        )
    }

    /// Devices, when a search matches nothing.
    static func noMatches(for term: String) -> EmptyStateView {
        EmptyStateView(
            symbol: Symbols.noMatches,
            title: "No matches",
            explanation: "No device matches \u{201C}\(term)\u{201D}."
        )
    }

    /// Activity, with no events at all.
    static var nothingHasChanged: EmptyStateView {
        EmptyStateView(
            symbol: Symbols.noEvents,
            title: "Nothing has changed",
            explanation: "Events appear here when devices join, leave, or change."
        )
    }

    /// Activity, with a filter that matches nothing.
    static func noEventsOfKind(_ kind: String) -> EmptyStateView {
        EmptyStateView(
            symbol: Symbols.noEvents,
            title: "No matches",
            explanation: "No \(kind.lowercased()) events in this window."
        )
    }
}

#Preview("Empty states — dark") {
    HStack(spacing: 0) {
        EmptyStateView.neverScanned
        Divider().overlay(Palette.separator)
        EmptyStateView.nothingAnswered
    }
    .frame(width: 900, height: 300)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Empty states — light") {
    HStack(spacing: 0) {
        EmptyStateView.noMatches(for: "sala")
        Divider().overlay(Palette.separator)
        EmptyStateView.nothingHasChanged
    }
    .frame(width: 900, height: 300)
    .background(Palette.surface)
    .preferredColorScheme(.light)
}
