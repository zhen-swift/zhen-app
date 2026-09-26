// Metrics.swift — every dimension, measured from the artboards at 1182pt window width.
//
// Every spacing value is a multiple of `unit`. If a layout needs 13, it needs 12 or 16;
// the in-between value is how a design starts looking hand-placed.

import SwiftUI

/// Sizes, insets and radii. No view writes a bare number.
public enum Metrics {
    /// The grid. Every gap in the system is a multiple of this.
    public static let unit: CGFloat = 4

    /// The sidebar column.
    public static let sidebarWidth: CGFloat = 228
    /// The selection pill's inset from the sidebar's edges.
    ///
    /// A3 states this one: "a `selection` fill with 6pt radius, inset 8pt from both
    /// edges."
    public static let sidebarPillInset: CGFloat = unit * 2
    /// Where a row's symbol and title start inside that pill.
    public static let sidebarPillTextInset: CGFloat = unit * 3
    /// Where text starts in the sidebar, pill or no pill.
    ///
    /// Composed rather than written as 20, because it is not an independent value: it
    /// is where a room name lands, and anything else in the sidebar has to agree with
    /// the rows or the column has a ragged left edge. The section label and the scan
    /// footer were each given 16 — four points left of the rows, which is exactly the
    /// distance at which a person can see that something is off without being able to
    /// say what.
    public static let sidebarTextInset: CGFloat = sidebarPillInset + sidebarPillTextInset
    /// Above the screen title.
    ///
    /// A1 gives `contentInset` as horizontal only, so the vertical values had no stated
    /// answer and four screens invented two. These are the Devices screen's, because
    /// Devices is the one A1 measured `headerBlockHeight` from.
    public static let headerTopInset: CGFloat = contentInset
    /// Below the screen title, before a divider or the first row.
    public static let headerBottomInset: CGFloat = unit * 3

    /// Horizontal inset for screen content.
    public static let contentInset: CGFloat = 20
    /// Horizontal inset inside a table row.
    public static let rowInset: CGFloat = 16
    /// Padding inside a card.
    public static let cardPadding: CGFloat = 16

    /// Card corner radius.
    public static let cardRadius: CGFloat = 10
    /// Text field and button corner radius.
    public static let fieldRadius: CGFloat = 6
    /// Chip corner radius.
    public static let chipRadius: CGFloat = 5
    /// The radius of a selected row's fill.
    public static let selectionRadius: CGFloat = 6

    /// The status dot.
    public static let dotSize: CGFloat = 8
    /// The offline dot's ring.
    public static let dotRingWidth: CGFloat = 1.5
    /// A hairline, in points. Not `1 / scale` — a hairline that disappears on a Retina
    /// display is a hairline nobody can see.
    public static let hairline: CGFloat = 1

    /// The focus ring's stroke. A stroke weight, which `RESPONSIVE-plan.md` keeps as
    /// rhythm rather than removing as a box.
    ///
    /// Two points and not one: this ring is the only thing telling a keyboard user
    /// where they are, and a hairline halo on a dark surface is a thing you hunt for.
    public static let focusRingWidth: CGFloat = 2
    /// The gap between a control and its ring.
    ///
    /// The ring sits outside the control, and the gap is what makes it readable on
    /// `PrimaryButton`, which is filled with the same accent the ring is drawn in.
    public static let focusRingGap: CGFloat = 2
    /// The height of a stage card's progress track.
    public static let progressTrackHeight: CGFloat = 3
    /// The device-kind symbol tile in the detail header.
    /// **A survivor, and the reason is at the call site too.** The detail screen's
    /// device tile is a glyph: a rounded square holding an icon, with no content whose
    /// width it could take. `RESPONSIVE-plan.md` names this category — a status dot, a
    /// histogram bar, a progress track — as the one kind of size that stays.
    public static let deviceTileSize: CGFloat = 44


