import XCTest

/// App Store and README captures. Asset generation, not correctness: skipped unless
/// `ZHEN_SCREENSHOTS=1` reaches the runner (`TEST_RUNNER_ZHEN_SCREENSHOTS=1` on the
/// `xcodebuild` line, which `fastlane screenshots` sets), so `test` never runs it.
///
/// Each capture is the main window at 1440 × 900 points — 2880 × 1800 pixels on a Retina
/// display, the Mac's 16:10 slot — attached under its `Marketing/copy.json` id, the
/// contract between this file and the renderer. Every launch is `-ShowcaseData`: the
/// invented network `Scripts/make-showcase-fixture.py` writes, never a real one — not
/// even the anonymised home network the other UI tests run on.
final class AppStoreScreenshotUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["ZHEN_SCREENSHOTS"] == "1",
      "marketing captures run only from `fastlane screenshots`"
    )
  }

  @MainActor
  private func launch(fixture: String = "home", look: String = "dark", scanPace: Int = 40) -> XCUIApplication {
    let app = XCUIApplication()
    // `-ShowcaseData` takes no value, so it goes last (see `ZhenRobot.launch`).
    app.launchArguments = [
      "-Fixture", fixture, "-ScanPace", "\(scanPace)", "-Appearance", look,
      "-WindowSize", "1440x900", "-ApplePersistenceIgnoreState", "YES", "-ShowcaseData",
    ]
    app.launch()
    XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    app.activate()
    app.typeKey("1", modifierFlags: .command)
    return app
  }

  /// Waits for an element, then lets the window finish drawing. A capture taken the moment
  /// accessibility reports an element has come out half-drawn — placeholder rows and an
  /// empty sidebar (phase 2's Q7, seen again in phase 3).
  @MainActor
  private func settle(_ app: XCUIApplication, on identifier: String) {
    XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 15), "\(identifier) never appeared")
    Thread.sleep(forTimeInterval: 1.5)
  }

  @MainActor
  private func capture(_ app: XCUIApplication, _ id: String) {
    let window = app.windows.firstMatch
    let attachment = XCTAttachment(screenshot: window.screenshot())
    attachment.name = id
    attachment.lifetime = .keepAlways
    add(attachment)
    // The slot is exact: a window the screen could not fit makes an undersized capture,
    // which the renderer would refuse later. Say so here, where the cause is visible.
    XCTAssertEqual(window.frame.width, 1440, accuracy: 1, "\(id): window is \(window.frame.size)")
    XCTAssertEqual(window.frame.height, 900, accuracy: 1, "\(id): window is \(window.frame.size)")
  }

  @MainActor
  func testCaptures() {
    var app = launch()
    settle(app, on: "deviceTable")
    capture(app, "01-devices")

    // Living Room, the Apple TV: a name from Bonjour, a rename in its history, AirPlay's port.
    app.descendants(matching: .any)["deviceName-192.168.50.10"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
    settle(app, on: "deviceDetail")
    capture(app, "02-device-detail")
    app.terminate()

    // Mid-scan: discovery done, names arriving.
    app = launch(scanPace: 700)
    settle(app, on: "deviceTable")
    app.typeKey("r", modifierFlags: .command)
    XCTAssertTrue(app.descendants(matching: .any)["foundHost-192.168.50.71"].firstMatch.waitForExistence(timeout: 20))
    Thread.sleep(forTimeInterval: 2.5)
    capture(app, "03-live-scan")
    app.terminate()

    app = launch(look: "light")
    app.typeKey("2", modifierFlags: .command)
    settle(app, on: "activityList")
    capture(app, "04-activity")
    app.terminate()

    // The same invented network with every name, vendor and model stripped.
    app = launch(fixture: "unidentified", look: "light")
    settle(app, on: "deviceTable")
    capture(app, "05-unidentified")
    app.terminate()
  }
}
