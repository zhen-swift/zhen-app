import XCTest

/// Stage E: the Settings scene and the privileged-engine panel, on the fake helper — no
/// test registers anything.
final class SettingsUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  private func openSettings() -> ZhenRobot {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.press(",", .command, expecting: "settings")
    return robot
  }

  @MainActor
  func testSectionsAndControls() {
    let robot = openSettings()
    // Section labels reach accessibility as drawn — "SCANNING" — so match either case.
    for section in ["Scanning", "History", "Privileged engine"] {
      let found = robot.element("settings").descendants(matching: .any)
        .matching(NSPredicate(format: "label ==[c] %@", section)).count > 0
      XCTAssertTrue(found, "no \(section) section")
    }
    for control in ["scanIntervalPicker", "subnetOverrideField", "scanBudgetPicker", "deepScanToggle", "notifyNewDevicesToggle", "keepInMenuBarToggle", "retentionPicker", "exportHistoryButton"] {
      XCTAssertTrue(robot.element(control).exists, "no \(control)")
    }
    XCTAssertTrue(robot.element("settings").staticTexts["Kept forever — it’s what makes merges possible"].exists)
    XCTAssertTrue(robot.element("settings").staticTexts.allElementsBoundByIndex.contains { $0.text.contains("auto, from en0") })
  }

  /// Phase 3, stage 3: the version is pinned above the form, the history line says what is
  /// true under a fixture, and Export opens a save panel.
  @MainActor
  func testVersionHistoryAndExport() {
    let robot = openSettings()
    XCTAssertTrue(robot.element("settingsVersion").text.hasPrefix("Zhen "), robot.element("settingsVersion").text)
    XCTAssertTrue(robot.element("historySize").text.contains("fixture"), robot.element("historySize").text)
    robot.element("exportHistoryButton").click()
    let panel = robot.app.sheets.firstMatch
    XCTAssertTrue(panel.waitForExistence(timeout: 5), "Export opened no save panel")
    XCTAssertTrue(panel.textFields.allElementsBoundByIndex.contains { $0.text.hasPrefix("Zhen history") }, "the export is not named for its date")
    robot.key(.escape)
    XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
  }

  @MainActor
  func testSubnetOverrideIsValidated() {
    let robot = openSettings()
    let field = robot.element("subnetOverrideField")
    field.click()
    robot.app.typeText("10.0.0.0/8")
    XCTAssertTrue(robot.element("subnetOverrideError").waitForExistence(timeout: 3), "a /8 was accepted")
    field.clickCentre()
    robot.key("a", .command)
    robot.app.typeText("192.168.7.0/24")
    XCTAssertTrue(robot.element("subnetOverrideError").waitForNonExistence(timeout: 3), "a good /24 was refused")
    // And it reaches the scan. Settings once wrote a store the model never read — the
    // real app's preferences, under fixtures — so the override was accepted and ignored.
    // The fixture has nothing in that /24, so the scan ends at once; the footer names
    // the network the recorded run covered.
    robot.key("w", .command)
    robot.key("r", .command)
    let scanned = NSPredicate { _, _ in robot.element("scanStatus").words.contains("192.168.7.0/24") }
    let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: scanned, object: nil)], timeout: 10)
    XCTAssertEqual(result, .completed, "the scan ignored the override: \(robot.element("scanStatus").words)")
  }

  @MainActor
  func testHelperPanelInstallApproveRemove() {
    let robot = openSettings()
    XCTAssertEqual(robot.element("helperState").text, "Not installed.")
    XCTAssertTrue(robot.element("removeHelperButton").exists, "no Remove beside Install")
    XCTAssertFalse(robot.element("removeHelperButton").isEnabled, "Remove offered with nothing installed")

    robot.element("installHelperButton").click()
    XCTAssertEqual(robot.element("helperState").text, "Installed · waiting for your approval")
    XCTAssertTrue(robot.element("openLoginItemsButton").exists)
    XCTAssertTrue(robot.element("removeHelperButton").isEnabled)

    robot.element("openLoginItemsButton").click()
    let answering = NSPredicate { _, _ in robot.element("helperState").text == "Installed · Zhen Scan Engine fixture" }
    wait(for: [XCTNSPredicateExpectation(predicate: answering, object: nil)], timeout: 5)
    XCTAssertTrue(robot.element("showInSystemSettingsButton").exists, "no way to check the claim against the OS")

    robot.element("removeHelperButton").click()
    robot.waitFor("confirmRemoveHelperButton")
    // The dialog's buttons report not hittable; a plain click() is silently a no-op.
    robot.element("confirmRemoveHelperButton").clickCentre()
    let removed = NSPredicate { _, _ in robot.element("helperState").text == "Not installed." }
    wait(for: [XCTNSPredicateExpectation(predicate: removed, object: nil)], timeout: 5)
  }
}
