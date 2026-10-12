import AppKit
import XCTest

/// Stage F: every action in the menu bar, frequent ones with shortcuts, and commands that
/// reach the front window's state through `@FocusedValue`.
final class CommandsUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Menu and item. (The key equivalents are proven by pressing them — here and in the
  /// keyboard gate — because XCUITest does not expose a menu item's shortcut.)
  let expected: [(menu: String, item: String, key: String)] = [
    ("View", "Devices", "1"), ("View", "Activity", "2"),
    ("Edit", "Find…", "f"),
    ("Scan", "Scan Now", "r"), ("Scan", "Stop Scan", "."),
    ("Device", "Open", "o"), ("Device", "Back to Devices", "["), ("Device", "Rename…", "e"),
    ("Device", "Scan Ports", "r"), ("Device", "Show in Activity", "a"),
    ("Device", "Copy Address", "c"), ("Device", "Copy MAC Address", "c"),
    ("File", "Export History…", "s"),
  ]

  @MainActor
  func testEveryActionIsInTheMenuBar() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    let bar = robot.app.menuBars.firstMatch
    for (menu, item, key) in expected {
      let element = bar.menuBarItems[menu].menuItems[item]
      XCTAssertTrue(element.exists, "\(menu) ▸ \(item) is missing")
      _ = key
    }
    for filter in ["All", "Presence", "Identity", "Ports", "Addresses"] {
      XCTAssertTrue(bar.menuBarItems["View"].menuItems[filter].exists, "View ▸ \(filter) is missing")
    }
  }

  /// A command acting on the window's selection: proof the menu reaches the window.
  @MainActor
  func testCopyAddressActsOnTheWindowsSelection() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.selectRowByKeyboard()
    let selected = robot.rows.first(where: \.isSelected)
    let cell = selected?.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'deviceName-'")).firstMatch
    let address = String((cell?.identifier ?? "").dropFirst("deviceName-".count))
    XCTAssertFalse(address.isEmpty)
    NSPasteboard.general.clearContents()
    robot.key("c", [.command, .shift])
    let copied = NSPredicate { _, _ in NSPasteboard.general.string(forType: .string) == address }
    wait(for: [XCTNSPredicateExpectation(predicate: copied, object: nil)], timeout: 5)
  }

  /// The Device menu's less-travelled shortcuts, pressed.
  @MainActor
  func testDeviceShortcuts() {
    let robot = ZhenRobot.launch(scanPace: 600)
    robot.waitFor("deviceTable")
    robot.selectRowByKeyboard()

    NSPasteboard.general.clearContents()
    robot.key("c", [.command, .option, .shift])
    let mac = NSPredicate { _, _ in (NSPasteboard.general.string(forType: .string) ?? "").count == 17 }
    wait(for: [XCTNSPredicateExpectation(predicate: mac, object: nil)], timeout: 5)

    robot.press("a", [.command, .shift], expecting: "activityList")
    robot.press("1", .command, expecting: "deviceTable")
    robot.selectRowByKeyboard()
    // Scan Ports opens the device and checks it there: no takeover, no /32 run. Slow
    // enough that Stop has something to stop.
    robot.app.terminate()
    let slow = ZhenRobot.launch(scanPace: 3_000)
    slow.waitFor("deviceTable")
    slow.selectRowByKeyboard()
    slow.press("r", [.command, .shift], expecting: "portScanProgress")
    XCTAssertTrue(slow.element("deviceDetail").exists)
    XCTAssertFalse(slow.element("liveScan").exists, "a port scan took over the window")
    slow.press(".", .command, expecting: "portScanFailure")
  }

  /// Phase 3, stage 3: one window. The scan runs from the window's task, so a second
  /// window over the same model ran every scan twice.
  @MainActor
  func testThereIsOneWindow() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.key("n", .command)
    let second = NSPredicate { _, _ in robot.app.windows.matching(NSPredicate(format: "identifier BEGINSWITH 'main'")).count > 1 }
    let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: second, object: nil)], timeout: 3)
    XCTAssertEqual(result, .timedOut, "⌘N opened a second window over the same model")
    XCTAssertFalse(robot.app.menuItems["New Window"].exists && robot.app.menuItems["New Window"].isEnabled, "File offers New Window")
  }

  /// Phase 3, stage 3: ⇧⌘S exports history from the main window.
  @MainActor
  func testExportShortcut() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.key("s", [.command, .shift])
    XCTAssertTrue(robot.app.sheets.firstMatch.waitForExistence(timeout: 5), "⇧⌘S opened no save panel")
    robot.key(.escape)
  }
}
