import XCTest

/// Gate: restoration. Quit and relaunch: the window comes back at the size it had, in the
/// room it was in, with the device that was open.
final class RestorationUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testWindowRoomAndDeviceReturn() {
    var robot = ZhenRobot.launch(restoreState: true)
    robot.key("1", .command)
    robot.press("[", .command, expecting: "deviceTable")
    robot.shrinkToMinimum()
    let frame = robot.window.frame

    robot.selectRowByKeyboard()
    robot.key(.downArrow)
    robot.press("o", .command, expecting: "deviceDetail")
    let name = robot.element("detailName").text
    XCTAssertFalse(name.isEmpty)

    robot.key("q", .command)
    XCTAssertTrue(robot.app.wait(for: .notRunning, timeout: 10), "the app did not quit")

    robot = ZhenRobot.launch(restoreState: true)
    robot.waitFor("deviceDetail")
    XCTAssertEqual(robot.element("detailName").text, name, "a different device came back")
    XCTAssertEqual(robot.window.frame.size.width, frame.size.width, accuracy: 2)
    XCTAssertEqual(robot.window.frame.size.height, frame.size.height, accuracy: 2)

    // And the room: Activity, quit, relaunch, Activity.
    robot.press("2", .command, expecting: "activityList")
    robot.key("q", .command)
    XCTAssertTrue(robot.app.wait(for: .notRunning, timeout: 10))
    robot = ZhenRobot.launch(restoreState: true)
    robot.waitFor("activityList")
    robot.key("1", .command)
    robot.app.terminate()
  }
}
