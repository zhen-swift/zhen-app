import AppKit
import SwiftUI
import Testing
@testable import Zhen
// The layout gate, against the two things macOS actually varies.
//
// ── Why this is not a Dynamic Type gate ────────────────────────────────────────
//
// The plan asks for snapshots at `.large` and `.accessibility3`. That gate was written,
// it passed on every screen, and it was measuring nothing: both type sizes produced the
// identical number, because macOS does not consume `dynamicTypeSize`. A view holding
// `@ScaledMetric(relativeTo: .body) var x = 100` reports 100.0 at both, and a `Text` in
// `.body` measures the same width at both. The value can be set; nothing reads it.
//
// `typeSizeIsInertOnThisPlatform` below pins that, so the day it stops being true is a
// failing test rather than a silent one, and the type-size gate can come back.
//
// What is left is what a Mac really varies: the width of the window, and the length of
// the strings a real network puts in it.

@Suite("Every screen lays out at the widths and contents it will meet")
@MainActor
struct LayoutGateTests {
    /// The smallest width a view lays out in without violating its own minimums.
    ///
    /// `fittingSize` is the layout system's own answer, and it accounts for the split
    /// view's divider, for `fixedSize` children and for the intrinsic width of wrapped
    /// text — none of which a token knows about.
    private func fittingWidth(_ view: some View, at size: DynamicTypeSize = .large) -> CGFloat {
        let host = NSHostingView(
            rootView: AnyView(
                view.environment(\.colorScheme, .dark).environment(\.dynamicTypeSize, size)
            )
        )
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(x: 0, y: 0, width: 100, height: 620)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.width
    }

    // ── Three width gates used to live here, and all three were blind ────────────
    //
    // `screenFitsTheWindow`, `theGateCanFail` and `realWorstCaseFits` each asked
    // `fittingSize` for the width a room needed and compared it to the window minimum.
    // All three passed. All three were measuring the header block: the table is inside
    // a `ScrollView`, which accepts any width and reports no minimum on behalf of what
    // it holds, so Devices answered 398pt for a room that needs 886.
    //
    // `theGateCanFail` is the sharpest loss. It was written specifically to establish
    // what the check could and could not see, it concluded "it CANNOT see truncation
    // but it CAN see a violated fixed minimum", and both halves were true — of a
    // minimum declared OUTSIDE the scroll view, which is the only kind it was ever
    // shown. A sensitivity check that only ever probes the case the check handles is
    // not a sensitivity check.
    //
    // Their replacement renders the window and looks at where the content landed. See
    // `WindowLayoutTests`, which also keeps the property these had: two widths, one
    // detector, opposite answers.

    @Test("Dynamic Type is inert on macOS, which is why there is no type-size gate")
    func typeSizeIsInertOnThisPlatform() {
        // Documentation with a failure mode. If macOS ever consumes `dynamicTypeSize`,
        // this test breaks, and the type-size gate the plan asked for becomes possible
        // and should be restored. Until then it records why the gate is missing rather
        // than leaving its absence to be rediscovered.
        for room in Room.allCases {
            let large = fittingWidth(FixtureWindow(room: room), at: .large)
            let a11y = fittingWidth(FixtureWindow(room: room), at: .accessibility3)
            #expect(a11y == large,
                    Comment(rawValue: "\(room.title) measured \(large)pt at .large and "
                            + "\(a11y)pt at .accessibility3 — macOS now scales type, so "
                            + "the type-size gate in RESPONSIVE-plan.md can be restored"))
        }
    }
}

