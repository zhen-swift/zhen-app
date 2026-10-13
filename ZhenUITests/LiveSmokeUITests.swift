import XCTest

/// The real engine, end to end, on the network this Mac is on. Never part of `test`: it
/// probes a real network, so it runs only when `ZHEN_LIVE_HISTORY` names a scratch history
/// file (`TEST_RUNNER_ZHEN_LIVE_HISTORY=… xcodebuild test -only-testing:…`). Every other
/// UI test runs on the fixture; this is the one that proves the live path does what the
/// fixture path promises.
final class LiveSmokeUITests: XCTestCase {
  var history: String!

  override func setUpWithError() throws {
    continueAfterFailure = false
    let path = ProcessInfo.processInfo.environment["ZHEN_LIVE_HISTORY"] ?? ""
    try XCTSkipIf(path.isEmpty, "live smoke runs only with ZHEN_LIVE_HISTORY set to a scratch history file")
    history = path
  }

  @MainActor
  func testScanThenPortScanOneDevice() {
    let app = XCUIApplication()
    // Live data: no -UITesting, no fixture. History is the scratch file, never the real one.
    app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(en)"]
    app.launchEnvironment["ZHEN_HISTORY"] = history
    app.launch()
    let robot = ZhenRobot(app: app)
    robot.waitFor("deviceTable", timeout: 20)

    robot.press("r", .command, expecting: "liveScan")
    let done = NSPredicate { _, _ in robot.element("scanStatus").words.contains("just now") }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: done, object: nil)], timeout: 60), .completed,
                   "the live scan did not finish: \(robot.element("scanStatus").words)")
    let summary = robot.window.title
    XCTContext.runActivity(named: "after the scan: \(summary)") { _ in }
    XCTAssertFalse(summary.contains(" 0 online"), "the live scan found nothing online: \(summary)")

    // The first row, by a click: after the scan hands back, the table may not hold focus,
    // and no real address belongs in a committed test.
    let first = robot.rows.first
    XCTAssertNotNil(first, "no rows after the scan")
    first?.clickCentre()
    robot.key("r", [.command, .shift])
    let finished = NSPredicate { _, _ in
      robot.element("noOpenPorts").exists || robot.element("portScanFailure").exists
        || robot.element("portsCard").staticTexts.allElementsBoundByIndex.contains { $0.text.hasPrefix("Checked") }
    }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: finished, object: nil)], timeout: 60), .completed,
                   "the port scan never finished")
    let card = robot.element("portsCard").staticTexts.allElementsBoundByIndex.map(\.text).joined(separator: " | ")
    XCTContext.runActivity(named: "ports card: \(card)") { _ in }
    XCTAssertEqual(robot.window.title.contains(" online"), true)
    XCTAssertFalse(robot.window.title.contains(" 0 online"), "the port scan took the network offline")
    robot.key("[", .command)
    robot.waitFor("deviceTable")
    XCTAssertEqual(robot.window.title, summary, "a port scan changed the network's counts: \(robot.window.title)")
    robot.capture("live-detail", in: self)
    app.terminate()
  }
}
