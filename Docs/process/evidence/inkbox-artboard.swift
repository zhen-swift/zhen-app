// inkbox-artboard.swift — the bounding box of ink (text, glyphs) inside a box on an artboard.
//
// Usage: swift inkbox-artboard.swift <png> <x0> <y0> <x1> <y1> [threshold]
// Ink is any pixel further than `threshold` (sum of channel differences, default 120) from
// the box's most common colour. For a word in capitals with no descender, the height is the
// cap height; SF's cap height is about 0.70 of the point size. Prints points (2x artboards).

import CoreGraphics
import Foundation
import ImageIO

let a = CommandLine.arguments
let n = a.dropFirst(2).compactMap { Int($0) }
guard n.count >= 4, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil),
  let img = CGImageSourceCreateImageAtIndex(src, 0, nil), let data = img.dataProvider?.data as Data?
else { print("usage: swift inkbox-artboard.swift <png> <x0> <y0> <x1> <y1> [threshold]"); exit(2) }
let threshold = n.count > 4 ? n[4] : 120
let first = [CGImageAlphaInfo.first, .premultipliedFirst, .noneSkipFirst].contains(img.alphaInfo)
func px(_ x: Int, _ y: Int) -> Int {
  let o = y * img.bytesPerRow + x * 4
  return first ? Int(data[o + 1]) << 16 | Int(data[o + 2]) << 8 | Int(data[o + 3])
    : Int(data[o]) << 16 | Int(data[o + 1]) << 8 | Int(data[o + 2])
}
func dist(_ p: Int, _ q: Int) -> Int { [16, 8, 0].map { abs((p >> $0 & 255) - (q >> $0 & 255)) }.reduce(0, +) }
var counts: [Int: Int] = [:]
for y in n[1]...n[3] { for x in n[0]...n[2] { counts[px(x, y), default: 0] += 1 } }
let bg = counts.max { $0.value < $1.value }!.key
var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
for y in n[1]...n[3] { for x in n[0]...n[2] where dist(px(x, y), bg) > threshold {
  minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
} }
guard minX != .max else { print("no ink"); exit(1) }
let h = Double(maxY - minY + 1) / 2
print(String(format: "ink %.1f x %.1f pt  →  if capitals: ≈ %.1f pt type", Double(maxX - minX + 1) / 2, h, h / 0.70))
