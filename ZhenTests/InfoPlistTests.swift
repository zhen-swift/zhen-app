import Foundation
import Testing
import ZhenCore

@testable import Zhen

/// Gate: the project tells the truth. Read from the BUILT app — the test host is Zhen.app —
/// because a build setting nobody reads back is an intention, not a fact.
struct InfoPlistTests {
  @Test("NSBonjourServices is exactly what zhen-core browses, in order")
  func bonjourServicesMatchTheVocabulary() throws {
    let declared = try #require(Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices") as? [String])
    // A type browsed but not declared returns nothing, silently. If this fails after a
    // zhen-core upgrade, run Scripts/generate-bonjour-services.sh.
    #expect(declared == BonjourVocabulary.browsedTypes)
  }

  @Test("The Local Network prompt says what and why, in words")
  func localNetworkUsageIsDescribed() throws {
    let text = try #require(Bundle.main.object(forInfoDictionaryKey: "NSLocalNetworkUsageDescription") as? String)
    #expect(text.count > 40)
    #expect(text.localizedStandardContains("network"))
  }

  @Test("The app runs unsandboxed: raw sockets and BPF have no sandbox entitlement")
  func appIsNotSandboxed() {
    // Set by the system for every sandboxed process, and only for one.
    #expect(ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil)
  }
}
