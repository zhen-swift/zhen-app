import SwiftUI
import Testing
@testable import Zhen
// The contrast floor, measured rather than asserted.
//
// A1's accessibility floor sets 4.5:1 for every text token, and its contrast correction
// revises two of them because the artboard values fail. That correction is the
// load-bearing claim in the whole appendix — it is why the vendor line, the model line
// and the "Randomized MAC · no vendor" explanation are readable at all — and nothing
// pinned it until this file existed.
//
// It should have. The first correction was derived against `surface` alone, and this
// design has three text backgrounds; against the other two the "corrected" values were
// still failing, in every card and every settings row. A number in a table cannot catch
// that. A test that walks every pair can.
//
// ── The one rule that makes this test worth having ───────────────────────────────
//
// **The values are read back through the same code path the views use.** Not from a
// duplicated table of hex constants — a test that restates the constants proves only
// that someone can type the same number twice.
//
// That rule survived the move off `NSColor`, and got stronger. It used to mean handing
// the token to AppKit inside `performAsCurrentDrawingAppearance` and hoping that was the
// appearance SwiftUI would have been in. It now means calling `PaletteColor.resolve(in:)`
// with an `EnvironmentValues` — which is not an approximation of what a view does, it is
// the exact function `foregroundStyle`, `background` and `fill` call.
//
// ── And it is why Increase Contrast is testable at all now ───────────────────────
//
// There used to be no high-contrast suite here, and the absence was correct: the
// accessibility appearances collapse into their base, `NSAppearance(named:
// .accessibilityHighContrastDarkAqua)` resolves to plain `.darkAqua`, and a suite that
// looked like it checked the setting would have measured the ordinary palette twice and
// passed. A green suite that proves nothing is worse than no suite.
//
// `\.colorSchemeContrast` is get-only, so it cannot be set here either. What can be set
// is the palette's own override, which exists for exactly this reason and for previews.
// `contrastTiersActuallyDiffer` below is the guard that keeps this suite honest: if the
// override ever stops reaching the resolver, every AAA measurement would silently be a
// standard-palette measurement, and that test fails first.

/// The environment a view would be in, for one appearance.
private func environment(
    _ scheme: ColorScheme, _ contrast: ColorSchemeContrast
) -> EnvironmentValues {
    var values = EnvironmentValues()
    values.colorScheme = scheme
    values.paletteContrastOverride = contrast
    return values
}

/// Resolves a token exactly as `foregroundStyle` would, and reads sRGB out of it.
///
/// `Color.Resolved`'s `red`/`green`/`blue` are gamma-encoded sRGB — the same space the
/// artboards were sampled in and the same one WCAG's formula expects before its own
/// linearisation step. `linearRed` and friends are the pre-linearised values and would
/// double-apply the transfer function if used here.
private func components(
    _ token: PaletteColor, _ values: EnvironmentValues
) -> (r: Double, g: Double, b: Double) {
    let resolved = token.resolve(in: values)
    return (Double(resolved.red), Double(resolved.green), Double(resolved.blue))
}

/// WCAG 2.1 relative luminance.
private func luminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
    func channel(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
}

/// The WCAG contrast ratio between two tokens under one appearance.
private func ratio(
    _ foreground: PaletteColor, on background: PaletteColor,
    _ scheme: ColorScheme, _ contrast: ColorSchemeContrast
) -> Double {
    let values = environment(scheme, contrast)
    let a = luminance(components(foreground, values))
    let b = luminance(components(background, values))
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
}

private let themes: [ColorScheme] = [.dark, .light]

/// AA for body text. Everything in this design is body text: the largest token is 22pt
/// regular-weight, which is below the 24pt threshold that would let it qualify as large.
private let floorAA = 4.5

/// AAA, and the bar Increase Contrast exists to clear. 7:1 is the natural target: it is
/// WCAG's own enhanced level for body text, and a setting that moved the numbers without
/// crossing a named threshold would be decoration.
private let floorAAA = 7.0

/// WCAG 1.4.11, non-text contrast. Separators and the offline ring are UI components
/// rather than text, and holding a hairline to a text floor would make it a rule.
private let floorNonText = 3.0

@Suite("Every text pair clears WCAG AA, and AAA under Increase Contrast")
@MainActor
struct ContrastTests {
    /// The three surfaces text is drawn on.
    ///
    /// `surfaceField` is in this list and is not in A1's reasoning, which is how the
    /// second derivation error happened. Chips, filter chips and the search field all
    /// put text on it, and the `private` chip is 10pt — small text, so it needs the full
    /// 4.5:1 like everything else.
    static let surfaces: [(String, PaletteColor)] = [
        ("surface", Palette.surface),
        ("surfaceRaised", Palette.surfaceRaised),
        ("surfaceField", Palette.surfaceField),
    ]

