#if DEBUG
import AppKit
import SwiftUI
import Testing
@testable import Zhen
// Renders every screen to PNG when ZHEN_SNAPSHOT names a directory, and is skipped
// otherwise. Not an assertion — a way to put the pixels somewhere two runs can be
// compared, which is how "no visual change" is checked rather than claimed.
@Suite("Screen snapshots, written only when asked",
       .disabled(if: ProcessInfo.processInfo.environment["ZHEN_SNAPSHOT"] == nil))
@MainActor
struct ScreenSnapshots {
    @Test("Write every room at the declared minimum width")
    func everyRoom() {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ZHEN_SNAPSHOT"]!)
        for (room, width) in Room.allCases.flatMap({ r in
            [(r, Metrics.windowMinWidth), (r, CGFloat(700)), (r, CGFloat(1600))]
        }) {
            let host = NSHostingView(
                rootView: AnyView(FixtureWindow(room: room).environment(\.colorScheme, .dark))
            )
            host.appearance = NSAppearance(named: .darkAqua)
            host.frame = NSRect(x: 0, y: 0, width: width, height: 700)
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { continue }
            try? data.write(to: out.appendingPathComponent("\(room.title)-\(Int(width)).png"))
        }
    }
}
#endif
