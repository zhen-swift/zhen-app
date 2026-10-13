import XCTest

/// Gate: keyboard-only. Every room, the detail, the takeover and the Settings scene are
/// driven with keys alone — no clicks, no coordinates. ⌘-number is the only keyboard route
/// between rooms on a stock Mac (the split view keeps the sidebar out of the Tab loop), so
/// those shortcuts are part of what is under test.
final class KeyboardUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testDevicesAndDetailByKeyboard() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")

    // Into the table, then down to a row: arrows select, ⌘O opens.
    robot.selectRowByKeyboard()
    robot.press("o", .command, expecting: "deviceDetail")
    XCTAssertTrue(robot.element("detailName").exists)

    // Back to the list.
    robot.press("[", .command, expecting: "deviceTable")

    // Return is the table's primary action, the same as a double-click.
    robot.selectRowByKeyboard()
    robot.key(.return)
    robot.waitFor("deviceDetail")
    robot.key("[", .command)

    // Search: ⌘F, type, and the list narrows.
    robot.key("f", .command)
    robot.app.typeText("Sala")
    XCTAssertTrue(robot.element("deviceName-192.168.50.10").waitForExistence(timeout: 3))
    XCTAssertFalse(robot.element("deviceName-192.168.50.1").exists, "search did not narrow the list")
    robot.key(.escape)
  }

  @MainActor
  func testActivityByKeyboard() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.press("2", .command, expecting: "activityList")
    XCTAssertTrue(robot.element("event-renamed").exists)

    // ⌥⌘2 is Presence: the rename leaves, the arrivals stay.
    var filtered = false
    for _ in 0..<3 where !filtered {
      robot.key("2", [.command, .option])
      filtered = robot.element("event-renamed").waitForNonExistence(timeout: 4)
    }
    XCTAssertTrue(filtered, "the Presence filter kept an identity event")
    XCTAssertTrue(robot.element("event-appeared").exists)

    // ⌥⌘4 is Ports: nothing in this window, said so, and the filter stays.
    robot.press("4", [.command, .option], expecting: "activityNoMatch")
    XCTAssertTrue(robot.element("activityFilter").exists)

    robot.key("1", [.command, .option])
    robot.press("1", .command, expecting: "deviceTable")
  }

  @MainActor
  func testScanAndSettingsByKeyboard() {
    let robot = ZhenRobot.launch(scanPace: 300)
    robot.waitFor("deviceTable")

    // ⌘R scans; the takeover replaces the table; ⌘. stops it and keeps what was found.
    robot.press("r", .command, expecting: "liveScan")
    XCTAssertTrue(robot.element("foundHost-192.168.50.1").waitForExistence(timeout: 5))
    robot.press(".", .command, expecting: "showDevicesButton")
    XCTAssertTrue(robot.element("foundHost-192.168.50.1").exists, "stopping discarded what was found")
    // Esc leaves the stopped scan.
    robot.key(.escape)
    robot.waitFor("deviceTable")

    // ⌘, opens Settings; ⌘W closes it.
    robot.press(",", .command, expecting: "settings")
    robot.key("w", .command)
    XCTAssertTrue(robot.element("settings").waitForNonExistence(timeout: 3))
  }
}
