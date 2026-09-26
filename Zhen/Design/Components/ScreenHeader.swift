// ScreenHeader.swift — the block every screen starts with, in one place.
//
// Four screens had four copies of the same twelve lines: a title, a subtitle under it,
// a spacer, and whatever controls that screen needs on the trailing edge. The copies
// agreed on the horizontal inset and disagreed about the vertical one, so switching
// rooms moved the title.
//
//     Devices, Activity      20 above, 12 below
//     Settings, Live Scan    16 above, 16 below
//
// The block was the same height either way, which is why it survived review: nothing
// jumped except the words inside it, by four points, only while changing rooms — the one
// moment a person is looking at the sidebar rather than the title.
//
// A1 gives `headerBlockHeight` as 87 and `contentInset` as 20 *horizontal*, and says
// nothing about the vertical padding. So there was no answer to look up, four people
// picked, and two of them picked differently. `headerBlockHeight` was declared in
// `Metrics` and referenced by nothing at all, which is the same failure one step earlier.
//
// The fix is not a third number. It is that screens no longer own this: they describe
// what goes in the header and the header decides how it sits. A screen cannot disagree
// with another screen about padding it does not write.

import SwiftUI

/// The title block at the top of a screen.
///
/// Everything a screen puts on the trailing edge — a search field, filter chips, a Stop
/// button — is `trailing`. The title, the subtitle and every inset belong to this type.
public struct ScreenHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String
    private let trailing: Trailing

    /// Creates a header with trailing controls.
    public init(
        _ title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Metrics.unit * 4) {
            VStack(alignment: .leading, spacing: Metrics.unit / 2) {
                Text(title)
                    .font(.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.screenSubtitle)
                    // Counts change between scans; monospaced digits keep the line from
                    // reflowing under them. Harmless where a subtitle has no digits.
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: Metrics.unit * 4)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.contentInset)
        .padding(.top, Metrics.headerTopInset)
        .padding(.bottom, Metrics.headerBottomInset)
    }
}

public extension ScreenHeader where Trailing == EmptyView {
    /// A header with nothing on the trailing edge.
    ///
    /// Its own initializer rather than a defaulted closure, so Settings does not have to
    /// write `trailing: { EmptyView() }` to say it has no controls.
    init(_ title: String, subtitle: String) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}
