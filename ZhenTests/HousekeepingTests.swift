import Foundation
import Testing
import ZhenCore

@testable import Zhen

/// Phase 3, stage 3: export, the Settings header, retention at launch.
@MainActor
struct HousekeepingTests {
  /// Gate. Break: drop `events` from `HistoryExport`'s encoding (rename the property).
  @Test("An export holds every device, with its shown name and presence, and every event")
  func exportHoldsEverything() async throws {
    let model = await ScanningBehaviourTests.loadedModel()
    let data = try #require(model.exportDocument()?.data)
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["format"] as? String == "zhen-app-history")
    let devices = try #require(json["devices"] as? [[String: Any]])
    #expect(devices.count == model.devices.count)
    #expect(devices.count { ($0["online"] as? Bool) == true } == model.onlineCount)
    #expect(devices.contains { ($0["device"] as? [String: Any])?["mac"] != nil })
    let events = try #require(json["events"] as? [[String: Any]])
    #expect(events.count == model.events.count)
    #expect(json["latestRun"] != nil)
  }

  @Test("The export's name carries the date")
  func exportName() {
    #expect(NetworkModel.exportFilename.hasPrefix("Zhen history 20"))
  }

  @Test("Settings' version line is the bundle's")
  func versionLine() {
    #expect(SettingsView.versionLine.hasPrefix("Zhen "))
    #expect(SettingsView.versionLine.contains("("))
  }

  /// Gate. Break: drop the `applyRetention` call from `NetworkModel.load()`.
  @Test("Retention from Settings reaches the store at launch, Settings never opened")
  func retentionAtLaunch() async throws {
    let environment = AppEnvironment.parse(arguments: ["-Fixture", "home", "-UITesting"], environment: [:], now: .now)
    let suite = "zhen.housekeeping.tests"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(7, forKey: Preferences.Key.retentionDays)
    let model = NetworkModel(environment: environment, defaults: defaults)
    await model.load()
    // The fixture's history spans 48 hours; record one more run dated nine days on and
    // everything older than seven days is pruned only if the policy reached the store.
    // Nine days after the fixture's last run — not after the capture's own date, which
    // is months earlier and made the first version of this test pass with the policy
    // never applied.
    let last = try #require(await model.store.latestRun())
    var later = try FixtureNetwork.capture()
    later.run.id = UUID()
    later.run.startedAt = Timestamp(millisecondsSinceEpoch: last.startedAt.millisecondsSinceEpoch + 9 * 86_400_000)
    later.run.finishedAt = later.run.startedAt
    let before = await model.store.events().count
    _ = await model.store.record(later)
    let after = await model.store.events()
    let cutoff = later.run.startedAt.millisecondsSinceEpoch - 7 * 86_400_000
    #expect(after.allSatisfy { $0.at.millisecondsSinceEpoch >= cutoff }, "events older than 7 days survived: retention never reached the store")
    #expect(before > 0)
  }
}

/// Phase 3, stage 5: counted strings take their plural from `Localizable.xcstrings`.
@MainActor
struct PluralTests {
  /// Gate. Break: drop the `one` variation of `identityChanges` from the catalogue.
  @Test("One of a thing is singular, through the catalogue")
  func singular() {
    #expect(String(localized: .identityChanges(1)) == "1 identity change")
    #expect(String(localized: .identityChanges(2)) == "2 identity changes")
    #expect(String(localized: .devicesOnlineUnidentified(devices: 1, 1, 0)) == "1 device · 1 online · 0 unidentified")
    #expect(String(localized: .stoppedAfterDevicesFound("0:05", devices: 1)) == "Stopped after 0:05 · 1 device found")
  }
}
