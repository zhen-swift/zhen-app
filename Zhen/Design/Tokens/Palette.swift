// Palette.swift — every colour in the app, by role.
//
// Semantic names only. Nobody outside this file writes a colour value, ever — the moment
// a `Color(hex:)` helper exists, hex values start appearing in views and the system stops
// being a system. A3's definition of done makes that checkable: grep for `Color(red:`
// outside `Tokens/` and it must return nothing.
//
// ── Why these are not in an asset catalog ────────────────────────────────────────
//
// A1's colour section says to put each colour in an asset catalog with Any and Dark
// appearances. That is the right instinct and it does not work for a standalone SwiftPM
// package: **`swift build` never runs `actool`.** Asset-catalog compilation is a feature
// of Xcode's build system, so SwiftPM copies `Assets.xcassets` into the resource bundle
// verbatim, `Color(_:bundle:)` finds no compiled `.car` at runtime, and every token
// silently resolves to white. It was built that way first; the previews came out blank
// with white text on white, which is exactly the failure mode you would expect and
// exactly the one nobody notices in a code review.
//
// So the values live here, one token per role, resolved at draw time. That keeps every
// property A1 actually asked for: light and dark stay a DATA change rather than a branch
// in view code, the values appear exactly once, and adding an appearance is a change to
// this file alone.
//
// ── Why a `ShapeStyle` and no longer an `NSColor` provider ───────────────────────
//
// This used to be `NSColor(name:dynamicProvider:)`, which is what an asset-catalog colour
// compiles down to and which resolves against the current `NSAppearance`. It worked, and
// it could not see Increase Contrast — the accessibility appearances collapse into their
// base:
//
//     NSAppearance(named: .accessibilityHighContrastDarkAqua)!.name
//         -> NSAppearanceNameDarkAqua
//
// so a four-way `bestMatch(from:)` inside the provider reads `.darkAqua` and the setting
// is invisible. Worse, that appearance is not constructible standalone — it exists only
// on an appearance handed down by a live view hierarchy with the setting on — so a test
// could never build one, and a suite that looked like it checked Increase Contrast would
// have measured the ordinary palette twice and passed.
//
// A `ShapeStyle` implementing `resolve(in:)` is handed the whole `EnvironmentValues`,
// which carries `\.colorScheme` AND `\.colorSchemeContrast`. Same job, no AppKit, and the
// accessibility setting becomes reachable. See <doc:Corrections>'s Increase Contrast
// entry.
//
// ── The one API cost, and what was decided about it ──────────────────────────────
//
// A `ShapeStyle` covers `foregroundStyle`, `background`, `fill` and `tint` — which is
// every call site in this package but two kinds. The exceptions are a ternary that mixes
// a token with `Color.clear`, and a component's private computed property typed `Color`.
//
// Those call sites were CHANGED rather than served by a `Color` accessor, and the reason
// is that a `Color` accessor would have been a quiet hole in the feature. A `Color` is
// resolved by SwiftUI against the colour scheme and nothing else; there is no way to make
// one carry a contrast tier. So every site reached through a `Color` accessor would have
// silently kept the standard palette under Increase Contrast — and those sites are the
// selection fill, the stage-card symbol and the progress fill, which is precisely the
// low-contrast furniture the setting exists to strengthen. A feature that is on
// everywhere except where you needed it is worse than one that is off, because nobody
// checks.
//
// So `PaletteColor.clear` exists to keep those ternaries in the token type, and the two
// `Color`-typed properties became `PaletteColor`-typed. `color(in:)` is kept for genuine
// interop — it takes the environment explicitly, so a caller cannot obtain one without
// saying which appearance it is for, and cannot obtain one by accident.

import SwiftUI

