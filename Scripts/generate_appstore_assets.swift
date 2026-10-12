#!/usr/bin/env swift
//
// generate_appstore_assets.swift — App Store and README artwork from the captures.
//
//   swift Scripts/generate_appstore_assets.swift
//
// Reads Marketing/copy.json (captions, palettes, targets) and one capture per screenshot id,
// and writes:
//
//   AppStoreAssets/<target>/<id>.png             the capture, upload-ready
//   AppStoreAssets/<target>/<id>-captioned.png   gradient, title, subtitle, framed capture
//   Docs/assets/hero.png                         2400 × 1000
//   Docs/assets/feature-NN.png                   620 px wide, one per screenshot
//   Docs/assets/app-icon.png                     from the design mark
//
// Captures are looked for in $SCREENSHOT_INPUT_DIR, then fastlane/screenshots/<target>, then
// AppStoreSimulatorCaptures/<target>. A missing capture prints every path tried and exits 1;
// an undersized one is refused — this renderer never upscales.
//
// Overrides: ZHEN_PROJECT_ROOT, SCREENSHOT_INPUT_DIR, APPSTORE_OUTPUT_DIR, DOCS_ASSET_DIR.

import AppKit
import Foundation

struct Copy: Decodable {
  struct App: Decodable { let name: String; let tagline: String }
  struct Palette: Decodable { let top: [Double]; let bottom: [Double]; let title: [Double]; let subtitle: [Double] }
  struct Target: Decodable { let name: String; let captureDir: String; let canvas: [Int]; let capture: [Int] }
  struct Screenshot: Decodable { let id: String; let title: String; let subtitle: String; let palette: String }
  struct Readme: Decodable {
    struct Hero: Decodable { let size: [Int]; let screenshot: String; let palette: String }
    let hero: Hero
    let featureWidth: Int
  }
  let app: App
  let palettes: [String: Palette]
  let targets: [Target]
  let screenshots: [Screenshot]
  let readme: Readme
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("generate_appstore_assets: \(message)\n".utf8))
  exit(1)
}

func color(_ rgb: [Double]) -> NSColor {
  NSColor(
    srgbRed: rgb[0] / 255, green: rgb[1] / 255, blue: rgb[2] / 255,
    alpha: rgb.count > 3 ? rgb[3] : 1
  )
}

let environment = ProcessInfo.processInfo.environment
let scriptRoot = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let root = environment["ZHEN_PROJECT_ROOT"].map { URL(fileURLWithPath: $0) } ?? scriptRoot
let copyURL = root.appending(path: "Marketing/copy.json")
guard let data = try? Data(contentsOf: copyURL), let copy = try? JSONDecoder().decode(Copy.self, from: data) else {
  fail("cannot read \(copyURL.path)")
}
let outputRoot = environment["APPSTORE_OUTPUT_DIR"].map { URL(fileURLWithPath: $0) } ?? root.appending(path: "AppStoreAssets")
let docsAssets = environment["DOCS_ASSET_DIR"].map { URL(fileURLWithPath: $0) } ?? root.appending(path: "Docs/assets")

/// A bitmap of exactly `width` × `height` pixels, drawn into with AppKit at 1 point per pixel.
func render(_ width: Int, _ height: Int, _ draw: (CGRect) -> Void) -> NSBitmapImageRep {
  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
  ) else { fail("cannot make a \(width) × \(height) canvas") }
  rep.size = NSSize(width: width, height: height)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  draw(CGRect(x: 0, y: 0, width: width, height: height))
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func write(_ rep: NSBitmapImageRep, to url: URL) {
  try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  guard let png = rep.representation(using: .png, properties: [:]) else { fail("cannot encode \(url.lastPathComponent)") }
  do { try png.write(to: url) } catch { fail("cannot write \(url.path): \(error)") }
  print("  \(url.path.replacingOccurrences(of: root.path + "/", with: ""))  \(rep.pixelsWide) × \(rep.pixelsHigh)")
}

/// The capture for an id: the first place it exists, or every place tried.
func capture(_ id: String, _ target: Copy.Target) -> (NSBitmapImageRep, URL) {
  var tried: [URL] = []
  if let input = environment["SCREENSHOT_INPUT_DIR"] { tried.append(URL(fileURLWithPath: input).appending(path: "\(id).png")) }
  tried.append(root.appending(path: "fastlane/screenshots/\(target.captureDir)/\(id).png"))
  tried.append(root.appending(path: "AppStoreSimulatorCaptures/\(target.captureDir)/\(id).png"))
  for url in tried {
    if let image = NSImage(contentsOf: url), let rep = image.representations.first as? NSBitmapImageRep {
      guard rep.pixelsWide >= target.capture[0], rep.pixelsHigh >= target.capture[1] else {
        fail("\(url.path) is \(rep.pixelsWide) × \(rep.pixelsHigh), under \(target.capture[0]) × \(target.capture[1]) — capture on a Retina display; this renderer never upscales")
      }
      return (rep, url)
    }
  }
  fail("no capture for \(id). Tried:\n" + tried.map { "    \($0.path)" }.joined(separator: "\n"))
}

/// The vertical gradient every captioned image stands on.
func background(_ palette: Copy.Palette, in rect: CGRect) {
  NSGradient(starting: color(palette.top), ending: color(palette.bottom))?.draw(in: rect, angle: -90)
}

