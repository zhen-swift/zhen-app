import XCTest

/// Gate: window size range. At the minimum window and at full screen, nothing a person
/// needs is clipped: every pinned element and every table cell lies inside the window, no
/// column collapses, and the sidebar keeps its own minimum. Old defect F2 was a table
/// minimum the split view paid for out of the sidebar.
final class WindowSizeUITests: XCTestCase {
  /// The token values, restated: a test that imported the app's token would agree with
  /// whatever the app said.
  let minimumWidth: CGFloat = 860
  let sidebarMinimum: CGFloat = 180

  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testMinimumWindowAndFullScreen() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")

    robot.shrinkToMinimum()
    let settled = robot.window.frame.width
    robot.shrinkToMinimum()
    XCTAssertEqual(robot.window.frame.width, settled, accuracy: 1, "the window kept shrinking: it had no minimum")
    XCTAssertGreaterThanOrEqual(settled, minimumWidth - 1)
    assertNothingClipped(robot, at: "minimum")
    robot.capture("devices-minimum", in: self)
    robot.press("2", .command, expecting: "activityList")
    assertInside(robot, ["activityFilter", "activityList", "sidebar"], at: "minimum, Activity")
    robot.key("1", .command)

    guard enterFullScreen(robot) else { return }
    robot.waitFor("deviceTable")
    assertNothingClipped(robot, at: "full screen")
    robot.capture("devices-fullscreen", in: self)
    robot.key("f", [.command, .control])
  }

  /// Spanish runs longer than English — "Escanear ahora", "Última vez visto", "Dispositivo
  /// sin identificar" — and the minimum window is measured from the text. At the minimum,
  /// in Spanish, nothing is clipped either.
  @MainActor
  func testSpanishFitsAtMinimum() {
    let robot = ZhenRobot.launch(language: "es")
    robot.waitFor("deviceTable")
    XCTAssertTrue(robot.window.title.contains("dispositivos"), "not in Spanish: \(robot.window.title)")
    robot.shrinkToMinimum()
    assertNothingClipped(robot, at: "minimum, Spanish")
    robot.capture("devices-minimum-es", in: self)
    robot.openDevice("192.168.50.10")
    assertInside(robot, ["detailName", "renameButton", "scanPortsButton", "sidebar"], at: "minimum, Spanish, detail")
    robot.capture("detail-minimum-es", in: self)
  }

  /// The detail and the live-scan takeover at the same two sizes.
  @MainActor
  func testDetailAndTakeoverFitAtBothSizes() {
    let robot = ZhenRobot.launch(scanPace: 900)
    robot.waitFor("deviceTable")
    robot.shrinkToMinimum()
    checkDetailAndTakeover(robot, at: "minimum")
    guard enterFullScreen(robot) else { return }
    checkDetailAndTakeover(robot, at: "full screen")
    robot.key("f", [.command, .control])
  }

  @MainActor
  private func checkDetailAndTakeover(_ robot: ZhenRobot, at size: String) {
    robot.openDevice("192.168.50.10")
    assertInside(robot, ["detailName", "renameButton", "scanPortsButton", "sidebar"], at: "\(size), detail")
    for card in ["identityCard", "knownByCard"] {
      let frame = robot.element(card).frame
      XCTAssertLessThanOrEqual(frame.maxX, robot.window.frame.maxX + 1, "\(card) runs past the window at \(size)")
      XCTAssertGreaterThan(frame.width, 200, "\(card) collapsed at \(size)")
    }
    robot.capture("detail-\(size)", in: self)
    robot.press("[", .command, expecting: "deviceTable")
    robot.press("r", .command, expecting: "liveScan")
    assertInside(robot, ["liveScanTitle", "liveStopScanButton", "stageCard-discovery", "stageCard-naming", "stageCard-deep_scan"], at: "\(size), live scan")
    robot.capture("livescan-\(size)", in: self)
    robot.press(".", .command, expecting: "showDevicesButton")
    assertInside(robot, ["showDevicesButton", "scanAgainButton"], at: "\(size), stopped scan")
    robot.key(.escape)
    robot.waitFor("deviceTable")
  }

  /// Enters full screen, or says there is no wider window to check. On a screen the minimum
  /// window already spans (CI's 1024 pt), the minimum is the widest the window gets, and
  /// there ⌃⌘F was measured not to take effect at all.
  @MainActor
  private func enterFullScreen(_ robot: ZhenRobot) -> Bool {
    if robot.window.frame.width >= robot.app.menuBars.firstMatch.frame.width - 1 {
      XCTContext.runActivity(named: "The minimum window already spans the screen: no full-screen pass") { _ in }
      return false
    }
    robot.key("f", [.command, .control])
    let entered = NSPredicate { _, _ in robot.window.frame.width > self.minimumWidth + 200 }
    wait(for: [XCTNSPredicateExpectation(predicate: entered, object: nil)], timeout: 10)
    return true
  }

  @MainActor
  private func assertNothingClipped(_ robot: ZhenRobot, at size: String) {
    assertInside(robot, ["sidebar", "deviceTable", "scanNowButton", "scanStatus"], at: size)
    let sidebar = robot.element("sidebar").frame
    XCTAssertGreaterThanOrEqual(sidebar.width, sidebarMinimum - 2, "at \(size) the sidebar paid for the table: \(sidebar.width) pt")
    let cells = robot.cells
    XCTAssertFalse(cells.isEmpty, "no cells at \(size)")
    let window = robot.window.frame.insetBy(dx: -1, dy: -1)
    // Where the window fills a screen narrower than the measured minimum (CI's is 1024 pt),
    // the table scrolls sideways by design: a cell may run past the window there, and only
    // there. The menu bar spans the screen.
    let screenWidth = robot.app.menuBars.firstMatch.frame.width
    let tableScrolls = robot.window.frame.width >= screenWidth - 1
    for (row, cell) in cells where cell.frame.minY < window.maxY {
      XCTAssertGreaterThan(cell.frame.width, 20, "at \(size) row \(row) has a collapsed column: \(cell.frame)")
      if !tableScrolls {
        XCTAssertLessThanOrEqual(cell.frame.maxX, window.maxX, "at \(size) row \(row) runs past the window: \(cell.frame)")
      }
    }
  }

  @MainActor
  private func assertInside(_ robot: ZhenRobot, _ identifiers: [String], at size: String) {
    let window = robot.window.frame.insetBy(dx: -1, dy: -1)
    for identifier in identifiers {
      let element = robot.element(identifier)
      XCTAssertTrue(element.exists, "\(identifier) is missing at \(size)")
      XCTAssertTrue(window.contains(element.frame), "\(identifier) \(element.frame) leaves the window \(window) at \(size)")
    }
  }
}