    /// The narrowest the window may be.
    ///
    /// **Rendered, not summed, and not asked of `fittingSize` either.** Three earlier
    /// answers to this question were all wrong in different directions: summing tokens
    /// gave 908pt and was 8pt short; `NSHostingView.fittingSize` on the assembled
    /// window gave 916pt and then, after stage 2 replaced the fixed columns with
    /// measured ones, 398pt — because the table is inside a `ScrollView`, and a scroll
    /// view accepts any width and reports no minimum for what it holds. 398 is the
    /// width of the header block. The table under it needs 650.
    ///
    /// The number here comes from rendering the window and finding the width at which
    /// the device row stops fitting its pane and starts centring itself back under the
    /// sidebar. Measured in stage 4: **974pt is the threshold**, 972 is already
    /// marginal, 970 clips. Declared four points above it.
    ///
    /// Four, and not a hundred. The old value was 1000 with headroom nobody had
    /// measured, which is how a minimum stops meaning anything. `WindowLayoutTests`
    /// now fails in BOTH directions — if a room stops fitting here, and if the table
    /// still fits 24pt below here — so the number cannot drift away from the threshold
    /// in either direction without a test saying so.
    ///
    /// **This is 22pt of progress, and that is the honest size of it.** The first
    /// rendered threshold was 886, and it was 886 because the name column had no floor
    /// and collapsed until words broke across lines mid-word. ``Detail/nameMinMeasure``
    /// gave it one, and the cost is 88 of those 114 points. Five columns plus a name
    /// column that can hold one word IS a 974pt table. What buys real width is dropping
    /// columns at narrow widths, which is stage 8's job, not a number here.
    ///
    /// Declaring it at all is the third part of the sidebar fix: the sidebar cannot
    /// flex and the columns cannot compress further, so something has to refuse, and
    /// the window is the right thing to refuse.
    public static let windowMinWidth: CGFloat = 978

    /// Widths inside the device detail's cards. Named rather than inlined so the three
    /// cards' first columns line up with each other by construction.
    public enum Detail {
        /// The content column. Cards wider than this stop being readable as a block.
        public static let contentMaxWidth: CGFloat = 900
        /// A paragraph of explanatory prose — the helper panel's copy.
        public static let proseMaxWidth: CGFloat = 520
        /// The widest a device's name and subtitle are allowed to run.
        ///
        /// **A MEASURE limit, not a column width.** The name column takes whatever is
        /// left after the measured columns, which on a wide display meant a subtitle
        /// running most of the window — "Randomized MAC · no vendor · in ARP table, no
        /// ping reply" as one line a thousand points long, with the data columns pushed
        /// so far right that the eye cannot connect a row's name to its address.
        ///
        /// Shorter than `proseMaxWidth` because this is a label and a caption rather
        /// than a paragraph: it is read in a glance across a row, not down a column of
        /// text.
        public static let nameMeasure: CGFloat = 420
        /// The narrowest the same column may get before it stops setting type.
        ///
        /// **The other end of the same measure limit**, and the more load-bearing one.
        /// Without it the name column has no floor at all: stage 2 deleted
        /// `Column.nameMin = 200` along with the fixed column widths, and at the
        /// window's minimum the column collapsed until "Unidentified" broke across two
        /// lines mid-word and the gateway row's name was squeezed to two bare strokes
        /// beside its chip. Nothing clipped. It was simply unreadable, which no
        /// overflow check can see.
        ///
        /// Measured rather than chosen: the widest single word this column must set is
        /// "entretenimiento" at 112pt, and the binding case is a name beside the
        /// gateway chip — "Unidentified" plus a 66pt chip and its gap is 158pt. Rounded
        /// up to the grid.
        ///
        /// Stage 2 was right to delete the old constant and wrong about what it was.
        /// `nameMin = 200` was not a column width; it was this, measured against a
        /// longer word at a larger inset.
        public static let nameMinMeasure: CGFloat = unit * 40
    }



    /// The timeline histogram.
    public enum Histogram {
        /// The tallest a bar can be.
        public static let height: CGFloat = 56
        /// A bar's corner radius.
        public static let barRadius: CGFloat = 2
        /// The floor, so an empty hour is a visible gap rather than a hole.
        public static let minimumBarHeight: CGFloat = 2
    }


    /// The confidence meter's bars: three of them, ascending.
    public enum Meter {
        /// Bar width.
        public static let barWidth: CGFloat = 3
        /// Gap between bars.
        public static let barGap: CGFloat = 2
        /// Gap between the bars and the word.
        public static let labelGap: CGFloat = 6
        /// A bar's corner radius.
        public static let barRadius: CGFloat = 1
        /// Height of bar `index` (1...3): 6, 9, 12.
        public static func barHeight(_ index: Int) -> CGFloat { CGFloat(3 + index * 3) }
    }
}
