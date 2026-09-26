// HelperIdentityTests.swift — the names three files have to agree on.
//
// The daemon's label appears in `HelperIdentity`, in the plist `Scripts/build-app.sh`
// generates, as that plist's filename, and as the Mach service the listener binds. A
// disagreement between any two of them fails as `SMAppService` error 108, "unable to
// read plist" — which names the wrong thing, reads as malformed XML, and sends whoever
// hits it to inspect a file that is perfectly well formed.
//
// So the agreement is checked here rather than discovered there.

import Foundation
import Testing
import ZhenPrivilege
@testable import Zhen

@Suite("The helper's name, in every place it is written")
struct HelperIdentityTests {
    static let repositoryRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // ZhenAppTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // zhen-app
        .deletingLastPathComponent()   // Packages
        .deletingLastPathComponent()   // the repository

    static func buildScript() throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent("Scripts/build-app.sh"),
            encoding: .utf8
        )
    }

    @Test("The build script writes the label the code connects to")
    func labelAgrees() throws {
        let script = try Self.buildScript()
        #expect(script.contains("HELPER_LABEL=\"\(HelperIdentity.label)\""))
        #expect(script.contains("APP_BUNDLE_ID=\"\(HelperIdentity.applicationBundleIdentifier)\""))
    }

    @Test("The plist lands where SMAppService looks for it")
    func plistPathAgrees() throws {
        // `SMAppService.daemon(plistName:)` looks in Contents/Library/LaunchDaemons and
        // nowhere else, and takes a filename rather than a path.
        #expect(HelperIdentity.plistBundlePath
                == "Contents/Library/LaunchDaemons/\(HelperIdentity.plistName)")
        #expect(HelperIdentity.plistName == "\(HelperIdentity.label).plist")
        let script = try Self.buildScript()
        #expect(script.contains("Contents/Library/LaunchDaemons/$HELPER_LABEL.plist"))
    }

    @Test("The team the build checks is the team the code requires")
    func teamAgrees() throws {
        let script = try Self.buildScript()
        #expect(script.contains("EXPECTED_TEAM=\"\(CodeRequirement.teamIdentifier)\""))
        // Both directions of the mutual check name that team. Handing a capture
        // descriptor to an unverified process is handing it promiscuous capture, since
        // Darwin has no BIOCLOCK to freeze the filter first.
        #expect(CodeRequirement.client.contains(CodeRequirement.teamIdentifier))
        #expect(CodeRequirement.helper.contains(CodeRequirement.teamIdentifier))
        #expect(CodeRequirement.client.contains(HelperIdentity.applicationBundleIdentifier))
        #expect(CodeRequirement.helper.contains(HelperIdentity.label))
    }

    @Test("The daemon plist associates itself with the app, which is what names it")
    func associatedBundleIdentifiers() throws {
        // The non-negotiable. Without this key Login Items lists the bare label, and a
        // person who just installed a background root process sees a reverse-DNS string
        // they have to search for before they can decide whether to trust it.
        let script = try Self.buildScript()
        #expect(script.contains("AssociatedBundleIdentifiers"))
        #expect(script.contains("<string>$APP_BUNDLE_ID</string>"))
    }

    @Test("A BPF program survives the crossing to the helper unchanged")
    func filterRoundTrip() {
        // The one piece of the protocol that is not a string. A filter that decoded
        // short would install a PREFIX of the program asked for, which passes traffic
        // the caller meant to exclude and does it silently.
        let program = [
            BPFInstruction(code: 0x28, jt: 0, jf: 0, k: 12),
            BPFInstruction(code: 0x15, jt: 0, jf: 1, k: 0x0806),
            BPFInstruction(code: 0x06, jt: 0, jf: 0, k: 0xFFFF_FFFF),
        ]
        let decoded = BPFFilterCoding.decode(BPFFilterCoding.encode(program))
        #expect(decoded == program)

        // A length that is not a whole number of instructions is refused rather than
        // truncated.
        #expect(BPFFilterCoding.decode(Data([1, 2, 3])) == nil)
        #expect(BPFFilterCoding.decode(Data()) == nil)
    }
}
