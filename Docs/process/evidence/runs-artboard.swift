// runs-artboard.swift — colour runs along one line of an artboard, for measuring distances.
//
// Usage: swift runs-artboard.swift <png> h|v <fixed> <from> <to> [tolerance]
//   h: walk x from..to at y = fixed;  v: walk y from..to at x = fixed. Source pixels.
// Prints each run of near-identical colour as `start length colour`, in pixels and in
// points (the artboards are 2x: 2364 px is a 1182 pt window).

import CoreGraphics
import Foundation
import ImageIO

let a = CommandLine.arguments
guard a.count >= 6, let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil),
  let img = CGImageSourceCreateImageAtIndex(src, 0, nil), let data = img.dataProvider?.data as Data?,
  let fixed = Int(a[3]), let from = Int(a[4]), let to = Int(a[5])
else { print("usage: swift runs-artboard.swift <png> h|v <fixed> <from> <to> [tolerance]"); exit(2) }
let tol = a.count > 6 ? Int(a[6]) ?? 6 : 6
let first = [CGImageAlphaInfo.first, .premultipliedFirst, .noneSkipFirst].contains(img.alphaInfo)
func px(_ x: Int, _ y: Int) -> (Int, Int, Int) {
  let o = y * img.bytesPerRow + x * 4
  return first ? (Int(data[o + 1]), Int(data[o + 2]), Int(data[o + 3])) : (Int(data[o]), Int(data[o + 1]), Int(data[o + 2]))
}
var start = from
var current = a[2] == "h" ? px(from, fixed) : px(fixed, from)
func emit(_ end: Int) {
  let len = end - start
  print(String(format: "%5d px (%7.1f pt)  len %4d px (%6.1f pt)  %02X%02X%02X", start, Double(start) / 2, len, Double(len) / 2, current.0, current.1, current.2))
}
for i in from...to {
  let c = a[2] == "h" ? px(i, fixed) : px(fixed, i)
  if abs(c.0 - current.0) + abs(c.1 - current.1) + abs(c.2 - current.2) > tol {
    emit(i); start = i; current = c
  }
}
emit(to + 1)
