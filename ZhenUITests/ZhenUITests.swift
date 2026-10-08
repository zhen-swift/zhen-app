import XCTest

final class ZhenUITests: XCTestCase {
  @MainActor
  func testLaunches() {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
  }
}
