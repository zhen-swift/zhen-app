import AppKit
import SwiftUI
import Testing
@testable import Zhen
// The window's minimum width, measured by rendering it.
//
// ── Why this suite was rewritten in stage 4 ────────────────────────────────────
//
// It used to ask `NSHostingView.fittingSize` for the width the window needed, and it
// had a good reason: the first `windowMinWidth` was a sum of token values, it was 8pt
// short, and nothing caught it.
//
// **`fittingSize` cannot see the table.** The device list lives in a `ScrollView`, and a
// scroll view will accept any width at all, so it reports no minimum on behalf of what
// it holds. Measured during stage 4: the Devices room answers 398pt, the width of its
// header block — title, search field, Scan Now — while the table beneath it needs 650
// and visibly runs out from under the sidebar at anything less. Three suites asked that
// question and got that answer. It is the fifth time on this project that a check
// passed because it was measuring the wrong thing, and the most expensive, because it
// is the check the whole layout plan leans on.
//
// What replaces it renders the window and looks at the pixels. Content that fits the
// detail pane starts at `rowInset` inside it; content wider than the pane centres
// itself and runs back underneath the sidebar, which shows up as leading ink at or
// near zero. That detector cannot be fooled by a scroll view, because it is looking at
// what was drawn.

@Suite("The window's minimum is one its content can actually live in")
@MainActor
struct WindowLayoutTests {
    /// The width of the split view's sidebar pane, measured rather than assumed.
    ///
    /// 236pt for a declared 228: the pane carries the divider. Measured here so the
    /// detector below is not quietly built on a number from a comment.
    static let sidebarPane: CGFloat = {
        MainActor.assumeIsolated {
            let host = NSHostingView(
                rootView: AnyView(FixtureWindow().environment(\.colorScheme, .dark)))
            host.appearance = NSAppearance(named: .darkAqua)
            host.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
            host.layoutSubtreeIfNeeded()
            func split(_ v: NSView) -> NSSplitView? {
                if let s = v as? NSSplitView { return s }
                for c in v.subviews { if let s = split(c) { return s } }
                return nil
            }
            guard let s = split(host) else { return 236 }
            return s.arrangedSubviews.min { $0.frame.minX < $1.frame.minX }?.frame.width ?? 236
        }
    }()

