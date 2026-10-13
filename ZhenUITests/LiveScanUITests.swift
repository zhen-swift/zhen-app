import XCTest

/// Stage C: the live scan takeover — starting, naming, done, stopped — and the gate that
/// degradations outlive the scan that found them.
final class LiveScanUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testStartingThenNamingThenHandBack() {
    let robot = ZhenRobot.launch(scanPace: 1_500)
    robot.waitFor("deviceTable")
    robot.press("r", .command, expecting: "liveScan")
    // Starting: nothing has answered yet.
    XCTAssertTrue(robot.element("liveScanListening").exists, "no 'Listening…' before the first host")
    XCTAssertTrue(robot.element("liveScanTitle").text.hasPrefix("Scanning 192.168.50.0/24"))
    XCTAssertTrue(robot.element("stageCard-naming").words.contains("Queued"))
    XCTAssertTrue(robot.element("stageCard-deep_scan").words.contains("Not requested"), robot.element("stageCard-deep_scan").words)
    // Discovery: hosts with no name yet say a name is still coming.
    XCTAssertTrue(robot.element("foundHost-192.168.50.1").waitForExistence(timeout: 6))
    XCTAssertTrue(robot.element("foundHost-192.168.50.1").words.contains("Resolving name…"))
    XCTAssertTrue(robot.element("liveScanSubtitle").text.contains("Stage 1 of 2"), robot.element("liveScanSubtitle").text)
    robot.capture("live-scan-discovery", in: self)
    // Done: back to Devices with no one dismissing anything.
    XCTAssertTrue(robot.table.waitForExistence(timeout: 60), "the scan never handed back")
    XCTAssertFalse(robot.element("liveScan").exists)
  }

  @MainActor
  func testStoppedKeepsWhatItFound() {
    let robot = ZhenRobot.launch(scanPace: 800)
    robot.waitFor("deviceTable")
    robot.press("r", .command, expecting: "liveScan")
    XCTAssertTrue(robot.element("foundHost-192.168.50.10").waitForExistence(timeout: 8))
    robot.press(".", .command, expecting: "showDevicesButton")
    let subtitle = robot.element("liveScanSubtitle").text
    XCTAssertTrue(subtitle.hasPrefix("Stopped after 0:0"), subtitle)
    XCTAssertTrue(subtitle.hasSuffix("devices found"), subtitle)
    XCTAssertTrue(robot.element("foundHost-192.168.50.1").exists, "stopping discarded the results")
    XCTAssertFalse(robot.element("foundHost-192.168.50.1").words.contains("Resolving"), "a stopped scan claims a name is coming")
    XCTAssertTrue(robot.element("scanAgainButton").exists)
    robot.capture("live-scan-stopped", in: self)
    // Scan Again starts over from the takeover.
    robot.element("scanAgainButton").clickCentre()
    let restarted = NSPredicate { _, _ in robot.element("liveScanSubtitle").text.hasPrefix("Stage") }
    wait(for: [XCTNSPredicateExpectation(predicate: restarted, object: nil)], timeout: 10)
  }

  /// Gate: degradations do not evaporate. The partial fixture's scan degrades during
  /// naming; after the hand-back, Devices still says so, with the same rows.
  @MainActor
  func testDegradationsSurviveTheHandBack() {
    let robot = ZhenRobot.launch(fixture: "partial", scanPace: 1_200)
    robot.waitFor("deviceTable")
    robot.press("r", .command, expecting: "liveScan")
    // Naming starts after 13 hosts at 1.2 s; the degradation arrives with it.
    XCTAssertTrue(robot.element("degradationBanner").waitForExistence(timeout: 25), "the degradation never reached the live scan")
    XCTAssertTrue(robot.table.waitForExistence(timeout: 30), "the scan never handed back")
    robot.waitFor("partialRunNotice")
    XCTAssertTrue(robot.element("scanStatus").words.hasPrefix("Partial results"), "a green dot over an incomplete scan")
    robot.element("partialRunDisclosure").clickCentre()
    robot.waitFor("degradationBanner")
    XCTAssertTrue(robot.element("degradation-1").words.contains("No names could be read"), robot.element("degradation-1").words)
  }
}
