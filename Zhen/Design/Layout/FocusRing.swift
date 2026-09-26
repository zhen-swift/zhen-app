// FocusRing.swift — the one place a control says "the keyboard can reach me".
//
// Stage 5 of `RESPONSIVE-plan.md`. Before it, the app had zero focus handling across
// every control, and that is not a polish gap: an app that cannot be operated from the
// keyboard fails WCAG 2.2 criterion 2.1.1 Keyboard, at level A.
//
// **Measured rather than counted.** The survey in the plan counted occurrences of
// `@FocusState`, `.focusable`, `.onKeyPress` and `keyboardShortcut` and found none. The
// stronger statement comes from driving the window: a synthetic Tab into a hosted
// `FixtureWindow` moved focus to exactly one thing, the search field, because a
// `TextField` bridges to AppKit and brings its own focus with it. Every button in the
// app was unreachable.
//
// ── Why a modifier and not a ButtonStyle ──────────────────────────────────────
//
// A `ButtonStyle` cannot read focus. Its `Configuration` carries `isPressed` and
// nothing else, and `@Environment(\.isFocused)` inside a style's body was MEASURED to
// stay false: rendering two styled buttons with focus set to the first, then the
// second, then neither, produced three identical bitmaps — zero differing pixels — even
// with `.focusable()` applied. So the ring has to come from a view that can hold
// `@FocusState`, which is a modifier.
//
// It is applied where `.buttonStyle(.plain)` is, which also means it works on the things
// that are buttons without looking like buttons: a device row, a sidebar room, a filter
// chip.
//
// ── Why it does NOT call `.focusable()` ───────────────────────────────────────
//
// **This reverses what stage 5 first shipped, and the reversal is JC's call.** The
// first version forced focusability, so every control joined the Tab loop on a stock
// Mac. That met the plan's gate literally and departed from the platform: on macOS, Tab
// visits text fields and lists until a person turns on Full Keyboard Access, and Apple's
// own applications behave that way.
//
// Forcing it also bought an unverifiable risk. If SwiftUI focuses the WRAPPER rather
// than the button inside it, Space and Return never reach the button — and that could
// not be tested from here, because a `swift test` process cannot become the active
// application, so its window never becomes key and no ordinary key is routed to the
// focused view. Letting the platform grant focus makes activation the platform's, which
// is the one way to be sure of it without being able to press the key.
//
// **The cost is stated rather than hidden: with Full Keyboard Access off, this ring
// never appears on a button, and that cannot be verified on a machine where the setting
// is off.** What is verifiable here is the drawing path itself, through the search
// field — a `TextField` is focusable whatever the setting says — and `FocusRingTests`
// does exactly that. The room shortcuts in `Room.shortcut` become the only keyboard
// route when the setting is off, which makes them load-bearing rather than a
// convenience.
//
import SwiftUI

/// Where a focus ring is drawn, and in what shape.
public enum FocusRingShape: Equatable, Sendable {
    /// A rounded rectangle at the control's own radius, drawn one gap OUTSIDE it.
    ///
    /// The default, and right for anything with room around it: a button, a chip, a
    /// sidebar room inside its pill inset.
    case rounded(CGFloat)
    /// A capsule, drawn one gap outside. For the filter chips, whose background is one.
    case capsule
    /// A rounded rectangle drawn INSIDE the control's bounds.
    ///
    /// For a full-bleed row. A device row runs the whole width of its pane, so a ring
    /// outside it would be drawn outside the pane and clipped away on both sides — the
    /// one case where the outside ring is not merely wrong but invisible.
    case inset(CGFloat)
}

public extension View {
    /// Makes this control keyboard-reachable and rings it when it has focus.
    ///
    /// Applied beside `.buttonStyle(.plain)`, never instead of it: the plain style is
    /// what removes the system's chrome, and this is what puts back the one piece of
    /// chrome that carries meaning.
    func zhenFocusRing(_ shape: FocusRingShape = .rounded(Metrics.fieldRadius)) -> some View {
        modifier(ZhenFocusRing(shape: shape))
    }
}

/// The ring itself. Internal: `zhenFocusRing(_:)` is the API.
struct ZhenFocusRing: ViewModifier {
    @FocusState private var focused: Bool
    let shape: FocusRingShape

    func body(content: Content) -> some View {
        content
            // No `.focusable()`. See the note above: the platform decides what the
            // keyboard can reach, and this only draws what it decided.
            .focused($focused)
            // The system's own effect is suppressed because this replaces it. It is
            // suppressed and not merely covered: two rings at two radii on a control
            // whose background the design system drew is worse than either.
            .focusEffectDisabled()
            .overlay { ring.opacity(focused ? 1 : 0) }
            .animation(.easeOut(duration: 0.1), value: focused)
    }

    /// Negative padding grows the ring OUTSIDE the control; positive insets it.
    private var outset: CGFloat { Metrics.focusRingGap + Metrics.focusRingWidth }

    @ViewBuilder private var ring: some View {
        switch shape {
        case .rounded(let radius):
            RoundedRectangle(cornerRadius: radius + Metrics.focusRingGap)
                .strokeBorder(Palette.accent, lineWidth: Metrics.focusRingWidth)
                .padding(-outset)
        case .capsule:
            Capsule()
                .strokeBorder(Palette.accent, lineWidth: Metrics.focusRingWidth)
                .padding(-outset)
        case .inset(let radius):
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Palette.accent, lineWidth: Metrics.focusRingWidth)
                .padding(Metrics.focusRingGap)
        }
    }
}