    /// Where the detail pane's content starts, in points from the pane's leading edge.
    ///
    /// `nil` when the pane drew nothing at all, which is a failure of the fixture rather
    /// than a layout result and is reported as such.
    private func paneLeadingInk(_ room: Room, width: CGFloat,
                                devices: [DeviceRowModel] = DeviceRowModel.sampleNetwork) -> CGFloat? {
        let host = NSHostingView(
            rootView: AnyView(
                FixtureWindow(room: room, devices: devices).environment(\.colorScheme, .dark)))
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 700)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / width
        for x in Int(Self.sidebarPane * scale)..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                if let c = rep.colorAt(x: x, y: y), c.brightnessComponent > 0.45 {
                    return (CGFloat(x) / scale) - Self.sidebarPane
                }
            }
        }
        return nil
    }

    private func fits(_ ink: CGFloat?) -> Bool {
        guard let ink else { return false }
        return ink >= Metrics.rowInset - 1
    }

    @Test("Every room fits its pane at the width the window promises",
          arguments: Room.allCases)
    func roomFitsAtTheMinimum(room: Room) {
        let ink = paneLeadingInk(room, width: Metrics.windowMinWidth)
        #expect(
            fits(ink),
            Comment(rawValue: "\(room.title) drew its first content \(ink.map { "\($0)pt" } ?? "nowhere") "
                    + "into a pane that insets by \(Metrics.rowInset)pt — at "
                    + "\(Metrics.windowMinWidth)pt the row is wider than the pane and has "
                    + "centred itself back under the sidebar")
        )
    }

    /// The same detector, the same content, two widths, opposite answers.
    ///
    /// This is what stops the suite above from being a tautology. A minimum that is
    /// merely LARGE passes `roomFitsAtTheMinimum` and tells nobody anything — 1000pt
    /// passed it for months with 114pt of headroom nobody had measured. Requiring the
    /// declared minimum to be close to the real threshold means the number has to stay
    /// honest in both directions.
    ///
    /// **This test is supposed to fail when stage 8 lands.** Compact forms will let the
    /// table fit in a narrower pane, the threshold will drop, and the declared minimum
    /// has to follow it down rather than being left behind as headroom.
    @Test("The minimum is a threshold and not a cushion")
    func theMinimumIsTight() {
        let slack: CGFloat = 24
        let below = Metrics.windowMinWidth - slack
        let ink = paneLeadingInk(.devices, width: below)
        #expect(
            !fits(ink),
            Comment(rawValue: "Devices still fits at \(below)pt, \(slack)pt below the declared "
                    + "minimum of \(Metrics.windowMinWidth)pt — either the table got narrower "
                    + "and the minimum should come down with it, or the minimum was never "
                    + "measured")
        )
    }

    /// Devices is the room that sets the number, and the other two have room to spare.
    ///
    /// Worth stating, because if Activity or Settings ever overtakes it, the minimum is
    /// being set by a screen nobody thought they were setting it with.
    @Test("Devices is the room that sets the minimum")
    func devicesIsTheBindingRoom() {
        let below = Metrics.windowMinWidth - 24
        for room in Room.allCases where room != .devices {
            #expect(fits(paneLeadingInk(room, width: below)),
                    Comment(rawValue: "\(room.title) stopped fitting at \(below)pt, so it — "
                            + "not Devices — now sets the window's minimum"))
        }
    }

    /// What the overflow detector above cannot see, written as its own check.
    ///
    /// **It measures escape, not legibility.** Stage 4's first rendered threshold was
    /// 886pt and the detector was satisfied at it: nothing ran outside the pane. The
    /// render showed a table whose names broke across two lines mid-word —
    /// "Unidentifi / ed device" — and whose gateway row had its name crushed to two
    /// bare strokes beside the chip, because the name column had no floor and the chip
    /// is `fixedSize`. A check that only asks "did anything escape" passes that
    /// happily. Looking at the picture is what caught it, which is the fourth time on
    /// this project.
    ///
    /// So the floor is checked here against the FONT rather than against the token:
    /// the widest single word the column must set, and the widest name that shares its
    /// line with a chip. Lower `nameMinMeasure` and this fails; it cannot be satisfied
    /// by agreeing with itself.
    @Test("The name column can set its longest word without breaking it")
    func theNameColumnHasAFloorThatFits() {
        func fitting(_ v: some View) -> CGFloat {
            let host = NSHostingView(rootView: AnyView(v.environment(\.colorScheme, .dark)))
            host.appearance = NSAppearance(named: .darkAqua)
            host.frame = NSRect(x: 0, y: 0, width: 2000, height: 200)
            host.layoutSubtreeIfNeeded()
            return host.fittingSize.width
        }

        // The widest word in the fixtures, and it is a real device on JC's network.
        let longestWord = fitting(Text("entretenimiento").font(.rowTitle))
        #expect(Metrics.Detail.nameMinMeasure >= longestWord,
                Comment(rawValue: "the column floor is \(Metrics.Detail.nameMinMeasure)pt and "
                        + "its longest word is \(longestWord)pt — the word will break across "
                        + "two lines in the middle"))

        // The binding case: a name sharing its line with the gateway chip, which is
        // `fixedSize` and takes its width before the name gets any.
        let withChip = fitting(
            HStack(spacing: Metrics.unit + 2) {
                Text("Unidentified").font(.rowTitle)
                Chip("gateway", style: .accent)
            }
        )
        #expect(Metrics.Detail.nameMinMeasure >= withChip,
                Comment(rawValue: "the column floor is \(Metrics.Detail.nameMinMeasure)pt but a "
                        + "name beside the gateway chip needs \(withChip)pt — the gateway row's "
                        + "name gets squeezed to nothing and the row reads as unnamed"))
    }

    @Test("The longest strings a real network produces do not move the threshold")
    func realWorstCaseFits() {
        // Not an invented worst case. `sampleNetwork` carries the longest subtitle this
        // app generates — "No name advertised · randomized MAC · no vendor · in ARP
        // table, no ping reply" — beside a chip, and this adds the longest plausible
        // hostname to it. The name column truncates rather than demanding room, so the
        // threshold should not move; this is the test that says so out loud.
        let long = DeviceRowModel(
            id: "long",
            name: "a-very-long-hostname-that-somebody-actually-named-their-nas.local",
            subtitle: "Synology DiskStation DS1821+ · Synology Incorporated · responds to ping",
            presence: .online, identification: .identified,
            ip: "10.10.20.119", mac: "A2:6A:35:C9:0A:BD",
            isPrivateMAC: true, lastSeen: "14 h ago"
        )
        let ink = paneLeadingInk(.devices, width: Metrics.windowMinWidth,
                                 devices: DeviceRowModel.sampleNetwork + [long])
        #expect(fits(ink),
                Comment(rawValue: "a 64-character hostname pushed the table out of its pane "
                        + "at \(Metrics.windowMinWidth)pt — the name column stopped truncating"))
    }
}
