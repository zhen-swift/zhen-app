import Foundation
import Testing
import ZhenCore

@testable import Zhen

/// Part 3: a device seen for the first time is announced, once, after the app's own scan.
@MainActor
struct NewDeviceNoticeTests {
  func item(_ id: String, firstSeen: Date, from capture: ScanReport) throws -> DeviceItem {
    var device = try #require(capture.devices.first)
    device.firstSeen = Timestamp(millisecondsSinceEpoch: Int64(firstSeen.timeIntervalSince1970 * 1000))
    return DeviceItem(id: id, device: device, isOnline: true, userName: nil, isReassigned: false)
  }

  @Test("New means unknown before the scan and first seen during it; never on a first scan")
  func whatCountsAsNew() throws {
    let capture = try FixtureNetwork.capture()
    let start = Date.now
    let joined = try item("joined", firstSeen: start.addingTimeInterval(2), from: capture)
    let rekeyed = try item("rekeyed", firstSeen: start.addingTimeInterval(-86_400), from: capture)
    let old = try item("old", firstSeen: start.addingTimeInterval(-86_400), from: capture)
    let all = [joined, rekeyed, old]
    #expect(NewDeviceNotice.newDevices(all, knownBefore: ["old"], scanStarted: start).map(\.id) == ["joined"],
            "a re-keyed device, known for a day, was announced as new")
    #expect(NewDeviceNotice.newDevices(all, knownBefore: [], scanStarted: start).isEmpty, "the first scan announced everything")
  }

  @Test("Up to three get a notification each; more get one summary")
  func summary() throws {
    let capture = try FixtureNetwork.capture()
    let four = try (1...4).map { try item("d\($0)", firstSeen: .now, from: capture) }
    #expect(NewDeviceNotice.messages(for: Array(four.prefix(3))).count == 3)
    let summary = NewDeviceNotice.messages(for: four)
    #expect(summary.count == 1)
    #expect(summary.first?.title == "4 new devices on your network")
  }

  /// Gate, end to end: a scan that finds a device history has never seen posts one notice
  /// naming it — and posts nothing when the setting is off. Break: drop the post loop in
  /// `NetworkModel.performScan`.
  @Test("A scan that finds a new device posts one notice, only when asked for")
  func endToEnd() async throws {
    for enabled in [true, false] {
      let suite = "zhen.notice.tests"
      let defaults = try #require(UserDefaults(suiteName: suite))
      defaults.removePersistentDomain(forName: suite)
      defaults.set(enabled, forKey: Preferences.Key.notifyNewDevices)
      let environment = AppEnvironment.parse(
        arguments: ["-Fixture", "home", "-ScanPace", "1", "-NewDeviceOnScan", "-UITesting"], environment: [:], now: .now
      )
      let model = NetworkModel(environment: environment, defaults: defaults)
      await model.load()
      model.startScan()
      await model.performScan()
      let notifier = try #require(model.notifier as? FakeNotifier)
      if enabled {
        #expect(notifier.posted.count == 1, "\(notifier.posted)")
        #expect(notifier.posted.first?.title == "New device on your network")
        #expect(notifier.posted.first?.body.contains("192.168.50.44") == true)
      } else {
        #expect(notifier.posted.isEmpty, "posted with the setting off")
      }
      defaults.removePersistentDomain(forName: suite)
    }
  }
}
