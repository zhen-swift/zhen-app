import XCTest

/// Gate: four appearances. Every room in light, dark and both Increase Contrast looks,
/// attached to the result bundle — and checked, not just taken: a dark capture must be dark,
/// a light one light, and Increase Contrast must change pixels. A screenshot set where the
/// appearance argument was ignored would otherwise pass as four pictures of one look.
final class AppearanceUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testEveryRoomInEveryLook() throws {
    var surfaces: [ZhenRobot.Look: Double] = [:]
    var devicesShots: [ZhenRobot.Look: Data] = [:]
    for look in ZhenRobot.Look.allCases {
      let robot = ZhenRobot.launch(look: look, scanPace: 500)
      robot.waitFor("deviceTable")
      let shot = robot.window.screenshot()
      devicesShots[look] = shot.pngRepresentation
      surfaces[look] = try Self.luminance(of: shot.image, atFraction: CGPoint(x: 0.6, y: 0.97))
      robot.capture("devices-\(look.rawValue)", in: self)

      robot.press("2", .command, expecting: "activityList")
      robot.capture("activity-\(look.rawValue)", in: self)

      robot.press("1", .command, expecting: "deviceTable")
      robot.select(row: 1)
      robot.press("o", .command, expecting: "deviceDetail")
      robot.capture("detail-\(look.rawValue)", in: self)
      robot.key("[", .command)

      robot.press("r", .command, expecting: "liveScan")
      _ = robot.element("foundHost-192.168.50.1").waitForExistence(timeout: 5)
      robot.capture("livescan-\(look.rawValue)", in: self)
      robot.press(".", .command, expecting: "showDevicesButton")
      robot.key(.escape)

      robot.press(",", .command, expecting: "settings")
      // The Settings window, never the screen: a screen capture holds whatever else the
      // person has open, and these attachments are kept.
      let settingsWindow = robot.app.windows.containing(.any, identifier: "settings").firstMatch
      XCTAssertTrue(settingsWindow.exists, "no window holds the settings form")
      let settings = XCTAttachment(screenshot: settingsWindow.screenshot())
      settings.name = "settings-\(look.rawValue)"
      settings.lifetime = .keepAlways
      add(settings)
      robot.app.terminate()
    }

    let dark = try XCTUnwrap(surfaces[.dark])
    let light = try XCTUnwrap(surfaces[.light])
    XCTAssertLessThan(dark, 0.25, "the dark capture is not dark (surface luminance \(dark))")
    XCTAssertGreaterThan(light, 0.75, "the light capture is not light (surface luminance \(light))")
    XCTAssertNotEqual(devicesShots[.dark], devicesShots[.darkIncreased], "Increase Contrast changed nothing in dark")
    XCTAssertNotEqual(devicesShots[.light], devicesShots[.lightIncreased], "Increase Contrast changed nothing in light")
  }

  /// Relative luminance of one pixel, at a fraction of the image's size from its top left.
  static func luminance(of image: NSImage, atFraction point: CGPoint) throws -> Double {
    let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    let bitmap = NSBitmapImageRep(cgImage: cg)
    let x = Int(Double(bitmap.pixelsWide - 1) * point.x)
    let y = Int(Double(bitmap.pixelsHigh - 1) * point.y)
    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
    return 0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
  }
}
