import XCTest

/// Gate: a degradation banner never takes the window with it.
///
/// The banner's explanation once had `fixedSize(vertical:)`. It sits in a safe-area inset,
/// outside any scroll view, so its height is part of the column's minimum; measured at
/// zero width that paragraph was thousands of points tall, and the window centred its
/// content off screen — sidebar, table and live scan all gone, only the toolbar left. The
/// existing tests asked whether the banner *existed*, which it did, off screen. These ask
/// whether everything a person needs is still *inside the window*.
final class DegradationLayoutUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Show Details on Devices' partial-run notice, at the default size and the minimum.
  @MainActor
  func testShowDetailsKeepsTheWindow() {
    let robot = ZhenRobot.launch(fixture: "partial")
    robot.waitFor("deviceTable")
    robot.element("partialRunDisclosure").clickCentre()
    robot.waitFor("degradationBanner")
    assertInside(robot, ["sidebar", "scanStatus", "partialRunNotice", "degradationBanner", "deviceTable", "scanNowButton"], at: "default, Show Details")
    robot.capture("degradation-devices-default", in: self)

    robot.shrinkToMinimum()
    assertInside(robot, ["sidebar", "scanStatus", "partialRunNotice", "degradationBanner", "scanNowButton"], at: "minimum, Show Details")
    robot.capture("degradation-devices-minimum", in: self)
  }

  /// Scan Now on a network that degrades mid-scan: the live scan stays on screen with the
  /// banner under the stage cards. This is the path the bug was reported on.
  @MainActor
  func testLiveScanDegradationKeepsTheWindow() {
    let robot = ZhenRobot.launch(fixture: "partial", scanPace: 1_200)
    robot.waitFor("deviceTable")
    robot.press("r", .command, expecting: "liveScan")
    XCTAssertTrue(robot.element("degradationBanner").waitForExistence(timeout: 25), "the degradation never reached the live scan")
    assertInside(
      robot,
      ["sidebar", "scanStatus", "liveScanTitle", "stageCard-discovery", "stageCard-naming", "degradationBanner", "liveScanList"],
      at: "live scan, degraded"
    )
    robot.capture("degradation-livescan", in: self)
  }

  @MainActor
  private func assertInside(_ robot: ZhenRobot, _ identifiers: [String], at moment: String) {
    let window = robot.window.frame.insetBy(dx: -1, dy: -1)
    for identifier in identifiers {
      let element = robot.element(identifier)
      XCTAssertTrue(element.exists, "\(identifier) is missing at \(moment)")
      XCTAssertTrue(window.contains(element.frame), "\(identifier) \(element.frame) left the window \(window) at \(moment)")
    }
  }
}
