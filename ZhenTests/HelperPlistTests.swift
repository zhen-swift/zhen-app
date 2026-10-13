import Foundation
import Testing
import ZhenPrivilege

@testable import Zhen

/// Gate: ship the check, not the intention. Nothing validates the daemon plist at build
/// time — registration succeeds with it wrong, and the item then shows in Login Items as a
/// bare reverse-DNS string. So this reads the BUILT app's copy (the test host is Zhen.app)
/// and pins it to the identities zhen-core declares.
struct HelperPlistTests {
  let plist: [String: Any]

  init() throws {
    let url = Bundle.main.bundleURL.appending(path: HelperIdentity.plistBundlePath)
    let data = try Data(contentsOf: url)
    plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
  }

  @Test("It is where SMAppService.daemon(plistName:) looks")
  func location() {
    let url = Bundle.main.bundleURL.appending(path: "Contents/Library/LaunchDaemons/\(HelperIdentity.plistName)")
    #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
  }

  @Test("AssociatedBundleIdentifiers names this app, so Login Items shows Zhen and its icon")
  func associatedBundle() {
    let associated = plist["AssociatedBundleIdentifiers"] as? [String]
    #expect(associated == [HelperIdentity.applicationBundleIdentifier])
    #expect(associated == [Bundle.main.bundleIdentifier].compactMap(\.self))
  }

  @Test("The label and the Mach service are core's helper label")
  func label() {
    #expect(plist["Label"] as? String == HelperIdentity.label)
    let services = plist["MachServices"] as? [String: Bool]
    #expect(services == [HelperIdentity.label: true])
  }

  @Test("The program path is the helper's place in the bundle")
  func programPath() {
    #expect(plist["BundleProgram"] as? String == "Contents/MacOS/zhen-helper")
  }

  /// Gate — phase 2's defect E1. Break: remove the Embed Helper phase (or the target's
  /// dependency on the `zhen-helper` product). An Xcode-built app then registers a daemon
  /// whose program launchd cannot find, and only `Scripts/release.sh` could fix it.
  @Test("An Xcode build embeds the helper where the daemon plist says it is")
  func helperIsEmbedded() throws {
    let program = try #require(plist["BundleProgram"] as? String)
    let url = Bundle.main.bundleURL.appending(path: program)
    #expect(FileManager.default.isExecutableFile(atPath: url.path(percentEncoded: false)),
            "no helper at \(program): launchd would find no program")
  }
}
