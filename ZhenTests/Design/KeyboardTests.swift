import AppKit
import SwiftUI
import Testing
@testable import Zhen
// The keyboard, and an honest account of what can be checked from here.
//
// ── What this suite used to claim, and why it no longer does ──────────────────
//
// Stage 5 shipped a focus ring that forced focusability with `.focusable()`, so every
// control joined the Tab loop on a stock Mac. This file then drove real Tab events into
// a real `NSWindow`, rendered after each one, and found the ring by diffing against the
// unfocused frame. It reported 12 stops in Devices, 5 in Activity, 5 in Settings, all
// wrapping.
//
// Those numbers were true of that design. **JC chose the platform convention instead**:
// the ring is now drawn from focus the platform granted, and on macOS that means Tab
// visits text fields and lists until Full Keyboard Access is switched on.
// `NSApp.isFullKeyboardAccessEnabled` reads false on this machine, so there is nothing
// for Tab to traverse here and the traversal measurement cannot be repeated.
//
// **It is rewritten rather than deleted, and the claim is withdrawn rather than
// weakened.** A suite that kept asserting traversal would now be asserting something it
// cannot see — the exact failure this project has caught six times.
//
// ── What survives, because it was measured and is still true ──────────────────
//
// **The AppKit key view loop is not where SwiftUI focus lives.** Walking the hierarchy
// for `canBecomeKeyView` finds exactly one view in the whole window — the search field,
// which bridges to an `AppKitTextField`. Three plain buttons find zero. Three
// DEFAULT-styled buttons also find zero.
//
// **Focus does not move unless at least two controls are focusable.** A single one, of
// every recipe tried, never took focus from a Tab. Any future probe written against one
// control will conclude the app has no focus handling.
//
// **A `ButtonStyle` cannot read focus.** `@Environment(\.isFocused)` inside a style's
// body stays false: two styled buttons rendered with focus on the first, the second and
// neither produced three identical bitmaps, zero differing pixels, even with
// `.focusable()` applied. That is why the ring is a modifier holding `@FocusState`.
//
// **Space and Return cannot be driven from here at all.** A `swift test` process cannot
// become the active application: `NSApp.activate` leaves `isActive` false and
// `makeKey()` leaves `isKeyWindow` false, and without a key window SwiftUI routes no
// ordinary key to the focused view — even `.onKeyPress(.space)` on the focused view
// stays silent. Tab was the exception, handled by the hosting view on its way through
// `sendEvent`, which is the only reason the old traversal worked.
//
// Following the platform is what makes that gap tolerable: activation is now the
// platform's to deliver, not something this app reimplements and cannot test.

@Suite("The focus ring draws where focus actually is")
@MainActor
struct FocusRingTests {
    private func settle(_ seconds: TimeInterval = 0.25) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// Pixels close to a token's resolved colour.
    ///
    /// **Counting any difference is not good enough, and that is not caution — the
    /// first version of this test did exactly that and passed while the ring was
    /// suppressed.** Focusing a text field also shows an insertion caret, so "something
    /// changed" is satisfied by the caret alone. Counting pixels of the RING's colour is
    /// what distinguishes the two.
    private func pixelsMatching(_ token: PaletteColor, in rep: NSBitmapImageRep) -> Int {
        // Resolved through the same call `foregroundStyle` and `strokeBorder` make, so
        // the test cannot drift from the palette by restating a hex value.
        var values = EnvironmentValues()
        values.colorScheme = .dark
        let target = token.resolve(in: values)
        var count = 0
        for x in stride(from: 0, to: rep.pixelsWide, by: 1) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 1) {
                guard let pixel = rep.colorAt(x: x, y: y) else { continue }
                let distance = abs(pixel.redComponent - Double(target.red))
                    + abs(pixel.greenComponent - Double(target.green))
                    + abs(pixel.blueComponent - Double(target.blue))
                if distance < 0.12 { count += 1 }
            }
        }
        return count
    }

    /// **The search field is the one control this can be checked on**, and that is not a
    /// convenience — a `TextField` is focusable whatever Full Keyboard Access says, so
    /// it is the only place on this machine where focus can actually land. Every button
    /// in the app draws its ring through the same `@FocusState`-and-overlay path, so
    /// this establishes that the path works; what it cannot establish is that the
    /// platform grants those buttons focus, which is the setting's business.
    /// **The search field is the one control this can be checked on**, and that is not
    /// a convenience: a `TextField` is focusable whatever Full Keyboard Access says, so
    /// it is the only place on this machine where focus can actually land. Every button
    /// in the app draws its ring through the same `@FocusState`-and-overlay path, so
    /// this establishes the path works. What it cannot establish is that the platform
    /// grants those buttons focus, which is the setting's business.
    @Test("A focused field is visibly different from an unfocused one")
    func theRingIsDrawn() {
        // Driven by making the field first responder rather than by `@FocusState`,
        // because the field owns its own focus state internally.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
                              styleMask: [.titled], backing: .buffered, defer: false)
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let host = NSHostingView(rootView: AnyView(
            SearchField(text: binding).padding(20).background(Palette.surface)
                .environment(\.colorScheme, .dark)))
        host.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        host.layoutSubtreeIfNeeded()
        settle()

        let before = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: before)

        // The field bridges to an AppKit text field, which is the one thing in this app
        // that is focusable regardless of the system setting.
        func firstTextView(_ view: NSView) -> NSView? {
            if view.canBecomeKeyView { return view }
            for sub in view.subviews { if let found = firstTextView(sub) { return found } }
            return nil
        }
        guard let field = firstTextView(host) else {
            Issue.record("no focusable view found, so nothing could be focused")
            return
        }
        window.makeFirstResponder(field)
        settle()
        let after = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: after)
        window.orderOut(nil)

        let ringBefore = pixelsMatching(Palette.accent, in: before)
        let ringAfter = pixelsMatching(Palette.accent, in: after)
        // The ring is a 2pt stroke around a field roughly 380 by 28 points, so at 2x
        // backing it is several thousand pixels. A caret is a handful and is not the
        // accent's colour anyway.
        #expect(ringBefore < 100,
                Comment(rawValue: "an unfocused field already has \(ringBefore) accent "
                        + "pixels — something else on this screen is accent-coloured and "
                        + "this count is not measuring the ring"))
        #expect(ringAfter > 500,
                Comment(rawValue: "focusing the field produced \(ringAfter) accent pixels "
                        + "against \(ringBefore) unfocused — the focus ring is not drawn"))
    }

    @Test("The ring is the accent, so it inherits the contrast the palette guarantees")
    func theRingUsesAToken() {
        // Not a tautology: it would fail if someone reached for a literal colour, which
        // is how a control ends up outside `ContrastTests`' reach.
        #expect(Metrics.focusRingWidth >= 2,
                "a hairline halo on a dark surface is a thing you hunt for")
        #expect(Metrics.focusRingGap > 0,
                "without a gap the ring is accent drawn on the accent-filled button")
    }
}