/// Every colour the design system defines, named for what it is used for rather than for
/// what it looks like.
public enum Palette {
    /// The content background — 77% of the window.
    public static let surface = token(dark: 0x1A1A1F, light: 0xFFFFFF)
    /// Sidebar and card fills, one step up from `surface`.
    public static let surfaceRaised = token(dark: 0x212127, light: 0xEEEDF3)
    /// Text field and chip backgrounds.
    public static let surfaceField = token(dark: 0x2C2C32, light: 0xF0F0F0)
    /// The hairline between table rows and inside cards.
    ///
    /// A border rather than text, so its floor is WCAG 1.4.11's 3:1 for non-text UI
    /// components, not 4.5:1 — at standard contrast it is deliberately below even that,
    /// because a separator that meets a text floor is a rule, not a hairline. Increase
    /// Contrast is where it earns 3:1.
    public static let separator = token(
        dark: 0x2A2A2F, light: 0xE3E3E8,
        darkIncreased: 0x75757A, lightIncreased: 0x88888D
    )
    /// The fill behind a selected sidebar row or table row.
    public static let selection = token(dark: 0x373548, light: 0xDBD8ED)
    /// Wisteria. Buttons, links, confidence bars, merge events.
    ///
    /// A different purple in each theme, and that is deliberate rather than sloppy: the
    /// same value on white is too pale to read and the darker one on `#1A1A1F`
    /// disappears. 6.64:1 on dark, 5.45:1 on light; 8.80:1 and 8.16:1 under Increase
    /// Contrast.
    public static let accent = token(
        dark: 0xA495E8, light: 0x6A58C9,
        darkIncreased: 0xBDAEFF, lightIncreased: 0x4E3CAD
    )
    /// What sits ON the accent — a button's label. Dark surface on dark, white on light.
    ///
    /// No increased variant: the pair inverts between themes, so lifting the accent
    /// lifts this pair too — 6.64:1 and 5.45:1 become 8.80:1 and 8.16:1 without this
    /// token moving at all.
    public static let onAccent = token(dark: 0x1A1A1F, light: 0xFFFFFF)
    /// Device names, values, anything the eye should land on first. 14.59:1 / 16.83:1.
    ///
    /// No increased variant, and this is the one token that needs none: its weakest
    /// pairing is 11.68:1 on dark `surfaceField`, already past AAA.
    public static let textPrimary = token(dark: 0xEBEBF0, light: 0x1D1D1F)
    /// Subtitles, column headers, the vendor and model line.
    ///
    /// **Corrected twice, and the second correction is the interesting one.**
    ///
    /// The artboards sample `#65656C` and `#ADADB0`, which are 3.00:1 and 2.24:1. This
    /// token carries the line that makes an unidentified device legible instead of
    /// blank — seven rows out of ten on the reference network — so it cannot be 3:1.
    ///
    /// The first correction lifted it to 4.52:1 and 4.53:1, **measured against
    /// `surface` alone**. This design has THREE text backgrounds, and against the other
    /// two those values fail: 4.18:1 on dark `surfaceRaised`, 3.62:1 on dark
    /// `surfaceField`, 3.89:1 and 3.97:1 on their light counterparts. Which meant
    /// secondary text was compliant in the device list and non-compliant nearly
    /// everywhere else — every card, every settings row, the sidebar footer, and the
    /// `private` chip. Deriving a colour against one background when the palette has
    /// several is the whole bug, and it is easy to make twice.
    ///
    /// These values clear 4.5:1 against **every** surface in the palette, and the
    /// increased pair clears 7:1 against every surface. Hue is unchanged in both: every
    /// channel moved by the same amount.
    public static let textSecondary = token(
        dark: 0x939396, light: 0x6B6B6E,
        darkIncreased: 0xB8B8BB, lightIncreased: 0x4F4F52
    )
    /// Sidebar section labels and grid labels.
    ///
    /// Held to the same rule, and note what that does: at AA against all three
    /// surfaces, secondary and tertiary CONVERGE — they differ here by three units of
    /// blue on dark and one on light, which is not a visible step.
    ///
    /// That is not a mistake to tidy up later. The two are different ROLES with
    /// different type treatments — tertiary is always 11pt semibold uppercase with
    /// +0.6 tracking, secondary is 12pt regular sentence case — and once both are held
    /// to the same floor on the same backgrounds there is no room left below the floor
    /// for one to be quieter than the other in colour. A1's original pair had the step
    /// INVERTED anyway (tertiary lighter, and therefore louder, than secondary on
    /// dark), because the two were derived against different backgrounds. The hierarchy
    /// is typographic. See <doc:Corrections>.
    public static let textTertiary = token(
        dark: 0x939399, light: 0x6A6A6E,
        darkIncreased: 0xB8B8BE, lightIncreased: 0x4F4F53
    )
    /// The ring of the hollow dot on an offline row.
    ///
    /// A shape's outline, so 3:1 rather than 4.5:1 — and the increased variant is what
    /// takes it there. Hollow versus filled is what carries the meaning; the ring only
    /// has to be findable.
    public static let offlineRing = token(
        dark: 0x49494F, light: 0xC4C4C9,
        darkIncreased: 0x75757B, lightIncreased: 0x88888D
    )

