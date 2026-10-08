import AppKit
import SwiftUI
import Testing

@testable import Zhen

// Every colour pair the design draws text or lines with, resolved the way AppKit resolves
// the asset catalogue, and held to WCAG.
//
// The values come from Docs/process/evidence/derive-palette.py. This suite does not trust
// that script: it reads the compiled catalogue back, so a colorset edited by hand fails here.
//
// Light and dark only. A test process cannot build an Increase Contrast appearance:
// `NSAppearance(named: .accessibilityHighContrastDarkAqua)` returns plain `darkAqua`
// (pinned below), so the high-contrast variants are checked from the compiled catalogue by
// `Scripts/check-palette.py`, which reads it with `assetutil`.

/// The appearances a test process can resolve an asset colour under.
enum Look: String, CaseIterable, CustomTestStringConvertible {
  case light, dark

  var appearance: NSAppearance {
    guard let appearance = NSAppearance(named: self == .light ? .aqua : .darkAqua) else {
      fatalError("AppKit has no \(rawValue) appearance")
    }
    return appearance
  }

  var testDescription: String { rawValue }
}

/// Gamma-encoded sRGB components of a catalogue colour under one appearance.
func components(_ resource: ColorResource, _ look: Look) -> (Double, Double, Double) {
  var result = (0.0, 0.0, 0.0)
  look.appearance.performAsCurrentDrawingAppearance {
    let colour = NSColor(resource: resource).usingColorSpace(.sRGB) ?? .clear
    result = (colour.redComponent, colour.greenComponent, colour.blueComponent)
  }
  return result
}

/// WCAG 2. The same formula as ZhenCore's `Contrast`, which the app moves to once a
/// zhen-core release contains it (zhen-core#5).
func contrast(_ a: ColorResource, _ b: ColorResource, _ look: Look) -> Double {
  func luminance(_ c: (Double, Double, Double)) -> Double {
    func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(c.0) + 0.7152 * linear(c.1) + 0.0722 * linear(c.2)
  }
  let x = luminance(components(a, look))
  let y = luminance(components(b, look))
  return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}

struct Pair: CustomTestStringConvertible {
  let name: String
  let foreground: ColorResource
  let backgrounds: [(String, ColorResource)]
  /// Floor at standard contrast; nil means not asserted here (a hairline is faint on
  /// purpose). The Increase Contrast floors are `Scripts/check-palette.py`'s.
  let standard: Double?
  var testDescription: String { name }
}

let textSurfaces: [(String, ColorResource)] = [
  ("surface", .surface), ("surfaceRaised", .surfaceRaised), ("surfaceField", .surfaceField),
]

let drawnPairs: [Pair] = [
  Pair(name: "textPrimary", foreground: .textPrimary,
       backgrounds: textSurfaces + [("selection", .selectionFill)], standard: 4.5),
  Pair(name: "textSecondary", foreground: .textSecondary,
       backgrounds: textSurfaces + [("selection", .selectionFill)], standard: 4.5),
  Pair(name: "textTertiary", foreground: .textTertiary,
       backgrounds: textSurfaces, standard: 4.5),
  Pair(name: "accent", foreground: .accent,
       backgrounds: textSurfaces + [("accentFill", .accentFill)], standard: 4.5),
  Pair(name: "onAccent", foreground: .onAccent,
       backgrounds: [("accent", .accent)], standard: 4.5),
  Pair(name: "statusOnlineText", foreground: .statusOnlineText,
       backgrounds: textSurfaces, standard: 4.5),
  Pair(name: "statusWarningText", foreground: .statusWarningText,
       backgrounds: textSurfaces, standard: 4.5),
  Pair(name: "statusInfoText", foreground: .statusInfoText,
       backgrounds: textSurfaces, standard: 4.5),
  Pair(name: "divider", foreground: .divider, backgrounds: textSurfaces, standard: nil),
  Pair(name: "cardBorder", foreground: .cardBorder, backgrounds: textSurfaces, standard: nil),
  Pair(name: "offlineRing", foreground: .offlineRing, backgrounds: textSurfaces, standard: nil),
  Pair(name: "signalWeak", foreground: .signalWeak, backgrounds: textSurfaces, standard: nil),
  Pair(name: "statusOnline", foreground: .statusOnline, backgrounds: textSurfaces, standard: nil),
  Pair(name: "statusWarning", foreground: .statusWarning, backgrounds: textSurfaces, standard: nil),
  Pair(name: "statusInfo", foreground: .statusInfo, backgrounds: textSurfaces, standard: nil),
]

@MainActor
struct PaletteContrastTests {
  @Test("Every drawn pair clears its floor in every appearance",
        arguments: drawnPairs, Look.allCases)
  func clearsItsFloor(_ pair: Pair, _ look: Look) {
    guard let floor = pair.standard else { return }
    for (name, background) in pair.backgrounds {
      let measured = contrast(pair.foreground, background, look)
      #expect(measured >= floor, "\(pair.name) on \(name), \(look): \(measured)")
    }
  }

  @Test("AppKit still cannot build an Increase Contrast appearance in-process")
  func highContrastAppearanceCollapses() {
    // Why the 7:1 checks live in check-palette.py. Measured on macOS 26.6.2: asking for the
    // accessibility appearance returns the plain one, and the catalogue then serves the
    // standard colour. If this ever fails, AppKit changed and the increased tier can move
    // back into this suite.
    #expect(NSAppearance(named: .accessibilityHighContrastDarkAqua)?.name == .darkAqua)
    #expect(NSAppearance(named: .accessibilityHighContrastAqua)?.name == .aqua)
  }

  @Test("The themes really differ", arguments: [ColorResource.surface, .textPrimary, .accent])
  func themesDiffer(_ resource: ColorResource) {
    let light = components(resource, .light)
    let dark = components(resource, .dark)
    #expect(light != dark)
  }

  @Test("Surfaces keep the artboards' exact values")
  func surfacesAreTheArtboards() {
    // DESIGN-FINDINGS.md section 4, sampled from Docs/Design/01 and 02.
    func hex(_ c: (Double, Double, Double)) -> Int {
      Int((c.0 * 255).rounded()) << 16 | Int((c.1 * 255).rounded()) << 8 | Int((c.2 * 255).rounded())
    }
    #expect(hex(components(.surface, .dark)) == 0x1A1A1F)
    #expect(hex(components(.surface, .light)) == 0xFFFFFF)
    #expect(hex(components(.surfaceRaised, .dark)) == 0x212127)
    #expect(hex(components(.accent, .dark)) == 0xA495E8)
    #expect(hex(components(.accent, .light)) == 0x6A58C9)
    #expect(hex(components(.textPrimary, .dark)) == 0xEBEBF0)
  }
}
