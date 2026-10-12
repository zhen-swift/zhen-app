import XCTest

/// Apple's own accessibility audit (`performAccessibilityAudit`) on every screen: contrast,
/// element descriptions, roles, hit regions, clipped text, actions, parent/child structure.
/// The hand-written audit beside it (`AccessibilityAuditUITests`) checks the project's rule
/// — every control has an identifier and a name; this checks the platform's.
///
/// Its first run found 39 issues (phase 3, part 2). Ours are fixed: combined elements had
/// no role, the device and found-host lists no name, the footer's dot said "Merged" while
/// scanning, and the partial-run strip's title failed contrast on a translucent bar. What
/// is excused below is drawn by AppKit or SwiftUI, out of reach of any modifier, each
/// matched exactly and said why.
final class SystemAccessibilityAuditUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = true
  }

  /// An issue the platform owns. Matched on everything known about it, so a new issue of
  /// the same kind on an element of ours still fails.
  private struct Excused {
    let type: XCUIAccessibilityAuditType
    let element: XCUIElement.ElementType
    let identifier: String
    let label: String
    let why: String
  }

  private let excused: [Excused] = [
    Excused(type: .action, element: .popUpButton, identifier: "scanIntervalPicker", label: "Scan automatically",
            why: "a SwiftUI Picker in a grouped Form: AppKit's NSPopUpButton, whose actions SwiftUI sets; .menu style made no difference"),
    Excused(type: .action, element: .popUpButton, identifier: "scanBudgetPicker", label: "Scan for up to", why: "as above"),
    Excused(type: .action, element: .popUpButton, identifier: "retentionPicker", label: "Keep events for", why: "as above"),
    Excused(type: .action, element: .popUpButton, identifier: "", label: "emoji & symbols",
            why: "the system's Edit ▸ Emoji & Symbols input item, not this app's"),
    Excused(type: .sufficientElementDescription, element: .popUpButton, identifier: "", label: "emoji & symbols", why: "as above"),
    Excused(type: .sufficientElementDescription, element: .touchBar, identifier: "", label: "", why: "the system Touch Bar host"),
  ]

  /// Audits what is on screen, failing on every issue not excused above.
  @MainActor
  private func audit(_ robot: ZhenRobot, _ screen: String, window: XCUIElement? = nil) {
    // Frames of everything in the window under audit, when one is named: the audit covers
    // every window, and the main window's text behind Settings "fails contrast" against
    // Settings' pixels. (Closing the main window instead quits the app: one `Window`.)
    let inWindow = window.map { Set($0.descendants(matching: .any).allElementsBoundByIndex.map { NSStringFromRect($0.frame) }) }
    do {
      try robot.app.performAccessibilityAudit(for: .all) { issue in
        if let inWindow, let element = issue.element, !inWindow.contains(NSStringFromRect(element.frame)) { return true }
        guard let element = issue.element else {
          // A structural finding with no element: the window chrome's parent/child check.
          if issue.auditType == .parentChild { return true }
          XCTFail("\(screen): \(issue.auditType) — \(issue.compactDescription) — no element — \(issue.detailedDescription)")
          return true
        }
        if self.excused.contains(where: {
          $0.type == issue.auditType && $0.element == element.elementType
            && $0.identifier == element.identifier && $0.label == element.label
        }) { return true }
        // AppKit's title-bar buttons: 14 pt groups at a window's top-left corner.
        if issue.auditType == .parentChild, element.elementType == .group, element.frame.width <= 16 { return true }
        // A container: SwiftUI's own groups for a window, a split view column, a table cell
        // or a list section. VoiceOver reads what is inside, so it needs no name of its own
        // — as long as what is inside has one. A group with nothing named inside still fails.
        if issue.auditType == .sufficientElementDescription || issue.auditType == .parentChild,
           element.elementType == .group, element.identifier.isEmpty, Self.hasNamedDescendant(element) {
          return true
        }
        // Contrast is judged by WCAG AA, 4.5:1, measured on the element's own pixels — the
        // standard the palette is held to (`PaletteContrastTests`). The audit is stricter
        // for small text and flagged the sidebar, "Minimal" and the `private` chip at
        // 4.56–5.60:1 measured; it also sampled through vibrancy differently run to run.
        // Below 4.5 fails. Text scrolled out of the window is not on screen to measure.
        if issue.auditType == .contrast {
          let window = robot.window.frame
          guard window.contains(element.frame) else { return true }
          let ratio = Self.contrast(of: element)
          // The selected sidebar row is filled with the person's own system accent, white
          // text on top, by AppKit; the app's accent is used only under "Multicolour". This
          // Mac's is green: 3.92:1, measured. Not the app's to change — `SystemAccent`
          // covers the Multicolour case (`PaletteContrastTests.whiteOnSystemAccent`).
          if element.identifier.hasPrefix("sidebarRoom-"),
             robot.app.outlineRows.containing(.any, identifier: element.identifier).firstMatch.isSelected {
            XCTContext.runActivity(named: "\(screen): selected sidebar row, system accent, \(String(format: "%.2f", ratio)):1") { _ in }
            return true
          }
          if ratio < 4.5 {
            let shot = XCTAttachment(screenshot: element.screenshot())
            shot.name = "contrast-\(screen)-\(element.identifier)"
            shot.lifetime = .keepAlways
            self.add(shot)
            let window = XCTAttachment(screenshot: robot.window.screenshot())
            window.name = "contrast-window-\(screen)"
            window.lifetime = .keepAlways
            self.add(window)
          }
          XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(screen): '\(element.label)' \(element.frame) measures \(String(format: "%.2f", ratio)):1")
          return true
        }
        let measured = issue.auditType == .contrast ? String(format: " — measured %.2f:1", Self.contrast(of: element)) : ""
        XCTFail("\(screen): \(issue.auditType) — \(issue.compactDescription) — \(element.elementType.rawValue) '\(element.identifier)' '\(element.label)' \(element.frame)\(measured)")
        return true
      }
    } catch {
      XCTFail("\(screen): the audit did not run: \(error)")
    }
  }

  @MainActor
  private static func hasNamedDescendant(_ element: XCUIElement) -> Bool {
    element.descendants(matching: .any).allElementsBoundByIndex.prefix(200).contains {
      !$0.label.isEmpty || !$0.title.isEmpty || !(($0.value as? String) ?? "").isEmpty
    }
  }

  /// WCAG contrast between the text and the background of an element's own pixels: the
  /// most common luminance is the background, the one farthest from it is the text.
  @MainActor
  private static func contrast(of element: XCUIElement) -> Double {
    guard let image = element.screenshot().image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return 0 }
    let perPixel = image.bitsPerPixel / 8
    var counts: [Int: Int] = [:]
    var luminances: [Double] = []
    func linear(_ value: UInt8) -> Double {
      let c = Double(value) / 255
      return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    for y in 0..<image.height {
      for x in 0..<image.width {
        let offset = y * image.bytesPerRow + x * perPixel
        // BGRA or RGBA: luminance weights the outer two alike enough for a ratio test.
        let l = 0.2126 * linear(bytes[offset + 2]) + 0.7152 * linear(bytes[offset + 1]) + 0.0722 * linear(bytes[offset])
        luminances.append(l)
        counts[Int(l * 1000), default: 0] += 1
      }
    }
    guard let mode = counts.max(by: { $0.value < $1.value })?.key else { return 0 }
    let background = Double(mode) / 1000
    let text = luminances.max { abs($0 - background) < abs($1 - background) } ?? background
    let (light, dark) = (max(text, background), min(text, background))
    return (light + 0.05) / (dark + 0.05)
  }

  @MainActor
  func testEveryScreen() {
    // Slow enough that the scan is still running after the audit of it, which takes up to
    // 18 s: at 900 ms a step the scan finished first, and Stop had nothing to stop.
    let robot = ZhenRobot.launch(scanPace: 2_500)
    robot.waitFor("deviceTable")
    audit(robot, "Devices")
    robot.openDevice("192.168.50.10")
    audit(robot, "Detail")
    robot.press("[", .command, expecting: "deviceTable")
    robot.press("2", .command, expecting: "activityList")
    audit(robot, "Activity")
    robot.press("1", .command, expecting: "deviceTable")
    robot.press("r", .command, expecting: "liveScan")
    audit(robot, "Live scan")
    robot.press(".", .command, expecting: "showDevicesButton")
    robot.key(.escape)
    robot.press(",", .command, expecting: "settings")
    audit(robot, "Settings", window: robot.app.windows.containing(.any, identifier: "settings").firstMatch)
  }

  @MainActor
  func testEmptyAndDegradedStates() {
    for (fixture, identifier) in [("empty", "neverScanned"), ("silent", "nothingAnswered"), ("partial", "partialRunNotice")] {
      let robot = ZhenRobot.launch(fixture: fixture)
      robot.waitFor(identifier)
      audit(robot, fixture)
      robot.app.terminate()
    }
  }
}
