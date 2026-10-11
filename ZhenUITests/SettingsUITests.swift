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
    for control in ["scanIntervalPicker", "subnetOverrideField", "deepScanToggle", "retentionPicker"] {
      XCTAssertTrue(robot.element(control).exists, "no \(control)")
    }
    XCTAssertTrue(robot.element("settings").staticTexts["Kept forever — it’s what makes merges possible"].exists)
    XCTAssertTrue(robot.element("settings").staticTexts.allElementsBoundByIndex.contains { $0.text.contains("auto, from en0") })
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
    XCTAssertEqual(robot.element("helperState").text, "Installed · Zhen Scan Engine")
    XCTAssertTrue(robot.element("showInSystemSettingsButton").exists, "no way to check the claim against the OS")

    robot.element("removeHelperButton").click()
    robot.waitFor("confirmRemoveHelperButton")
    // The dialog's buttons report not hittable; a plain click() is silently a no-op.
    robot.element("confirmRemoveHelperButton").clickCentre()
    let removed = NSPredicate { _, _ in robot.element("helperState").text == "Not installed." }
    wait(for: [XCTNSPredicateExpectation(predicate: removed, object: nil)], timeout: 5)
  }
}