@Suite("Rooms are reachable without a mouse whatever the system setting says")
@MainActor
struct RoomShortcutTests {
    /// **These matter more under the platform convention, not less.**
    ///
    /// `NavigationSplitView` keeps its sidebar out of the Tab loop — measured during
    /// stage 5, and `focusSection()` on both columns did not change it. With Full
    /// Keyboard Access off there is no Tab traversal either. So Command-1, Command-2 and
    /// Command-3 are the only way to change rooms without a mouse, on a stock Mac.
    @Test("Every room has a distinct shortcut, and they are the drawn order")
    func everyRoomHasOne() {
        let shortcuts = Room.allCases.map(\.shortcut)
        #expect(Set(shortcuts.map(\.character)).count == Room.allCases.count,
                Comment(rawValue: "two rooms share a key: \(shortcuts.map(\.character))"))
        #expect(shortcuts.map(\.character) == ["1", "2", "3"],
                "the keys no longer match the order the rooms are drawn in")
    }

    @Test("Command-2 and Command-3 change the room")
    func shortcutsChangeTheRoom() {
        // Driven, not asserted from the declaration. A shortcut bound to the wrong
        // action, or to nothing, fails here: the window would still look like Devices.
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        func still(_ room: Room) -> NSBitmapImageRep { render(room, pressing: nil) }

        func render(_ room: Room, pressing key: (String, UInt16)?) -> NSBitmapImageRep {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: Metrics.windowMinWidth, height: 800),
                styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            let host = NSHostingView(rootView: AnyView(
                FixtureWindow(room: room).environment(\.colorScheme, .dark)))
            host.appearance = NSAppearance(named: .darkAqua)
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            window.layoutIfNeeded(); host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            if let key, let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: .command,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil,
                characters: key.0, charactersIgnoringModifiers: key.0,
                isARepeat: false, keyCode: key.1) {
                window.sendEvent(event)
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            }
            let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: rep)
            window.orderOut(nil)
            return rep
        }

        func difference(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep) -> Double {
            guard a.pixelsWide == b.pixelsWide, a.pixelsHigh == b.pixelsHigh else { return 1 }
            var differing = 0, total = 0
            for x in stride(from: 0, to: a.pixelsWide, by: 6) {
                for y in stride(from: 0, to: a.pixelsHigh, by: 6) {
                    guard let ca = a.colorAt(x: x, y: y), let cb = b.colorAt(x: x, y: y) else { continue }
                    total += 1
                    if abs(ca.redComponent - cb.redComponent)
                        + abs(ca.greenComponent - cb.greenComponent)
                        + abs(ca.blueComponent - cb.blueComponent) > 0.12 { differing += 1 }
                }
            }
            return total == 0 ? 1 : Double(differing) / Double(total)
        }

        let devices = still(.devices)
        for (room, key, code) in [(Room.activity, "2", UInt16(19)), (Room.settings, "3", UInt16(20))] {
            let target = still(room)
            let after = render(.devices, pressing: (key, code))
            let toTarget = difference(after, target)
            let toDevices = difference(after, devices)
            #expect(toTarget < toDevices,
                    Comment(rawValue: "Command-\(key) left the window \(Int(toTarget * 100))% "
                            + "unlike \(room.title) and \(Int(toDevices * 100))% unlike Devices "
                            + "— it did not change the room"))
        }
    }
}
