// ScreenScroll.swift — a screen's content area, which scrolls whether or not it has to.
//
// ── Why an empty screen still contains a scroll view ─────────────────────────────
//
// A screen that is a `ScrollView` when it has rows and a plain view when it has none is
// two different things to the window around it. macOS decides the titlebar's scroll-edge
// treatment from whether the detail column scrolls, and the window is configured
// `.unifiedCompact`, so the chrome above the content is not the same height in both
// cases. The symptom is not a scroll bar appearing. It is the entire window's content
// sitting a few points higher in the room that happens to be empty, which reads as the
// whole app twitching as you move between rooms.
//
// Nothing about that is visible while writing either screen, because each one is correct
// on its own. It only shows when you switch, and it only shows on a machine where one
// room has data and another does not — which is every machine, in the first minutes of
// use, when the device list is full and nothing has changed yet.
//
// So the container is decided by the screen, not by its contents. An empty state still
// gets a scroll view; it simply has nothing to scroll.

import SwiftUI

/// The scrolling content area every screen puts below its header.
public struct ScreenScroll<Content: View>: View {
    private let content: Content

    /// Wraps a screen's content.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            content
                // A scroll view offers unbounded height, so anything inside it that
                // wanted to fill — an empty state centring itself, for one — would
                // collapse to its natural size and sit at the top instead. This pins
                // the content to the viewport's height, so "centred in the screen"
                // still means the screen.
                .containerRelativeFrame(.vertical, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
