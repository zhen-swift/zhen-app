import XCTest

/// "Keep watching from the menu bar": off, closing the window quits as before; on, the app
/// outlives its window and the menu bar item runs the scans.
final class MenuBarUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// The menu item with this title that is on screen now.
  @MainActor
  private func shown(_ robot: ZhenRobot, _ title: String) -> XCUIElement? {
    robot.app.menuItems.matching(NSPredicate(format: "title == %@", title)).allElementsBoundByIndex.first(where: \.isHittable)
  }

  @MainActor
  func testOffClosingTheWindowQuits() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.key("w", .command)
    XCTAssertTrue(robot.app.wait(for: .notRunning, timeout: 10), "with the menu bar off, the app outlived its window")
  }

  /// Gate. Break: `isActive: false` in `MenuBarLabelView` — the item shows, Scan Now is
  /// asked for, and nothing runs it with the window closed.
  @MainActor
  func testOnTheMenuBarItemScansWithTheWindowClosed() {
    let robot = ZhenRobot.launch(scanPace: 5)
    robot.waitFor("deviceTable")
    XCTAssertTrue(robot.element("scanStatus").words.contains("6 min"), robot.element("scanStatus").words)

    robot.press(",", .command, expecting: "settings")
    robot.element("keepInMenuBarToggle").click()
    robot.key("w", .command)  // Settings
    robot.key("w", .command)  // the main window
    XCTAssertFalse(robot.app.wait(for: .notRunning, timeout: 3), "the app quit with the menu bar on")
    XCTAssertFalse(robot.window.exists, "the window did not close")

    let item = robot.app.statusItems.firstMatch
    XCTAssertTrue(item.waitForExistence(timeout: 5), "no menu bar item")
    item.click()
    // The menu bar's own Scan menu has a Scan Now too: the one on screen is the item's.
    let onScreen = NSPredicate { _, _ in self.shown(robot, "Scan Now") != nil }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: onScreen, object: nil)], timeout: 5), .completed)
    shown(robot, "Scan Now")?.click()

    // Let the scan run with no window, then come back through the menu.
    Thread.sleep(forTimeInterval: 3)
    item.click()
    let open = NSPredicate { _, _ in self.shown(robot, "Open Zhen") != nil }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: open, object: nil)], timeout: 5), .completed)
    shown(robot, "Open Zhen")?.click()
    XCTAssertTrue(robot.window.waitForExistence(timeout: 5), "Open Zhen opened no window")
    let scanned = NSPredicate { _, _ in robot.element("scanStatus").words.contains("just now") }
    let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: scanned, object: nil)], timeout: 15)
    XCTAssertEqual(result, .completed, "no scan ran while the window was closed: \(robot.element("scanStatus").words)")

    // Leave it off for the next test: the fixture domain is cleared at launch, but say so.
    robot.press(",", .command, expecting: "settings")
    robot.element("keepInMenuBarToggle").click()
    robot.app.terminate()
  }
}
