import XCTest

/// Stage D: Activity's filter drives the list and the histogram together, and its two
/// empty states keep what they should.
final class ActivityUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  /// Every event row on screen.
  @MainActor
  private func eventRows(_ robot: ZhenRobot) -> Int {
    robot.element("activityList").descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH 'event-'")).count
  }

  /// The histogram's stated total.
  @MainActor
  private func histogramTotal(_ robot: ZhenRobot) -> Int {
    let value = robot.element("activityHistogram").words
    let number = value.split(separator: " ").compactMap { Int($0) }.first
    XCTAssertNotNil(number, "the histogram states no total: \(value)")
    return number ?? -1
  }

  /// Gate: the filter drives both. Under every segment, the histogram counts what the
  /// list shows — no more.
  @MainActor
  func testFilterDrivesListAndHistogram() {
    let robot = ZhenRobot.launch()
    robot.press("2", .command, expecting: "activityList")
    for (index, segment) in ["All", "Presence", "Identity", "Addresses"].enumerated() {
      let key = ["1", "2", "3", "5"][index]
      robot.key(key, [.command, .option])
      let agree = NSPredicate { _, _ in self.eventRows(robot) == self.histogramTotal(robot) && self.eventRows(robot) > 0 }
      let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: agree, object: nil)], timeout: 6)
      XCTAssertEqual(result, .completed, "\(segment): list shows \(eventRows(robot)), histogram counts \(histogramTotal(robot))")
    }
    robot.capture("activity-presence", in: self)
  }

  @MainActor
  func testFilterWithNoMatchKeepsItsContext() {
    let robot = ZhenRobot.launch()
    robot.press("2", .command, expecting: "activityList")
    robot.press("4", [.command, .option], expecting: "activityNoMatch")
    XCTAssertTrue(robot.element("activityNoMatch").words.contains("No port events in this window"), robot.element("activityNoMatch").words)
    XCTAssertTrue(robot.element("activityFilter").exists, "the segments went away")
    XCTAssertTrue(robot.element("activityHistogram").exists, "the histogram went away")
  }

  /// Phase 3, stage 2: Show in Activity used to keep whatever segment was selected, so a
  /// device's history arrived filtered by something nobody chose for it.
  @MainActor
  func testShowInActivityStartsFromAll() {
    let robot = ZhenRobot.launch()
    robot.press("2", .command, expecting: "activityList")
    robot.press("4", [.command, .option], expecting: "activityNoMatch")
    robot.press("1", .command, expecting: "deviceTable")
    robot.selectRowByKeyboard()
    robot.press("a", [.command, .shift], expecting: "activityList")
    XCTAssertFalse(robot.element("activityNoMatch").exists, "arrived under the Ports segment, showing nothing")
    XCTAssertGreaterThan(eventRows(robot), 0)
  }

  @MainActor
  func testNothingHasChanged() {
    let robot = ZhenRobot.launch(fixture: "empty")
    robot.press("2", .command, expecting: "activityEmpty")
    XCTAssertTrue(robot.element("activityEmpty").staticTexts["Nothing has changed"].exists)
  }
}
