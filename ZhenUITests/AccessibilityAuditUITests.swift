import XCTest

/// Stage F: every interactive control on every screen has a stable identifier and a name.
/// The old app's helper could not be uninstalled by automation because no button had an
/// accessible name; this walks each screen and fails on the first such control.
final class AccessibilityAuditUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = true
  }

  let types: [XCUIElement.ElementType] = [
    .button, .textField, .checkBox, .popUpButton, .radioButton, .segmentedControl,
    .menuButton, .toggle, .slider, .link, .switch,
  ]

  /// AppKit's own controls, named by the system and not ours to identify: window buttons,
  /// the sidebar toggle, the toolbar search field, sortable column headers, the overlay
  /// scroller's disabled parts, and the parts of a legacy scroll bar — a Mac driven by a
  /// mouse, as CI's virtual one is, shows those, and their page areas are nameless buttons.
  @MainActor
  private func isSystem(_ element: XCUIElement, scrollBars: [CGRect]) -> Bool {
    element.identifier.hasPrefix("_XCUI:")
      || ["Hide Sidebar", "Show Sidebar", "Search", "Back"].contains(element.label)
      || (!element.title.isEmpty && element.identifier.isEmpty && element.label.isEmpty)
      || (!element.isEnabled && element.frame.width <= 8)
      || (element.identifier.isEmpty && element.label.isEmpty && scrollBars.contains { $0.contains(element.frame) })
  }

  @MainActor
  private func audit(_ root: XCUIElement, screen: String) {
    var checked = 0
    let scrollBars = root.descendants(matching: .scrollBar).allElementsBoundByIndex.map(\.frame)
    for type in types {
      for element in root.descendants(matching: type).allElementsBoundByIndex where element.exists && !isSystem(element, scrollBars: scrollBars) {
        checked += 1
        XCTAssertFalse(element.identifier.isEmpty, "\(screen): a \(type) named '\(element.label)' at \(element.frame) has no identifier")
        XCTAssertFalse(element.label.isEmpty && element.title.isEmpty, "\(screen): '\(element.identifier)' has no accessible name")
      }
    }
    XCTAssertGreaterThan(checked, 0, "\(screen): nothing was audited")
  }

  @MainActor
  func testEveryScreen() {
    let robot = ZhenRobot.launch(scanPace: 900)
    robot.waitFor("deviceTable")
    audit(robot.window, screen: "Devices")
    robot.openDevice("192.168.50.25")
    audit(robot.window, screen: "Detail")
    robot.press("[", .command, expecting: "deviceTable")
    robot.press("2", .command, expecting: "activityList")
    audit(robot.window, screen: "Activity")
    robot.press("1", .command, expecting: "deviceTable")
    robot.press("r", .command, expecting: "liveScan")
    audit(robot.window, screen: "Live scan, running")
    robot.press(".", .command, expecting: "showDevicesButton")
    audit(robot.window, screen: "Live scan, stopped")
    robot.key(.escape)
    robot.press(",", .command, expecting: "settings")
    let settings = robot.app.windows.containing(.any, identifier: "settings").firstMatch
    audit(settings, screen: "Settings")
    robot.element("installHelperButton").click()
    audit(settings, screen: "Settings, awaiting approval")
  }

  @MainActor
  func testEmptyAndDegradedStates() {
    for (fixture, identifier) in [("empty", "neverScanned"), ("silent", "nothingAnswered")] {
      let robot = ZhenRobot.launch(fixture: fixture)
      robot.waitFor(identifier)
      audit(robot.window, screen: fixture)
      robot.app.terminate()
    }
  }
}