// Defect F2, as a test rather than as a memory.
//
// The device table's fixed columns forced a minimum wider than the window could give,
// and the split view paid for it out of the only flexible thing it had: the sidebar,
// which collapsed from its declared 228pt to 134. The table did not look broken. The
// sidebar did, and the cause was three panes away.
//
// Stage 2 removed the columns, so the table no longer asserts a width to be paid for.
//
// **This suite pins the property and cannot prove stage 2 earned it.** F2 was already
// fixed locally, by giving the sidebar equal min, ideal and max in `ZhenWindow` — it is
// rigid, so nothing the table does can squeeze it. Reintroducing a 520pt fixed column
// deliberately does not make these tests fail, which is the honest state of them: they
// defend against the split configuration losing its pinning, not against the table
// regaining a minimum.
//
// What stage 2 actually removed is measurable, and stage 4 had to remeasure it. The
// figure written here was 624pt, from `fittingSize`, and it was not a width the table
// needs — it was the width of everything OUTSIDE the scroll view. Rendered instead, the
// Devices screen stops fitting its pane at an 886pt window, against 956 before stage 2.
// Real, and 70pt rather than 332.
@Suite("The sidebar keeps its width whatever the table holds")
@MainActor
struct SidebarWidthTests {
    /// The width of the split view's first pane.
    ///
    /// Found by POSITION, not by width. The first version of this searched the
    /// hierarchy for a view whose width was already `Metrics.sidebarWidth` and then
    /// asserted that the width was `Metrics.sidebarWidth` — a test that asserts its own
    /// search criterion and can only fail by finding nothing at all. It passed while a
    /// 520pt fixed column was deliberately squeezing the sidebar.
    private func sidebarWidth(devices: [DeviceRowModel]) -> CGFloat {
        let host = NSHostingView(
            rootView: AnyView(
                FixtureWindow(devices: devices).environment(\.colorScheme, .dark)
            )
        )
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(x: 0, y: 0, width: Metrics.windowMinWidth, height: 700)
        host.layoutSubtreeIfNeeded()

        func split(_ view: NSView) -> NSSplitView? {
            if let found = view as? NSSplitView { return found }
            for sub in view.subviews {
                if let found = split(sub) { return found }
            }
            return nil
        }
        guard let split = split(host) else { return -1 }
        // Leftmost arranged pane, by frame origin rather than by array order, so a
        // right-to-left layout or a reordered split does not silently measure the
        // detail column instead.
        let panes = split.arrangedSubviews.sorted { $0.frame.minX < $1.frame.minX }
        return panes.first?.frame.width ?? -1
    }

    @Test("A hostname long enough to have squeezed it does not")
    func longHostnameDoesNotSqueezeTheSidebar() {
        // The row that would have done it: a name and a subtitle far longer than the
        // name column was ever sized for, beside the longest MAC and a chip.
        let long = DeviceRowModel(
            id: "long",
            name: "a-very-long-hostname-that-somebody-actually-named-their-nas.local",
            subtitle: "Synology DiskStation DS1821+ · Synology Incorporated · responds to ping",
            presence: .online, identification: .identified,
            ip: "10.10.20.119", mac: "A2:6A:35:C9:0A:BD",
            isPrivateMAC: true, lastSeen: "now"
        )
        let width = sidebarWidth(devices: [long])
        // At least its declared width, not exactly it: the split view's pane carries
        // the divider, so it measures 236 for a 228pt sidebar. What F2 did was take
        // width AWAY — 228 down to 134 — so the floor is the property worth defending
        // and the exact number is the split view's business.
        #expect(
            width >= Metrics.sidebarWidth,
            Comment(rawValue: "the sidebar pane measured \(width)pt against a declared "
                    + "\(Metrics.sidebarWidth)pt — the table squeezed it, which is "
                    + "defect F2 returning")
        )
    }

    @Test("And the ordinary network does not either, so the check is not vacuous")
    func normalNetworkKeepsIt() {
        let width = sidebarWidth(devices: DeviceRowModel.sampleNetwork)
        #expect(width >= Metrics.sidebarWidth,
                Comment(rawValue: "the sidebar pane measured \(width)pt with the ordinary "
                        + "fixtures — something other than hostname length is squeezing it"))
    }
}
