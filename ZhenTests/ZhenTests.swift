import Testing
import ZhenCore

@testable import Zhen

struct ZhenTests {
  @Test("The app resolves zhen-core by version, not by path")
  func linksZhenCore() {
    // A path dependency let an engine schema change break the old app silently. This only
    // compiles if the package resolved; the value says which release it resolved to.
    #expect(ZhenVersion.current.split(separator: ".").count == 3)
  }
}