    /// State colours, split by whether they mark something or spell something.
    ///
    /// **The split is a correction and it matters.** The artboards use one vivid green
    /// for both the status dot and the "APPEARED" label in the activity list. As a dot
    /// that is fine — a dot is a shape, filled versus hollow carries the meaning, and
    /// A1's accessibility floor says so explicitly. As TEXT on white it is 1.96:1, which
    /// is unreadable; amber is 2.17:1 and blue is 2.32:1.
    ///
    /// So there are two families. `online`/`warning`/`info` are the artboard colours,
    /// unchanged in both themes and under Increase Contrast, for dots, fills and progress
    /// tracks — they are shapes, and changing them would change what the design looks
    /// like rather than what it is legible at. The `…Text` variants are identical on dark
    /// — where the vivid colours already reach 7–9:1 — and darkened on light so a kind
    /// label passes 4.5:1 on both `surface` and `surfaceRaised`, and 7:1 when the setting
    /// is on.
    public enum Status {
        /// A live host, a completed stage, an "appeared" event mark.
        public static let online = token(dark: 0x4CD268, light: 0x4CD268)
        /// Partial results, port events. Amber, not red: nothing here is broken.
        public static let warning = token(dark: 0xD9A856, light: 0xD9A856)
        /// An address change. Informational, not a problem.
        public static let info = token(dark: 0x6DB3D4, light: 0x6DB3D4)

        /// `online` where it is used as text. 8.85:1 dark, 5.73:1 light; 8.85 / 8.20 HC.
        public static let onlineText = token(
            dark: 0x4CD268, light: 0x217538,
            darkIncreased: 0x4CD268, lightIncreased: 0x085C1F
        )
        /// `warning` where it is used as text. 8.00:1 dark, 5.53:1 light; 8.82 / 8.23 HC.
        public static let warningText = token(
            dark: 0xD9A856, light: 0x8A6114,
            darkIncreased: 0xE2B15F, lightIncreased: 0x6F4600
        )
        /// `info` where it is used as text. 7.47:1 dark, 5.59:1 light; 8.82 / 8.15 HC.
        public static let infoText = token(
            dark: 0x6DB3D4, light: 0x256F90,
            darkIncreased: 0x7CC2E3, lightIncreased: 0x0B5576
        )
    }
}

/// Builds one token.
///
/// The increased-contrast values default to the standard ones, so a token that needs no
/// accessibility variant says so by omission rather than by repeating itself. That is
/// the majority: `textPrimary` is already past AAA, `onAccent` inverts with the accent,
/// and the status MARKS are shapes rather than text.
///
/// The literals passed to this function are the ONLY place hex appears in this project.
private func token(
    dark: UInt32, light: UInt32,
    darkIncreased: UInt32? = nil, lightIncreased: UInt32? = nil
) -> PaletteColor {
    PaletteColor(
        dark: dark, light: light,
        darkIncreased: darkIncreased ?? dark,
        lightIncreased: lightIncreased ?? light
    )
}

/// One palette token: a colour that knows what it should be in each appearance.
///
/// A `ShapeStyle` rather than a `Color`, because `resolve(in:)` is handed the whole
/// environment and a `Color` is only ever resolved against the colour scheme. That
/// difference is the entire reason Increase Contrast is reachable at all — see the note
/// at the top of this file.
public struct PaletteColor: ShapeStyle, Sendable, Hashable {
    private let dark: UInt32
    private let light: UInt32
    private let darkIncreased: UInt32
    private let lightIncreased: UInt32
    private let alpha: Double

    fileprivate init(
        dark: UInt32, light: UInt32, darkIncreased: UInt32, lightIncreased: UInt32,
        alpha: Double = 1
    ) {
        self.dark = dark
        self.light = light
        self.darkIncreased = darkIncreased
        self.lightIncreased = lightIncreased
        self.alpha = alpha
    }

