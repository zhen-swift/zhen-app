// ColumnWidths.swift — columns that agree across rows, without anybody naming a number.
//
// ── What this replaces ─────────────────────────────────────────────────────────
//
// `Metrics.Column`: nine constants, each a width somebody measured once at one font
// size, in one language, against one set of fixtures. They produced defect F2, where the
// device table's fixed columns forced a minimum the split view paid for by squeezing the
// sidebar from 228 to 134pt, and they produced the `reassigned` chip wrapping an address
// mid-octet inside a 104pt column.
//
// ── Why not `Grid` ────────────────────────────────────────────────────────────
//
// `Grid` is the right tool and it cannot be used here. It sizes its columns to the
// widest cell AMONG ITS OWN ROWS, and this table's header is pinned while its rows
// scroll — A3's rule, reached after review, is that the header and anything describing
// the whole screen stay put and only the collection moves. Two grids, one per tree, are
// two tables that agree by luck.
//
// With the header as a pinned `Section` header both live in one scroll view again, which
// is what A3 asks for structurally — but a `Grid` still cannot wrap a `Section`, so the
// alignment mechanism has to be something both trees can share. This is that: every cell
// reports the width it would like, the widest per column wins, and both the header and
// the rows draw to the result.
//
// ── Why the measurement is a hidden copy ──────────────────────────────────────
//
// A cell cannot measure itself while being constrained by the answer — that is a loop:
// the width it reports depends on the width it was given. So each cell lays out a hidden
// copy of its content at its natural size, reports THAT, and draws the visible copy at
// whatever the column resolved to. The hidden copy is never constrained, so its
// measurement is stable and the second pass changes nothing.

import SwiftUI

/// Every measured column in the design system, named rather than numbered.
///
/// One enum for all four tables rather than one per table, because the resolver is
/// scoped to the subtree it is attached to: two tables each carrying their own
/// `resolvesColumns()` cannot see each other's measurements, so the cases only have to
/// be distinct within a table. They are distinct across all of them anyway, which makes
/// a misplaced case a compile-time rename rather than a silent misalignment.
///
/// **A table with two of these inside one resolver would fuse its columns.** The device
/// detail screen has two tables in one scroll view; each gets its own resolver.
public enum TableColumn: String, Sendable, Hashable, CaseIterable {
    // The device table. `statusGutter` is the slot the presence dot sits in: it has to
    // be the same width in the header, which has nothing in it, as in the rows, which
    // have a dot — so it is a column rather than a constant written out twice.
    case statusGutter, identity, ip, mac, lastSeen
    /// The sidebar's icon slot, so every room label starts at the same x.
    case sidebarIcon
    // Device detail: the identity sources table.
    case detailMAC, detailSource
    // Device detail: the ports table.
    case portNumber, portService
    // Activity.
    case eventTime, eventKind
    // The live scan's found-so-far list.
    case findingIP, findingMAC, findingNote
}

/// The widest natural width seen for each column, gathered from every cell.
struct ColumnWidthKey: PreferenceKey {
    static let defaultValue: [TableColumn: CGFloat] = [:]

    static func reduce(
        value: inout [TableColumn: CGFloat],
        nextValue: () -> [TableColumn: CGFloat]
    ) {
        for (column, width) in nextValue() {
            value[column] = max(value[column] ?? 0, width)
        }
    }
}

private struct ResolvedColumnWidthsKey: EnvironmentKey {
    static let defaultValue: [TableColumn: CGFloat] = [:]
}

extension EnvironmentValues {
    /// The resolved width of each column, published by the table to its rows.
    ///
    /// Empty until the first measurement pass completes, and a cell with no resolved
    /// width draws at its natural size — so the table is correct on the first frame and
    /// merely unaligned, rather than collapsed.
    var zhenColumnWidths: [TableColumn: CGFloat] {
        get { self[ResolvedColumnWidthsKey.self] }
        set { self[ResolvedColumnWidthsKey.self] = newValue }
    }
}

extension View {
    /// Marks this view as a cell of `column`: measures it, and draws it at the width the
    /// column resolved to.
    public func measuredColumn(
        _ column: TableColumn, alignment: Alignment = .leading
    ) -> some View {
        modifier(ColumnCell(column: column, alignment: alignment))
    }

    /// Collects the measurements from every cell inside and publishes the result.
    ///
    /// Put this on the table, around both the pinned header and the rows.
    public func resolvesColumns() -> some View {
        modifier(ColumnResolver())
    }
}

private struct ColumnCell: ViewModifier {
    let column: TableColumn
    let alignment: Alignment
    @Environment(\.zhenColumnWidths) private var widths

    func body(content: Content) -> some View {
        content
            .frame(width: widths[column], alignment: alignment)
            .background(
                // The hidden copy, at its natural size. `fixedSize` is what makes it
                // natural: without it the copy inherits the constraint being measured
                // and reports the answer back to itself.
                content
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ColumnWidthKey.self,
                                value: [column: proxy.size.width]
                            )
                        }
                    )
            )
    }
}

private struct ColumnResolver: ViewModifier {
    @State private var widths: [TableColumn: CGFloat] = [:]

    func body(content: Content) -> some View {
        content
            .environment(\.zhenColumnWidths, widths)
            .onPreferenceChange(ColumnWidthKey.self) { measured in
                // Only ever grows within a layout pass, and is replaced wholesale when
                // the set of rows changes. Taking the max without ever resetting would
                // leave the table permanently as wide as the longest row it has ever
                // shown, including one that has since gone offline and been filtered
                // out.
                if measured != widths { widths = measured }
            }
    }
}
