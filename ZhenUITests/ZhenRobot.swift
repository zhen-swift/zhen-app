import XCTest

/// The UI tests' one way into the app. Tests say what a person does; this says which
/// identifier that is. Labels are copy and will change — identifiers are the API.
@MainActor
struct ZhenRobot {
  enum Look: String, CaseIterable {
    case light, dark, lightIncreased, darkIncreased

    var arguments: [String] {
      switch self {
      case .light: ["-Appearance", "light"]
      case .dark: ["-Appearance", "dark"]
      case .lightIncreased: ["-Appearance", "light", "-Contrast", "increased"]
      case .darkIncreased: ["-Appearance", "dark", "-Contrast", "increased"]
      }
    }
  }

  let app: XCUIApplication

  /// Launches on a fixture network. `restoreState` keeps the window's saved state, for the
  /// restoration gate; every other test starts clean.
  @discardableResult
  static func launch(
    fixture: String = "home", look: Look? = nil, scanPace: Int = 40,
    restoreState: Bool = false, extra: [String] = []
  ) -> ZhenRobot {
    let app = XCUIApplication()
    // `-UITesting` takes no value, so it goes LAST. Anywhere else AppKit reads it as a
    // default whose value is the next flag, the flag's own value is left over, and a
    // leftover argument is a document to open — so the app skips its window. Seen as
    // "the main window never appeared" with every argument in the right order but this one.
    app.launchArguments = ["-Fixture", fixture, "-ScanPace", "\(scanPace)"]
      + (look?.arguments ?? [])
      + (restoreState ? ["-NSQuitAlwaysKeepsWindows", "YES", "-RestoreState"] : ["-ApplePersistenceIgnoreState", "YES"])
      + extra
      + ["-UITesting"]
    app.launch()
    let robot = ZhenRobot(app: app)
    XCTAssertTrue(robot.window.waitForExistence(timeout: 10), "the main window never appeared")
    // Scene storage can outlive -ApplePersistenceIgnoreState between launches, so a test
    // that did not ask for restoration starts in Devices on purpose, not by luck.
    if !restoreState { robot.key("1", .command) }
    return robot
  }

  var window: XCUIElement { app.windows.firstMatch }
  /// SwiftUI's `Table` reaches accessibility as an outline on macOS 26, not a table; ask
  /// by identifier and type-free, so the next change of role does not blind every test.
  var table: XCUIElement { element("deviceTable") }
  var sidebar: XCUIElement { app.outlines["sidebar"].exists ? app.outlines["sidebar"] : app.descendants(matching: .any)["sidebar"] }

  func element(_ identifier: String) -> XCUIElement {
    app.descendants(matching: .any)[identifier].firstMatch
  }

  func waitFor(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "\(identifier) never appeared", file: file, line: line)
  }

  /// Rows the device table is showing.
  var rows: [XCUIElement] {
    let outline = table.outlineRows.allElementsBoundByIndex
    return outline.isEmpty ? table.tableRows.allElementsBoundByIndex : outline
  }

  /// Selects a device row by clicking its middle. The rows report themselves disabled to
  /// accessibility, so `click()` on the element refuses; a coordinate inside it does not.
  /// Never used by the keyboard gate, which selects with arrows.
  func select(row index: Int) {
    let row = rows[index]
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
  }

  /// Selects a device row with the keyboard alone: an arrow, and if the table did not
  /// have focus, Tab towards it and try again. Accessibility marks every cell "keyboard
  /// focused", so the only trustworthy signal is a row turning selected.
  func selectRowByKeyboard(file: StaticString = #filePath, line: UInt = #line) {
    let before = rows.firstIndex(where: \.isSelected)
    for _ in 0..<6 {
      // Down, or up when the selection already sits on the last row.
      for arrow in [XCUIKeyboardKey.downArrow, .upArrow] {
        key(arrow)
        let after = rows.firstIndex(where: \.isSelected)
        if after != nil, after != before { return }
      }
      key(.tab)
    }
    XCTFail("no keyboard route selected a device row", file: file, line: line)
  }

  /// Drags the window's bottom-right corner up and left past any sensible size, so the
  /// window settles at its minimum.
  func shrinkToMinimum() {
    let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)).withOffset(CGVector(dx: -2, dy: -2))
    let target = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 120, dy: 120))
    corner.press(forDuration: 0.2, thenDragTo: target)
  }

  /// Every cell of every visible row, with its row.
  var cells: [(row: Int, cell: XCUIElement)] {
    rows.enumerated().flatMap { index, row in row.cells.allElementsBoundByIndex.map { (index, $0) } }
  }

  func key(_ key: String, _ modifiers: XCUIElement.KeyModifierFlags = []) {
    frontmost()
    app.typeKey(key, modifierFlags: modifiers)
  }

  func key(_ key: XCUIKeyboardKey, _ modifiers: XCUIElement.KeyModifierFlags = []) {
    frontmost()
    app.typeKey(key, modifierFlags: modifiers)
  }

  /// Sends a shortcut until `identifier` appears, up to three times. A shortcut that does
  /// not exist fails all three; one sent in the instant the app is re-activating — when
  /// its menu items are briefly disabled — is sent again instead of failing the gate.
  func press(
    _ key: String, _ modifiers: XCUIElement.KeyModifierFlags = [], expecting identifier: String,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    for _ in 0..<3 {
      self.key(key, modifiers)
      if element(identifier).waitForExistence(timeout: 4) { return }
    }
    XCTFail("\(identifier) never appeared after ⌘-key \(key) ×3", file: file, line: line)
  }

  /// Opens the device at `address` with a double-click, as a person would.
  func openDevice(_ address: String, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<3 {
      frontmost()
      guard let row = rows.first(where: { $0.descendants(matching: .any)["deviceName-\(address)"].exists }) else {
        XCTFail("no row for \(address)", file: file, line: line)
        return
      }
      row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
      if element("deviceDetail").waitForExistence(timeout: 4) { return }
    }
    XCTFail("\(address) never opened", file: file, line: line)
  }

  /// Opens a row's context menu, re-trying a right-click that landed while the app was
  /// coming to the front. `marker` is an item only the context menu has.
  func openContextMenu(row index: Int, marker: String, file: StaticString = #filePath, line: UInt = #line) {
    for _ in 0..<3 {
      frontmost()
      rows[index].rightClickCentre()
      if app.menuItems[marker].waitForExistence(timeout: 3) { return }
      key(.escape)
    }
    XCTFail("the context menu never opened", file: file, line: line)
  }

  /// These tests run on a desktop someone may be using: another app's menu-bar popover
  /// once took key focus mid-test and swallowed an Esc. Keys go to Zhen or nowhere.
  func frontmost() {
    guard app.state != .runningForeground else { return }
    app.activate()
    _ = app.wait(for: .runningForeground, timeout: 3)
  }

  /// Attaches the window as it is now, kept with the result bundle.
  func capture(_ name: String, in test: XCTestCase) {
    let attachment = XCTAttachment(screenshot: window.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    test.add(attachment)
  }
}

extension XCUIElement {
  /// Everything an element says, label and value together: a combined element keeps its
  /// children's text in one or the other depending on the control.
  var words: String { [label, (value as? String) ?? ""].joined(separator: " ") }

  /// Clicks the middle of an element that accessibility reports as not hittable — table
  /// rows and headers on macOS 26.
  func clickCentre() { coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click() }
  func rightClickCentre() { coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick() }

  /// A text element's words: SwiftUI puts them in the value, not the label.
  var text: String { (value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? label }
}