    /// Fully transparent, and a `PaletteColor` rather than a `Color`.
    ///
    /// Exists so that `isSelected ? Palette.selection : .clear` type-checks without the
    /// token having to become a `Color` — which would cost that call site its Increase
    /// Contrast behaviour, and those call sites are selection fills and progress fills,
    /// exactly the furniture the setting is for.
    public static let clear = PaletteColor(
        dark: 0, light: 0, darkIncreased: 0, lightIncreased: 0, alpha: 0
    )

    /// The value this token takes under one appearance.
    ///
    /// Separated from `resolve(in:)` so it can be reasoned about — and measured — without
    /// constructing an `EnvironmentValues`. `resolve(in:)` is a two-line wrapper over it,
    /// so a test that drives this drives what a view draws.
    public func resolved(
        scheme: ColorScheme, contrast: ColorSchemeContrast
    ) -> Color.Resolved {
        let packed = switch (scheme, contrast) {
        case (.dark, .standard): dark
        case (.dark, .increased): darkIncreased
        case (_, .standard): light
        case (_, .increased): lightIncreased
        @unknown default: light
        }
        return Color.Resolved(
            red: Float((packed >> 16) & 0xFF) / 255,
            green: Float((packed >> 8) & 0xFF) / 255,
            blue: Float(packed & 0xFF) / 255,
            opacity: Float(alpha)
        )
    }

    /// `ShapeStyle`'s hook. This is what `foregroundStyle`, `background` and `fill` call.
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        resolved(scheme: environment.colorScheme, contrast: environment.paletteContrast)
    }

    /// The same token at a different alpha.
    ///
    /// Shadows `ShapeStyle.opacity(_:)` deliberately: that one returns an opaque
    /// `some ShapeStyle`, which would stop the result being usable where a `PaletteColor`
    /// is expected — including the other branch of a ternary against `.clear`.
    public func opacity(_ opacity: Double) -> PaletteColor {
        PaletteColor(
            dark: dark, light: light,
            darkIncreased: darkIncreased, lightIncreased: lightIncreased,
            alpha: alpha * opacity
        )
    }

    /// A concrete `Color`, for the few APIs that will not take a `ShapeStyle`.
    ///
    /// Takes the environment rather than reading it, and there is no
    /// environment-free overload on purpose. A `Color` cannot carry a contrast tier, so
    /// every one produced here is a snapshot of one appearance — fine when the caller
    /// has the environment in hand and knows it, and a silent bug when it is reached for
    /// out of convenience. Making the appearance an argument means a call site cannot
    /// pretend not to know.
    public func color(in environment: EnvironmentValues) -> Color {
        Color(resolve(in: environment))
    }
}

// ── Forcing the contrast tier ─────────────────────────────────────────────────────

/// Storage for the override. Written by hand rather than with `@Entry` because both
/// accessors have to be `nonisolated`: this module is main-actor by default, and
/// `ShapeStyle.resolve(in:)` is not — a main-actor-isolated environment property cannot
/// be read from the one place the palette actually needs to read it.
private struct PaletteContrastOverrideKey: EnvironmentKey {
    nonisolated static let defaultValue: ColorSchemeContrast? = nil
}

public extension EnvironmentValues {
    /// Overrides the system's Increase Contrast setting for the palette.
    ///
    /// This exists because `\.colorSchemeContrast` is **get-only**: SwiftUI derives it
    /// from the system setting and offers no way to set it, so neither a preview nor a
    /// test can ask to see the high-contrast palette. A design system whose
    /// accessibility variant can only be viewed by changing a system-wide setting and
    /// relaunching is one nobody will look at, and the contrast suite could not measure
    /// it at all.
    ///
    /// `nil` — the default — means follow the system, which is what the app does.
    nonisolated var paletteContrastOverride: ColorSchemeContrast? {
        get { self[PaletteContrastOverrideKey.self] }
        set { self[PaletteContrastOverrideKey.self] = newValue }
    }

    /// The contrast tier the palette should resolve at: the override if one is set,
    /// otherwise whatever the system says.
    nonisolated var paletteContrast: ColorSchemeContrast {
        paletteContrastOverride ?? colorSchemeContrast
    }
}

public extension View {
    /// Renders this subtree at a chosen contrast tier, for previews and tests.
    ///
    /// Not for production use: the app follows the system setting, which is the point of
    /// the setting.
    func paletteContrast(_ contrast: ColorSchemeContrast?) -> some View {
        environment(\.paletteContrastOverride, contrast)
    }
}
