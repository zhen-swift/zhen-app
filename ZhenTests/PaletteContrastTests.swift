import AppKit
import SwiftUI
import Testing

@testable import Zhen

// Every colour pair the design draws text or lines with, resolved the way a view resolves
// it — `Color(resource).resolve(in:)`, the call `foregroundStyle` and `fill` make — under
// all four appearances, and held to WCAG.
//
// The values come from Docs/process/evidence/derive-palette.py. This suite does not trust
// that script: it reads the compiled catalogue back, so a colorset edited by hand fails here.
// Scripts/check-palette.py checks the same pairs from the shipped Assets.car.

/// The four appearances an asset colour resolves under.
enum Look: String, CaseIterable, CustomTestStringConvertible {
  case light, dark, lightIncreased, darkIncreased

  var environment: EnvironmentValues {
    var values = EnvironmentValues()
    values.colorScheme = (self == .dark || self == .darkIncreased) ? .dark : .light
    // Underscored but public; the only way to put a view, a preview or a test into Increase
    // Contrast without the system setting. AppKit's accessibility appearance cannot (below).
    values._colorSchemeContrast = isIncreased ? .increased : .standard
    return values
  }

  var isIncreased: Bool { self == .lightIncreased || self == .darkIncreased }
  var testDescription: String { rawValue }
}

/// Gamma-encoded sRGB components of a catalogue colour, as a view would get them.
func components(_ resource: ColorResource, _ look: Look) -> [Double] {
  let resolved = Color(resource).resolve(in: look.environment)
  return [Double(resolved.red), Double(resolved.green), Double(resolved.blue)]
}

func hex(_ c: [Double]) -> Int {
  c.reduce(0) { $0 << 8 | Int(($1 * 255).rounded()) }
}

/// WCAG 2. The same formula as ZhenCore's `Contrast`, which the app moves to once a
/// zhen-core release contains it (zhen-core#5).
func contrast(_ a: ColorResource, _ b: ColorResource, _ look: Look) -> Double {
  func luminance(_ c: [Double]) -> Double {
    let l = c.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
    return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
  }
  let x = luminance(components(a, look))
  let y = luminance(components(b, look))
  return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}

struct Pair: CustomTestStringConvertible {
  let name: String
  let foreground: ColorResource
  let backgrounds: [(String, ColorResource)]
  /// Floor at standard contrast; nil means not asserted (a hairline is faint on purpose).
  let standard: Double?
  let increased: Double
  var testDescription: String { name }
}

let textSurfaces: [(String, ColorResource)] = [
  ("surface", .surface), ("surfaceRaised", .surfaceRaised), ("surfaceField", .surfaceField),
]

let drawnPairs: [Pair] = [
  Pair(name: "textPrimary", foreground: .textPrimary,
       backgrounds: textSurfaces + [("selection", .selectionFill)], standard: 4.5, increased: 7),
  Pair(name: "textSecondary", foreground: .textSecondary,
       backgrounds: textSurfaces + [("selection", .selectionFill)], standard: 4.5, increased: 7),
  Pair(name: "textTertiary", foreground: .textTertiary,
       backgrounds: textSurfaces, standard: 4.5, increased: 7),
  Pair(name: "accent", foreground: .accent,
       backgrounds: textSurfaces + [("accentFill", .accentFill)], standard: 4.5, increased: 7),
  Pair(name: "onAccent", foreground: .onAccent,
       backgrounds: [("accent", .accent)], standard: 4.5, increased: 7),
  Pair(name: "statusOnlineText", foreground: .statusOnlineText,
       backgrounds: textSurfaces, standard: 4.5, increased: 7),
  Pair(name: "statusWarningText", foreground: .statusWarningText,
       backgrounds: textSurfaces, standard: 4.5, increased: 7),
  Pair(name: "statusInfoText", foreground: .statusInfoText,
       backgrounds: textSurfaces, standard: 4.5, increased: 7),
  Pair(name: "divider", foreground: .divider, backgrounds: textSurfaces, standard: nil, increased: 3),
  Pair(name: "cardBorder", foreground: .cardBorder, backgrounds: textSurfaces, standard: nil, increased: 3),
  Pair(name: "offlineRing", foreground: .offlineRing, backgrounds: textSurfaces, standard: nil, increased: 3),
  Pair(name: "signalWeak", foreground: .signalWeak, backgrounds: textSurfaces, standard: nil, increased: 3),
  Pair(name: "statusOnline", foreground: .statusOnline, backgrounds: textSurfaces, standard: nil, increased: 3),
  Pair(name: "statusWarning", foreground: .statusWarning, backgrounds: textSurfaces, standard: nil, increased: 3),
  Pair(name: "statusInfo", foreground: .statusInfo, backgrounds: textSurfaces, standard: nil, increased: 3),
]

@MainActor
struct PaletteContrastTests {
  @Test("Every drawn pair clears its floor in every appearance",
        arguments: drawnPairs, Look.allCases)
  func clearsItsFloor(_ pair: Pair, _ look: Look) {
    guard let floor = look.isIncreased ? pair.increased : pair.standard else { return }
    for (name, background) in pair.backgrounds {
      let measured = contrast(pair.foreground, background, look)
      #expect(measured >= floor, "\(pair.name) on \(name), \(look): \(measured)")
    }
  }

  @Test("Increase Contrast really resolves different colours", arguments: [Look.light, .dark])
  func increasedIsNotStandardTwice(_ look: Look) {
    // If the high-contrast variant were never served, every 7:1 check above would be
    // measuring the standard palette — the failure the old app's suite once had.
    let increased: Look = look == .light ? .lightIncreased : .darkIncreased
    for resource in [ColorResource.textSecondary, .textTertiary, .accent, .divider] {
      #expect(components(resource, look) != components(resource, increased))
    }
    // Pinned to the derived values, so "different" cannot mean "different and wrong".
    #expect(hex(components(.textTertiary, increased)) == (look == .dark ? 0xB8B8BB : 0x4F4F51))
  }

  @Test("The themes really differ", arguments: [ColorResource.surface, .textPrimary, .accent])
  func themesDiffer(_ resource: ColorResource) {
    #expect(components(resource, .light) != components(resource, .dark))
  }

  @Test("Surfaces, accent and primary text keep the artboards' exact values")
  func keyColoursAreTheArtboards() {
    // DESIGN-FINDINGS.md section 4, sampled from Docs/Design/01 and 02.
    #expect(hex(components(.surface, .dark)) == 0x1A1A1F)
    #expect(hex(components(.surface, .light)) == 0xFFFFFF)
    #expect(hex(components(.surfaceRaised, .dark)) == 0x212127)
    #expect(hex(components(.surfaceRaised, .light)) == 0xEEEDF3)
    #expect(hex(components(.accent, .dark)) == 0xA495E8)
    #expect(hex(components(.accent, .light)) == 0x6A58C9)
    #expect(hex(components(.textPrimary, .dark)) == 0xEBEBF0)
    #expect(hex(components(.textPrimary, .light)) == 0x1D1D1F)
  }

  @Test("AppKit's accessibility appearance is not a way into Increase Contrast")
  func appKitHighContrastCollapses() {
    // Measured on macOS 26.6.2, and why this suite resolves through SwiftUI: asking AppKit
    // for the accessibility appearance returns the plain one, and the catalogue then serves
    // the standard colour. Pinned so the next person does not rebuild the trap.
    #expect(NSAppearance(named: .accessibilityHighContrastDarkAqua)?.name == .darkAqua)
    #expect(NSAppearance(named: .accessibilityHighContrastAqua)?.name == .aqua)
  }
}
