import XCTest

/// Gate: the acceptance case. Every host unidentified — randomised MAC, no name, no vendor,
/// no model — is a normal list: every row the same height, every column standing, every
/// name saying what it is rather than nothing. At the default size and at the minimum.
final class AcceptanceUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testEveryHostUnidentified() {
    let robot = ZhenRobot.launch(fixture: "unidentified")
    robot.waitFor("deviceTable")
    assertNormalList(robot, at: "default size")
    robot.capture("unidentified-default", in: self)
    robot.shrinkToMinimum()
    assertNormalList(robot, at: "minimum")
    robot.capture("unidentified-minimum", in: self)
  }

  @MainActor
  private func assertNormalList(_ robot: ZhenRobot, at size: String) {
    // Whole rows only: one the scroll view cuts in half reports its visible height.
    let visible = robot.table.frame
    let rows = robot.rows.filter {
      !$0.cells.allElementsBoundByIndex.isEmpty && visible.contains($0.frame)
    }
    XCTAssertGreaterThanOrEqual(rows.count, 8, "too few rows to judge at \(size)")
    let heights = Set(rows.map { $0.frame.height.rounded() })
    XCTAssertEqual(heights.count, 1, "row heights vary at \(size): \(heights.sorted())")
    for (index, row) in rows.enumerated() {
      let cells = row.cells.allElementsBoundByIndex
      XCTAssertEqual(cells.count, 5, "row \(index) lost a column at \(size)")
      for cell in cells {
        XCTAssertGreaterThan(cell.frame.width, 20, "row \(index) has a collapsed column at \(size)")
      }
      let name = row.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'deviceName-'")).firstMatch
      XCTAssertTrue(name.label.hasPrefix("Unidentified device"), "row \(index) names itself '\(name.label)'")
    }
  }
}
