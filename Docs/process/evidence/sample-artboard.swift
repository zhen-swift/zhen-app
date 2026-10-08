// sample-artboard.swift — read colours out of an artboard PNG, uncorrected.
//
// Usage: swift sample-artboard.swift <png> <spec-file>
//
// Each spec line: `name x0 y0 x1 y1 mode`, in the PNG's own pixels (inclusive box).
//   fill     the most common colour in the box: a flat surface, a chip, a dot's centre
//   ink      the pixel furthest from the box's most common colour: text or a glyph,
//            whose anti-aliased edges would drag an average toward the background
// Lines starting with # are skipped.
//
// The artboards carry no colour profile (`sips -g profile` → nil), so the bytes are read
// as written, with no colour management, and reported as sRGB hex — the space A1 used.

import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count == 3,
  let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
  let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
  let data = image.dataProvider?.data as Data?
else {
  print("usage: swift sample-artboard.swift <png> <spec-file>")
  exit(2)
}
guard image.bitsPerComponent == 8, image.bitsPerPixel == 32 else {
  print("unsupported layout: \(image.bitsPerComponent) bpc, \(image.bitsPerPixel) bpp")
  exit(2)
}
let alphaFirst = [CGImageAlphaInfo.first, .premultipliedFirst, .noneSkipFirst]
  .contains(CGImageAlphaInfo(rawValue: image.alphaInfo.rawValue))
let bytesPerRow = image.bytesPerRow

func pixel(_ x: Int, _ y: Int) -> UInt32 {
  let o = y * bytesPerRow + x * 4
  let (r, g, b) = alphaFirst
    ? (data[o + 1], data[o + 2], data[o + 3])
    : (data[o], data[o + 1], data[o + 2])
  return UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b)
}

func distance(_ a: UInt32, _ b: UInt32) -> Int {
  let d = [16, 8, 0].map { abs(Int((a >> $0) & 0xFF) - Int((b >> $0) & 0xFF)) }
  return d.reduce(0, +)
}

let spec = try String(contentsOfFile: args[2], encoding: .utf8)
for line in spec.split(separator: "\n") where !line.hasPrefix("#") {
  let f = line.split(separator: " ").map(String.init)
  guard f.count == 6, let x0 = Int(f[1]), let y0 = Int(f[2]), let x1 = Int(f[3]),
    let y1 = Int(f[4])
  else { continue }
  var counts: [UInt32: Int] = [:]
  for y in y0...y1 { for x in x0...x1 { counts[pixel(x, y), default: 0] += 1 } }
  let total = counts.values.reduce(0, +)
  guard let common = counts.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) })
  else { continue }
  switch f[5] {
  case "fill":
    let share = Double(common.value) / Double(total) * 100
    print("\(f[0]) \(String(format: "%06X", common.key)) fill \(Int(share.rounded()))%")
  case "ink":
    let ink = counts.keys.max { distance($0, common.key) < distance($1, common.key) } ?? common.key
    print("\(f[0]) \(String(format: "%06X", ink)) ink on \(String(format: "%06X", common.key))")
  default:
    print("\(f[0]) unknown mode \(f[5])")
  }
}