    static let textTokens: [(String, PaletteColor)] = [
        ("textPrimary", Palette.textPrimary),
        ("textSecondary", Palette.textSecondary),
        ("textTertiary", Palette.textTertiary),
    ]

    static let statusLabels: [(String, PaletteColor)] = [
        ("onlineText", Palette.Status.onlineText),
        ("warningText", Palette.Status.warningText),
        ("infoText", Palette.Status.infoText),
    ]

    /// Every token that is drawn as words, on every background it can land on.
    static var everyTextPair: [(String, PaletteColor, String, PaletteColor)] {
        (textTokens + statusLabels).flatMap { token in
            surfaces.map { (token.0, token.1, $0.0, $0.1) }
        }
        + surfaces.map { ("accent", Palette.accent, $0.0, $0.1) }
    }

    @Test("Text clears 4.5:1 on every surface, in both themes")
    func textAtStandardContrast() {
        for scheme in themes {
            for (token, colour, surface, background) in Self.everyTextPair {
                let measured = ratio(colour, on: background, scheme, .standard)
                #expect(
                    measured >= floorAA,
                    "\(token) on \(surface), \(scheme): \(String(format: "%.2f", measured)):1"
                )
            }
        }
    }

    @Test("Text clears 7:1 on every surface with Increase Contrast on")
    func textAtIncreasedContrast() {
        // The new half. Note it walks the same pairs as the AA test rather than a
        // hand-picked subset: the failure this whole file exists to catch was a value
        // derived against one background and applied to three, and an accessibility
        // variant is exactly as capable of that mistake as the original was.
        for scheme in themes {
            for (token, colour, surface, background) in Self.everyTextPair {
                let measured = ratio(colour, on: background, scheme, .increased)
                let note = "\(token) on \(surface), \(scheme), increased: "
                    + String(format: "%.2f", measured) + ":1"
                #expect(measured >= floorAAA, "\(note)")
            }
        }
    }

    @Test("The button label reads on the accent, in both directions and both tiers")
    func onAccentBothWays() {
        // Both directions because the pair inverts between themes: the label is the dark
        // surface colour on dark and white on light. A2's PrimaryButton asserts both pass
        // "comfortably" — this is what makes that checkable.
        //
        // `onAccent` has no increased variant, and this is what says that is sound: the
        // accent moves under Increase Contrast and carries the pair with it.
        for scheme in themes {
            #expect(ratio(Palette.onAccent, on: Palette.accent, scheme, .standard) >= floorAA)
            let increased = ratio(Palette.onAccent, on: Palette.accent, scheme, .increased)
            let note = "onAccent on accent, \(scheme), increased: "
                + String(format: "%.2f", increased) + ":1"
            #expect(increased >= floorAAA, "\(note)")
        }
    }

    @Test("Separators and the offline ring reach the non-text floor when asked to")
    func nonTextAtIncreasedContrast() {
        // Deliberately NOT asserted at standard contrast. A hairline that clears 3:1
        // against its own background is not a hairline, and A1 draws these as the
        // faintest thing on the screen on purpose. Increase Contrast is where a user who
        // needs the structure visible gets it, and 3:1 is WCAG 1.4.11's bar for a UI
        // component rather than 4.5:1 for text.
        for scheme in themes {
            for (name, token) in [("separator", Palette.separator),
                                  ("offlineRing", Palette.offlineRing)] {
                for (surfaceName, background) in Self.surfaces {
                    let measured = ratio(token, on: background, scheme, .increased)
                    let note = "\(name) on \(surfaceName), \(scheme), increased: "
                        + String(format: "%.2f", measured) + ":1"
                    #expect(measured >= floorNonText, "\(note)")
                }
            }
        }
    }

    @Test("The themes actually differ, so a resolving token is really being read")
    func themesResolveDifferently() {
        // Guards the test itself. If `components` stopped honouring the scheme, every
        // measurement above would silently be taken in one theme twice, and the suite
        // would still pass while proving nothing.
        for (name, token) in Self.textTokens + Self.surfaces {
            #expect(components(token, environment(.dark, .standard))
                    != components(token, environment(.light, .standard)),
                    "\(name) resolves identically in both themes")
        }
    }

    @Test("The contrast tiers actually differ, so the AAA suite is not the AA suite twice")
    func contrastTiersActuallyDiffer() {
        // The guard that replaces the old comment explaining why there was no
        // high-contrast suite. If `paletteContrastOverride` ever stopped reaching
        // `resolve(in:)` — a renamed key, a lost `nonisolated`, a default that swallows
        // the value — `textAtIncreasedContrast` would quietly measure the standard
        // palette against a 7:1 floor. Most tokens would still pass, because most of
        // them already clear 7:1 on dark. This fails instead.
        let declaresAVariant: [(String, PaletteColor)] =
            [("textSecondary", Palette.textSecondary),
             ("textTertiary", Palette.textTertiary),
             ("accent", Palette.accent),
             ("separator", Palette.separator),
             ("offlineRing", Palette.offlineRing),
             ("warningText", Palette.Status.warningText),
             ("infoText", Palette.Status.infoText)]
        for scheme in themes {
            for (name, token) in declaresAVariant {
                #expect(components(token, environment(scheme, .standard))
                        != components(token, environment(scheme, .increased)),
                        "\(name) is unchanged by Increase Contrast in \(scheme)")
            }
        }
    }

    @Test("With no override, the palette follows the system's contrast setting")
    func overrideFallsBackToTheSystem() {
        // `\.colorSchemeContrast` cannot be set from a test, so what is checkable is the
        // wiring: with no override in the environment, the resolver must read the
        // system value rather than a hardcoded tier. The test process runs at standard
        // contrast, so that is the value it must land on.
        var values = EnvironmentValues()
        values.colorScheme = .dark
        #expect(values.paletteContrastOverride == nil)
        #expect(values.paletteContrast == values.colorSchemeContrast)
        #expect(components(Palette.textSecondary, values)
                == components(Palette.textSecondary, environment(.dark, values.colorSchemeContrast)))
    }

    @Test("Status marks are the artboard colours everywhere; only the text variants shift")
    func markAndTextFamiliesBehaveAsDesigned() {
        // The correction, pinned. Marks are theme-invariant AND contrast-invariant — a
        // dot is a shape, filled versus hollow carries the meaning, and moving it under
        // Increase Contrast would change what the design looks like rather than what it
        // is legible at.
        for (mark, text) in [(Palette.Status.online, Palette.Status.onlineText),
                             (Palette.Status.warning, Palette.Status.warningText),
                             (Palette.Status.info, Palette.Status.infoText)] {
            for contrast in [ColorSchemeContrast.standard, .increased] {
                #expect(components(mark, environment(.dark, contrast))
                        == components(mark, environment(.light, contrast)))
            }
            #expect(components(mark, environment(.dark, .standard))
                    == components(mark, environment(.dark, .increased)))
            #expect(components(text, environment(.dark, .standard))
                    != components(text, environment(.light, .standard)))
            // Identical on dark at standard contrast, where the vivid colour already
            // clears 7:1 and there is nothing to correct.
            #expect(components(mark, environment(.dark, .standard))
                    == components(text, environment(.dark, .standard)))
        }
    }

    @Test("A transparent token is transparent")
    func clearIsClear() {
        // `PaletteColor.clear` is what keeps the selection-fill ternaries in the token
        // type rather than forcing them back to `Color`, so it is worth one line.
        #expect(Palette.accent.opacity(0).resolve(in: environment(.dark, .standard)).opacity == 0)
        #expect(PaletteColor.clear.resolve(in: environment(.dark, .standard)).opacity == 0)
        #expect(PaletteColor.clear.resolve(in: environment(.light, .increased)).opacity == 0)
    }

    /// Prints the whole table, both contrast tiers. Not an assertion — a way to read the
    /// numbers without recomputing them by hand, which is how they drifted in the first
    /// place.
    @Test("The measured table, for the record")
    func printTable() {
        let rows: [(String, PaletteColor)] =
            Self.textTokens + [("accent", Palette.accent)] + Self.statusLabels
            + [("separator", Palette.separator), ("offlineRing", Palette.offlineRing)]
        var lines: [String] = []
        for contrast in [ColorSchemeContrast.standard, .increased] {
            for scheme in themes {
                lines.append("")
                lines.append("\(scheme) · \(contrast)")
                lines.append("  token             surface   raised    field")
                for (name, token) in rows {
                    let cells = Self.surfaces.map {
                        String(format: "%9.2f", ratio(token, on: $0.1, scheme, contrast))
                    }.joined()
                    lines.append("  " + name.padding(toLength: 16, withPad: " ", startingAt: 0) + cells)
                }
                let onAccent = ratio(Palette.onAccent, on: Palette.accent, scheme, contrast)
                lines.append("  " + "onAccent/accent".padding(toLength: 16, withPad: " ", startingAt: 0)
                             + String(format: "%9.2f", onAccent))
            }
        }
        print(lines.joined(separator: "\n"))
        #expect(!lines.isEmpty)
    }
}
