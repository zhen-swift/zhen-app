import AppKit
import SwiftUI
import Testing
@testable import Zhen
// The header block, measured rather than asserted.
//
// Four screens each padded their own header and two of them chose differently — 20 above
// and 12 below on Devices and Activity, 16 and 16 on Settings and Live Scan. The block
// came out the same height either way, so nothing moved except the title inside it, by
// four points, and only while switching rooms: the one moment a person is looking at the
// sidebar instead of the words. It survived a design review that way.
//
// A1 named `headerBlockHeight` and `contentInset` and said nothing about the vertical
// padding, so there was no answer to look up. `headerBlockHeight` was declared in
// `Metrics` and referenced by nothing, which is the same failure one step earlier: a
// number that describes no code cannot be wrong, and cannot be right either.
//
// So this measures the rendered thing. What it defends is not the exact numbers — those
// are allowed to change — but that they are the SAME across every screen, whatever they
// are, and that they come from the tokens rather than from four opinions.
@Suite("Every screen's header sits in the same place")
@MainActor
struct ScreenHeaderTests {
    private func host(_ view: some View, width: CGFloat = 900) -> NSHostingView<AnyView> {
        let host = NSHostingView(rootView: AnyView(view.environment(\.colorScheme, .dark)))
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 200)
        host.layoutSubtreeIfNeeded()
        return host
    }

    private func height(_ view: some View) -> CGFloat {
        host(view).fittingSize.height
    }

    /// The four shapes the real screens use: no controls, one button, a field and a
    /// button, and a row of chips.
    @Test("Trailing controls do not change how tall the header is")
    func heightIsIndependentOfTrailingContent() {
        let plain = height(ScreenHeader("Settings", subtitle: "Version 0.4.0"))
        let oneButton = height(
            ScreenHeader("Scanning 10.10.20.0/24", subtitle: "3 of 254") {
                SecondaryButton("Stop Scan") {}
            }
        )
        let fieldAndButton = height(
            ScreenHeader("Devices", subtitle: "14 devices") {
                SearchField(text: .constant(""))
                PrimaryButton("Scan Now") {}
            }
        )
        let chips = height(
            ScreenHeader("Activity", subtitle: "Last 48 hours · 12 events") {
                HStack(spacing: Metrics.unit * 2) {
                    FilterChip("All", isSelected: true) {}
                    FilterChip("Appeared", isSelected: false) {}
                }
            }
        )

        // A person switching rooms sees these one after another. Any difference is the
        // title moving under a stationary sidebar.
        #expect(plain == oneButton, "Settings and Live Scan disagree about header height")
        #expect(plain == fieldAndButton, "Settings and Devices disagree about header height")
        #expect(plain == chips, "Settings and Activity disagree about header height")
    }

    // The vertical inset is the half that had no stated answer, so it is the half worth
    // pinning to the tokens rather than to a literal.
    @Test("The header's height is the title block plus the tokens above and below it")
    func heightComesFromTheTokens() {
        let padded = height(ScreenHeader("Devices", subtitle: "14 devices"))
        let bare = height(
            VStack(alignment: .leading, spacing: Metrics.unit / 2) {
                Text("Devices").font(.screenTitle)
                Text("14 devices").font(.screenSubtitle)
            }
        )
        let insets = Metrics.headerTopInset + Metrics.headerBottomInset
        #expect(abs((padded - bare) - insets) < 0.5,
                "the header is not padded by the tokens that claim to describe it")
    }

    // A1 gives the inset as horizontal, and every screen did agree about this one. It
    // is pinned anyway: it is the other half of the same block, and the reason the four
    // copies looked identical in review was that this half was.
    @Test("The title starts one content inset from the leading edge")
    func leadingInsetIsTheContentInset() {
        // The comparison has to carry the header's own spacer and spacing, or it
        // measures those as though they were padding — which is what the first version
        // of this test did, and it reported a 32pt inset that does not exist.
        let bare = host(
            HStack(alignment: .top, spacing: Metrics.unit * 4) {
                VStack(alignment: .leading, spacing: Metrics.unit / 2) {
                    Text("Devices").font(.screenTitle)
                    Text("14 devices").font(.screenSubtitle)
                }
                Spacer(minLength: Metrics.unit * 4)
            }
        ).fittingSize.width
        let padded = host(ScreenHeader("Devices", subtitle: "14 devices")).fittingSize.width
        #expect(abs((padded - bare) - Metrics.contentInset * 2) < 0.5,
                "the header's horizontal inset is not `contentInset` on both sides")
    }
}

// The sidebar's left edge, which had three answers.
//
// The section label sat at 16, the room names at 8 + 12 = 20, and the scan footer at 16
// again — so the rows were four points right of the title above them and the status
// below them. Four points is the distance at which a person can see that a column is
// ragged without being able to say what is wrong, which is how it reached a built app.
//
// A3 states the pill inset (8pt from both edges) and says nothing about where text goes
// inside it, so again there was no answer to look up.
@Suite("The sidebar has one left edge")
struct SidebarInsetTests {
    // `sidebarTextInset` is where a room name lands, and anything else in the sidebar
    // has to agree with the rows or the column is ragged. Composed rather than written
    // as 20 so it cannot drift away from the two values it is the sum of.
    @Test("Text in the sidebar starts where a row's text starts")
    func textInsetIsTheRowsTextInset() {
        #expect(Metrics.sidebarTextInset
                == Metrics.sidebarPillInset + Metrics.sidebarPillTextInset)
    }

    // A3 gives this one explicitly, and it is the only one of the three it gives.
    @Test("The selection pill is inset 8pt, as A3 states")
    func pillInsetMatchesTheSpec() {
        #expect(Metrics.sidebarPillInset == 8)
    }
}
