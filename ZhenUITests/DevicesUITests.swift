import XCTest

/// Stage B: the Devices room in each of its states, its sorting, and its menu.
final class DevicesUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testNeverScanned() {
    let robot = ZhenRobot.launch(fixture: "empty")
    robot.waitFor("neverScanned")
    XCTAssertTrue(robot.element("emptyScanNowButton").exists)
    XCTAssertTrue(robot.element("scanStatus").words.contains("Never scanned"), "the footer is never empty")
    robot.capture("devices-never-scanned", in: self)
  }

  @MainActor
  func testFirstScanStreamsRowsNeverASpinner() {
    // 600 ms a host: on CI's virtual Mac one accessibility query can take seconds, and at
    // 250 ms the tenth host had arrived before the test looked for the first.
    let robot = ZhenRobot.launch(fixture: "empty", scanPace: 600)
    robot.waitFor("neverScanned")
    robot.element("emptyScanNowButton").click()
    robot.waitFor("liveScan")
    // Rows arrive one at a time while discovery is still running.
    XCTAssertTrue(robot.element("foundHost-192.168.50.1").waitForExistence(timeout: 10))
    XCTAssertFalse(robot.element("foundHost-192.168.50.37").exists, "everything arrived at once: nothing streamed")
    XCTAssertEqual(robot.app.progressIndicators.matching(NSPredicate(format: "identifier == 'deviceTable'")).count, 0)
    // And it hands back to a table on its own.
    XCTAssertTrue(robot.table.waitForExistence(timeout: 40), "the scan never handed back to Devices")
  }

  @MainActor
  func testPartialRunSaysSoAfterTheFact() {
    let robot = ZhenRobot.launch(fixture: "partial")
    robot.waitFor("deviceTable")
    robot.waitFor("partialRunNotice")
    XCTAssertTrue(robot.element("partialRunTitle").text.contains("partial"))
    XCTAssertTrue(robot.element("scanStatus").words.hasPrefix("Partial results"), "the footer dot is not amber: \(robot.element("scanStatus").words)")
    robot.element("partialRunDisclosure").click()
    robot.waitFor("degradationBanner")
    robot.capture("devices-partial", in: self)
  }

  @MainActor
  func testNothingAnsweredIsExplained() {
    let robot = ZhenRobot.launch(fixture: "silent")
    robot.waitFor("nothingAnswered")
    XCTAssertTrue(robot.element("openLocalNetworkSettingsButton").exists, "no way to the permission")
    XCTAssertTrue(robot.element("degradation-0").label.contains("Local Network access appears to be denied"))
    robot.capture("devices-nothing-answered", in: self)
  }

  @MainActor
  func testSortingAndSearch() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    // Default: online first, the offline rows last.
    let names = robot.rows.compactMap { row in
      row.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'deviceName-'")).firstMatch.text
    }.filter { !$0.isEmpty }
    let firstOffline = names.firstIndex { $0.contains(", offline,") } ?? names.count
    XCTAssertGreaterThan(firstOffline, 0)
    XCTAssertTrue(names[firstOffline...].allSatisfy { $0.contains(", offline,") }, "an online device sorts below an offline one: \(names)")

    // Sort by address, then reverse it: the gateway is at one end, then at the other.
    let header = robot.app.buttons["IP Address"]
    func ends() -> (first: String, last: String) {
      let ids = robot.rows.compactMap { row in
        row.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'deviceName-'")).firstMatch.identifier
      }.filter { !$0.isEmpty }
      return (ids.first ?? "", ids.last ?? "")
    }
    header.clickCentre()
    let once = ends()
    header.clickCentre()
    let twice = ends()
    XCTAssertTrue([once.first, once.last].contains("deviceName-192.168.50.1"), "address sort left the gateway mid-list: \(once)")
    XCTAssertEqual(once.first, twice.last, "clicking the header again did not reverse the order")

    // Search narrows, and an unmatched search says so with the counts left alone.
    robot.press("f", .command, expecting: "deviceTable")
    robot.app.typeText("zzz")
    robot.waitFor("noMatches")
    XCTAssertTrue(robot.window.title.contains("13 devices"), "searching changed the header counts")
  }

  @MainActor
  func testContextMenuMirrorsTheDeviceMenu() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.openContextMenu(row: 1, marker: "Copy MAC Address")
    // On screen, not merely in the app: the menu bar's Device menu has the same titles,
    // and a query that found those passed with an item deleted from the context menu.
    for item in ["Open", "Rename…", "Scan Ports", "Show in Activity", "Copy Address", "Copy MAC Address"] {
      let shown = robot.app.menuItems.matching(NSPredicate(format: "title == %@", item)).allElementsBoundByIndex.contains(where: \.isHittable)
      XCTAssertTrue(shown, "the context menu has no \(item)")
    }
    // The context menu's Open, not the menu bar's: the one on screen.
    let open = robot.app.menuItems.matching(NSPredicate(format: "title == 'Open'")).allElementsBoundByIndex.first(where: \.isHittable)
    XCTAssertNotNil(open)
    open?.click()
    robot.waitFor("deviceDetail")
  }
}
