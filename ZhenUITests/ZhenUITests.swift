import XCTest

final class ZhenUITests: XCTestCase {
  /// Launches on the fixture network. Never without `-UITesting`: a bare launch opens the
  /// history file the command line shares, and a test must never see real data.
  @MainActor
  func testLaunches() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
  }
}