/// Title and subtitle, centred in `rect`, top-aligned. Returns the height used.
@discardableResult
func caption(_ title: String, _ subtitle: String, _ palette: Copy.Palette, in rect: CGRect, scale: CGFloat, alignment: NSTextAlignment = .center) -> CGFloat {
  let style = NSMutableParagraphStyle()
  style.alignment = alignment
  let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 96 * scale, weight: .black),
    .foregroundColor: color(palette.title), .paragraphStyle: style,
  ]
  let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 44 * scale, weight: .semibold),
    .foregroundColor: color(palette.subtitle), .paragraphStyle: style,
  ]
  let titleText = NSAttributedString(string: title, attributes: titleAttributes)
  let subtitleText = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
  let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
  let titleHeight = ceil(titleText.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: options).height)
  let subtitleHeight = ceil(subtitleText.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: options).height)
  let gap = 24 * scale
  titleText.draw(with: CGRect(x: rect.minX, y: rect.maxY - titleHeight, width: rect.width, height: titleHeight), options: options)
  subtitleText.draw(with: CGRect(x: rect.minX, y: rect.maxY - titleHeight - gap - subtitleHeight, width: rect.width, height: subtitleHeight), options: options)
  return titleHeight + gap + subtitleHeight
}

/// The capture, clipped to a rounded rect with a drop shadow and a 0.18-alpha white hairline.
func framed(_ shot: NSBitmapImageRep, in rect: CGRect, scale: CGFloat) {
  let radius = 28 * scale
  let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
  shadow.shadowBlurRadius = 60 * scale
  shadow.shadowOffset = NSSize(width: 0, height: -20 * scale)
  shadow.set()
  NSColor.black.setFill()
  path.fill()
  NSGraphicsContext.restoreGraphicsState()
  NSGraphicsContext.saveGraphicsState()
  path.addClip()
  shot.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high.rawValue])
  NSGraphicsContext.restoreGraphicsState()
  NSColor.white.withAlphaComponent(0.18).setStroke()
  path.lineWidth = max(1, 2 * scale)
  path.stroke()
}

/// The largest rect of `aspect` that fits inside `bounds`, centred horizontally, at its bottom.
func fit(aspect: CGFloat, in bounds: CGRect) -> CGRect {
  var width = bounds.width
  var height = width / aspect
  if height > bounds.height {
    height = bounds.height
    width = height * aspect
  }
  return CGRect(x: bounds.midX - width / 2, y: bounds.minY, width: width, height: height)
}

print("generate_appstore_assets: \(copy.screenshots.count) screenshots, \(copy.targets.count) target(s)")
var captioned: [String: NSBitmapImageRep] = [:]
var captures: [String: NSBitmapImageRep] = [:]
for target in copy.targets {
  let width = target.canvas[0], height = target.canvas[1]
  let scale = CGFloat(height) / 1800
  for shot in copy.screenshots {
    guard let palette = copy.palettes[shot.palette] else { fail("\(shot.id) names palette \(shot.palette), which copy.json does not define") }
    let (image, _) = capture(shot.id, target)
    captures[shot.id] = image
    // Plain: the capture itself, already at the upload size.
    write(render(width, height) { rect in
      image.draw(in: rect, from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
    }, to: outputRoot.appending(path: "\(target.name)/\(shot.id).png"))
    // Captioned: caption on top, the capture framed and sized to the height left.
    let rep = render(width, height) { rect in
      background(palette, in: rect)
      let margin = 120 * scale
      let used = caption(shot.title, shot.subtitle, palette, in: rect.insetBy(dx: margin * 2, dy: 0).offsetBy(dx: 0, dy: -margin), scale: scale)
      let available = CGRect(x: margin, y: 0, width: rect.width - margin * 2, height: rect.height - margin - used - margin * 0.75)
      let aspect = CGFloat(image.pixelsWide) / CGFloat(image.pixelsHigh)
      var frame = fit(aspect: aspect, in: available)
      frame.origin.y = -frame.height * 0.06
      framed(image, in: frame, scale: scale)
    }
    captioned[shot.id] = rep
    write(rep, to: outputRoot.appending(path: "\(target.name)/\(shot.id)-captioned.png"))
  }
}

// README artwork.
let hero = copy.readme.hero
guard let heroShot = captures[hero.screenshot], let heroPalette = copy.palettes[hero.palette] else {
  fail("the README hero names \(hero.screenshot) / \(hero.palette), which are not both defined")
}
write(render(hero.size[0], hero.size[1]) { rect in
  background(heroPalette, in: rect)
  let scale = rect.height / 1800 * 1.6
  let textWidth = rect.width * 0.36
  caption(copy.app.name, copy.app.tagline, heroPalette, in: CGRect(x: 100, y: 0, width: textWidth, height: rect.height - 300), scale: scale, alignment: .left)
  let aspect = CGFloat(heroShot.pixelsWide) / CGFloat(heroShot.pixelsHigh)
  let area = CGRect(x: textWidth + 180, y: 80, width: rect.width - textWidth - 260, height: rect.height - 160)
  var frame = fit(aspect: aspect, in: area)
  frame.origin.y = rect.midY - frame.height / 2
  framed(heroShot, in: frame, scale: scale * 0.6)
}, to: docsAssets.appending(path: "hero.png"))

for (index, shot) in copy.screenshots.enumerated() {
  guard let source = captioned[shot.id] else { continue }
  let width = copy.readme.featureWidth
  let height = Int((Double(width) * Double(source.pixelsHigh) / Double(source.pixelsWide)).rounded())
  write(render(width, height) { rect in
    source.draw(in: rect, from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high.rawValue])
  }, to: docsAssets.appending(path: String(format: "feature-%02d.png", index + 1)))
}

let iconURL = root.appending(path: "Design/marks/03-z/png/icon-colour-1024.png")
guard let icon = NSImage(contentsOf: iconURL)?.representations.first as? NSBitmapImageRep else { fail("no design mark at \(iconURL.path)") }
write(render(512, 512) { rect in
  icon.draw(in: rect, from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high.rawValue])
}, to: docsAssets.appending(path: "app-icon.png"))
print("generate_appstore_assets: done")
