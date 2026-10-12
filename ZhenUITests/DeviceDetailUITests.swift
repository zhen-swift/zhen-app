import XCTest

/// Stage B: the detail's four blocks, the unidentified case, and rename.
final class DeviceDetailUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testFourBlocksForANamedDevice() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.openDevice("192.168.50.10")
    for card in ["identityCard", "knownByCard", "portsCard", "recentEventsCard"] {
      XCTAssertTrue(robot.element(card).exists, "\(card) is missing")
    }
    XCTAssertEqual(robot.element("detailName").text, "Sala de estar principal")
    // Known by: every source listed, the winner chipped, the silent ones saying so.
    XCTAssertTrue(robot.element("knownBy-Bonjour").words.contains("Winner"), robot.element("knownBy-Bonjour").words)
    XCTAssertTrue(robot.element("knownBy-NetBIOS").words.contains("not advertised"))
    XCTAssertTrue(robot.element("portsCard").staticTexts["5000/tcp"].exists, "port missing or mis-formatted")
    let events = robot.element("recentEventsCard").descendants(matching: .any).allElementsBoundByIndex.map(\.words)
    XCTAssertTrue(events.contains { $0.contains("was Apple TV") }, "the rename is not among its recent events")
    robot.capture("detail-named", in: self)
  }

  @MainActor
  func testUnidentifiedDeviceIsANormalDetail() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.openDevice("192.168.50.25")
    XCTAssertEqual(robot.element("detailName").text, "Unidentified device")
    for source in ["Assigned", "Bonjour", "UPnP", "NetBIOS", "Reverse DNS"] {
      XCTAssertTrue(robot.element("knownBy-\(source)").words.contains("not advertised"), "\(source) hides its absence")
    }
    XCTAssertTrue(robot.element("cardScanPortsButton").exists, "never port-scanned, and no way to scan")
    robot.capture("detail-unidentified", in: self)
  }

  /// Phase 3, stage 1: a port scan of one device used to record a /32 run, after which
  /// every other device read as offline.
  @MainActor
  func testPortScanLeavesTheRestOnline() {
    let robot = ZhenRobot.launch(scanPace: 50)
    robot.waitFor("deviceTable")
    let before = robot.window.title
    robot.openDevice("192.168.50.25")
    // By key: the card's own button sits below the fold at the default window size.
    robot.key("r", [.command, .shift])
    robot.waitFor("noOpenPorts")
    let caption = robot.element("portsCard").staticTexts.allElementsBoundByIndex.map(\.text)
    XCTAssertTrue(caption.contains { $0.contains("this session") }, "the result does not say it is unsaved: \(caption)")
    robot.key("[", .command)
    robot.waitFor("deviceTable")
    XCTAssertEqual(robot.window.title, before, "a port scan changed the network's counts")
  }

  @MainActor
  func testRenameIsLocalAndWins() {
    let robot = ZhenRobot.launch()
    robot.waitFor("deviceTable")
    robot.openDevice("192.168.50.25")
    robot.key("e", [.command, .shift])
    robot.waitFor("renameField")
    robot.app.typeText("Hall camera")
    robot.element("renameConfirmButton").click()
    XCTAssertTrue(robot.element("knownBy-You").waitForExistence(timeout: 3))
    XCTAssertTrue(robot.element("knownBy-You").words.contains("Winner"))
    XCTAssertEqual(robot.element("detailName").text, "Hall camera")
    robot.press("[", .command, expecting: "deviceTable")
    XCTAssertTrue(robot.element("deviceName-192.168.50.25").label.hasPrefix("Hall camera"))
  }
}
