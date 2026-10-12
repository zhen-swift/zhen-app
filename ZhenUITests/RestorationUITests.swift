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

  /// Part 5: the table's sort and its columns come back too. Right-click a header to hide a
  /// column; click one to sort.
  @MainActor
  func testSortAndColumnsReturn() {
    var robot = ZhenRobot.launch(restoreState: true)
    robot.key("1", .command)
    robot.press("[", .command, expecting: "deviceTable")
    // From a known state: a column hidden by an earlier run comes back first. (The sort
    // needs no reset — the test compares after the relaunch with whatever it set.)
    if !robot.app.buttons["MAC Address"].exists {
      robot.app.buttons["IP Address"].rightClickCentre()
      robot.app.menuItems.matching(NSPredicate(format: "title == 'MAC Address'")).allElementsBoundByIndex.first(where: \.isHittable)?.click()
      XCTAssertTrue(robot.app.buttons["MAC Address"].waitForExistence(timeout: 3))
    }
    // Address ascending, then descending, each surviving a relaunch. Addresses are
    // unique, so the whole order is fixed — "Last Seen" was not: every online row is "Now",
    // and ties come back in another order. Two directions, because a sort never stored
    // still matches whatever the window saved last, and an earlier version of this test
    // passed on exactly that.
    let header = robot.app.buttons["IP Address"]
    header.clickCentre()
    if rowOrder(robot).first != "deviceName-192.168.50.1" { header.clickCentre() }
    let ascending = rowOrder(robot)
    XCTAssertEqual(ascending.first, "deviceName-192.168.50.1")
    robot.key("q", .command)
    XCTAssertTrue(robot.app.wait(for: .notRunning, timeout: 10))
    robot = ZhenRobot.launch(restoreState: true)
    robot.waitFor("deviceTable")
    XCTAssertEqual(rowOrder(robot), ascending, "the ascending sort did not come back")

    robot.app.buttons["IP Address"].clickCentre()
    let orderBefore = rowOrder(robot)
    XCTAssertEqual(orderBefore, ascending.reversed(), "a second click did not reverse the order")

    robot.app.buttons["MAC Address"].rightClickCentre()
    let macItem = robot.app.menuItems.matching(NSPredicate(format: "title == 'MAC Address'")).allElementsBoundByIndex.first(where: \.isHittable)
    XCTAssertNotNil(macItem, "the header menu has no column list")
    macItem?.click()
    XCTAssertTrue(robot.app.buttons["MAC Address"].waitForNonExistence(timeout: 3), "the MAC column did not hide")

    robot.key("q", .command)
    XCTAssertTrue(robot.app.wait(for: .notRunning, timeout: 10))
    robot = ZhenRobot.launch(restoreState: true)
    robot.waitFor("deviceTable")
    XCTAssertFalse(robot.app.buttons["MAC Address"].exists, "the hidden column came back")
    XCTAssertEqual(rowOrder(robot), orderBefore, "the sort did not come back")

    // Put it back for whoever restores next, and quit so the window saves it.
    robot.app.buttons["IP Address"].rightClickCentre()
    robot.app.menuItems.matching(NSPredicate(format: "title == 'MAC Address'")).allElementsBoundByIndex.first(where: \.isHittable)?.click()
    XCTAssertTrue(robot.app.buttons["MAC Address"].waitForExistence(timeout: 3))
    robot.key("q", .command)
    _ = robot.app.wait(for: .notRunning, timeout: 10)
  }

  /// Every row, top to bottom. The whole order, not the first row: in the fixture the first
  /// row is the same under the default order and under address-descending, and a test of
  /// the first row passed with the sort never stored.
  @MainActor
  private func rowOrder(_ robot: ZhenRobot) -> [String] {
    robot.rows.map { $0.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'deviceName-'")).firstMatch.identifier }
  }
}
