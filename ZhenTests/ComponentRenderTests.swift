import AppKit
import SwiftUI
import Testing

@testable import Zhen

// Renders every component under the four appearances, so a person can look at them, and
// checks that the render really is in the appearance asked for: a dot's centre pixel must
// be the catalogue colour for that look. Sheets are written to the test host's temporary
// directory (in its sandbox container) and named per look.

/// Every component, once, on the surfaces the artboards put them on.
private struct ComponentSheet: View {
  var body: some View {
    VStack(alignment: .leading, spacing: .spacing.large) {
      Text("Zhen").sectionLabel()
      HStack(spacing: .spacing.large) {
        ForEach(StatusDot.Tone.allCases, id: \.self) { StatusDot($0) }
      }
      HStack(spacing: .spacing.small) {
        Text("GW1000").foregroundStyle(.textPrimary)
        Chip("Gateway", style: .accent)
        Text("2A:5C:00:00:00:01").font(.callout.monospaced()).foregroundStyle(.textTertiary)
        Chip("private")
      }
      HStack(spacing: .spacing.large) {
        SignalMeter(lit: 3)
        SignalMeter(lit: 2)
        SignalMeter(lit: 1, tint: .textTertiary)
        SignalMeter(lit: 3, of: 4, tint: .statusOnline)
      }
      VStack(alignment: .leading, spacing: .spacing.xSmall) {
        Text("Mac Studio de Luis").font(.body).foregroundStyle(.textPrimary)
        Text("Mac Studio · Mac16,9 · Apple").font(.subheadline).foregroundStyle(.textSecondary)
        Text("Randomized MAC · no vendor").font(.subheadline).foregroundStyle(.textTertiary)
        Text(12_345, format: .number).numericValue().foregroundStyle(.textPrimary)
      }
      Button("Open System Settings…") {}.buttonStyle(.press).foregroundStyle(.accent)
    }
    .padding(.spacing.xLarge)
    .background(.surface)
  }
}

@MainActor
private func render<V: View>(_ view: V, _ look: Look) -> NSBitmapImageRep? {
  let env = look.environment
  let renderer = ImageRenderer(
    content: view
      .environment(\.colorScheme, env.colorScheme)
      .environment(\._colorSchemeContrast, env._colorSchemeContrast)
  )
  renderer.scale = 2
  return renderer.cgImage.map(NSBitmapImageRep.init(cgImage:))
}

@MainActor
struct ComponentRenderTests {
  @Test("Each look renders, and is really that look", arguments: Look.allCases)
  func rendersInTheLookAskedFor(_ look: Look) throws {
    let dot = try #require(render(StatusDot(.online).frame(width: .iconSize.xLarge, height: .iconSize.xLarge), look))
    // The render is tagged sRGB; `colorAt` reports its components as "calibrated RGB",
    // and converting those to sRGB shifts values that are already right (measured: a
    // correct 4CD268 came back 58D77B). So assert the tag and compare the raw components.
    #expect(dot.cgImage?.colorSpace?.name == CGColorSpace.sRGB)
    let centre = try #require(dot.colorAt(x: dot.pixelsWide / 2, y: dot.pixelsHigh / 2))
    let expected = Color(.statusOnline).resolve(in: look.environment)
    #expect(abs(centre.redComponent - Double(expected.red)) < 0.02)
    #expect(abs(centre.greenComponent - Double(expected.green)) < 0.02)
    #expect(abs(centre.blueComponent - Double(expected.blue)) < 0.02)

    let sheet = try #require(render(ComponentSheet(), look))
    let png = try #require(sheet.representation(using: .png, properties: [:]))
    let url = FileManager.default.temporaryDirectory.appending(path: "components-\(look.rawValue).png")
    try png.write(to: url)
    print("rendered \(url.path(percentEncoded: false))")
  }
}

/// Phase 3, stage 3: with Differentiate Without Colour on, no two tones share a shape.
@MainActor
struct StatusDotShapeTests {
  /// Gate. Break: give `.warning` the same symbol as `.online`.
  @Test("Every tone has its own shape without colour")
  func distinctShapes() {
    let shapes = StatusDot.Tone.allCases.map { $0.symbol ?? "ring" }
    #expect(Set(shapes).count == StatusDot.Tone.allCases.count, "\(shapes)")
  }
}
