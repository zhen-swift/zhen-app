// corner-artboard.swift — measure a rounded element's corner radius on an artboard.
//
// Usage: swift corner-artboard.swift <png> <x0> <y0> <x1> <y1> <fx> <fy> [tolerance]
//   x0 y0 x1 y1  a box around the element, a little larger than it (source pixels)
//   fx fy        a pixel of the colour to trace: the element's fill, or its border when the
//                fill is the same as what is behind it (the result is then the outer radius)
// Takes the bounding box of every pixel of that colour inside the box, then walks the top
// row and the left column from the bounding box's corner to where the colour is at full
// strength. For a circular corner both distances are the radius. Text or glyphs inside the
// element do not affect it. Prints pixels and points (the artboards are 2x).

import CoreGraphics
import Foundation
import ImageIO

let a = CommandLine.arguments
let n = a.dropFirst(2).compactMap { Int($0) }
guard a.count >= 8, n.count >= 6,
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil),
  let img = CGImageSourceCreateImageAtIndex(src, 0, nil), let data = img.dataProvider?.data as Data?
else { print("usage: swift corner-artboard.swift <png> <x0> <y0> <x1> <y1> <fx> <fy> [tolerance]"); exit(2) }
let (x0, y0, x1, y1, fx, fy) = (n[0], n[1], n[2], n[3], n[4], n[5])
let tol = n.count > 6 ? n[6] : 6
let first = [CGImageAlphaInfo.first, .premultipliedFirst, .noneSkipFirst].contains(img.alphaInfo)
func px(_ x: Int, _ y: Int) -> (Int, Int, Int) {
  let o = y * img.bytesPerRow + x * 4
  return first ? (Int(data[o + 1]), Int(data[o + 2]), Int(data[o + 3])) : (Int(data[o]), Int(data[o + 1]), Int(data[o + 2]))
}
let c = px(fx, fy)
func near(_ p: (Int, Int, Int)) -> Bool { abs(p.0 - c.0) + abs(p.1 - c.1) + abs(p.2 - c.2) <= tol }
var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
for y in y0...y1 { for x in x0...x1 where near(px(x, y)) {
  minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
} }
guard minX != .max else { print("no pixel of that colour in the box"); exit(1) }
var along = minX; while along < maxX, !near(px(along, minY)) { along += 1 }
var down = minY; while down < maxY, !near(px(minX, down)) { down += 1 }
print(String(format: "%02X%02X%02X  box %dx%d pt  top +%d px, left +%d px  →  radius ≈ %.1f pt",
  c.0, c.1, c.2, (maxX - minX + 1) / 2, (maxY - minY + 1) / 2, along - minX, down - minY,
  Double(max(along - minX, down - minY)) / 2))
