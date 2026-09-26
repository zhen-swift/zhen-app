import AppKit
import Testing
@testable import Zhen
// Symbol names, checked against the system that has to draw them.
//
// A1's SF Symbols section says to open SF Symbols.app and confirm the deployment target
// supports each name. That is a manual step, it is done once, and it goes stale — and the
// failure mode is the quietest one in the toolkit: `Image(systemName:)` with a name macOS
// does not know renders NOTHING. No crash, no warning, no missing-asset placeholder. A
// blank space where the icon was, which reads as a layout bug and gets chased somewhere
// else entirely.

@Suite("Every symbol name is one the system actually has")
@MainActor
struct SymbolTests {
    @Test("Every name in Symbols.all resolves at the deployment target")
    func namesResolve() {
        for name in Symbols.all {
            #expect(
                NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
                "SF Symbol '\(name)' does not exist on this system"
            )
        }
    }

    @Test("Symbols.all lists every symbol the type declares")
    func listIsComplete() throws {
        // Source-level, because Swift cannot reflect over static properties. Without
        // this, `all` drifts the moment somebody adds a symbol and forgets it — and a
        // symbol missing from `all` is a symbol the test above never sees, which is
        // exactly the gap this suite exists to close.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // Design
            .deletingLastPathComponent()      // ZhenTests
            .deletingLastPathComponent()      // zhen-app
            .appendingPathComponent("Zhen/Design/Tokens/Symbols.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        let declared = text
            .split(separator: "\n")
            .filter { $0.contains("public static let ") && $0.contains("\"") }
            .count
        #expect(
            declared == Symbols.all.count,
            "Symbols.swift declares \(declared) symbol names but Symbols.all lists \(Symbols.all.count)"
        )
    }

    @Test("No symbol name is listed twice")
    func namesAreDistinct() {
        // Two roles may legitimately share a glyph — `offline` and `queued` are both
        // `circle`, and `noMatches` reuses `magnifyingglass` — so this checks the
        // ROLES resolve, not that the strings are unique. What it catches is a
        // copy-paste in `all` itself, where the same constant got listed twice and
        // another was dropped, leaving the count right and the coverage wrong.
        let expectedDuplicates = Set(["circle", "magnifyingglass"])
        var seen: Set<String> = []
        for name in Symbols.all where !expectedDuplicates.contains(name) {
            #expect(seen.insert(name).inserted, "'\(name)' appears twice in Symbols.all")
        }
    }
}
