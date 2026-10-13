import Foundation
import Testing
import ZhenCore

@testable import Zhen

/// The settings a scan reads, and the helper panel's states.
@MainActor
struct SettingsTests {
  @Test("A subnet override is a CIDR network /16 or narrower, or nothing", arguments: [
    ("192.168.1.0/24", true), (" 10.0.0.0/16 ", true), ("10.0.0.0/8", false),
    ("192.168.1.1", false), ("nonsense", false), ("", false),
  ])
  func subnet(_ text: String, _ valid: Bool) {
    #expect((Preferences.network(text) != nil) == valid)
  }

  @Test("Preferences read what Settings writes")
  func preferences() throws {
    let defaults = try #require(UserDefaults(suiteName: "zhen.settings.tests"))
    defaults.removePersistentDomain(forName: "zhen.settings.tests")
    defaults.set(15, forKey: Preferences.Key.scanInterval)
    defaults.set("192.168.7.0/24", forKey: Preferences.Key.subnetOverride)
    defaults.set(true, forKey: Preferences.Key.deepScan)
    let read = Preferences(defaults)
    #expect(read.scanIntervalMinutes == 15)
    #expect(read.subnetOverride?.description == "192.168.7.0/24")
    #expect(read.deepScanNewDevices)
    #expect(read.portStage == .newHosts, "\"Deep-scan new devices\" probes more than new devices")
  }

  /// Gate. Break: map the toggle to `.everyHost` in `Preferences.portStage` — the
  /// relabelled "Check ports on every scan" that zhen-core 0.6.0 forced.
  @Test("Scan Now uses them: deep scan of new devices and the override reach the request")
  func scanUsesPreferences() {
    let model = PreviewContainer.model(.home)
    model.startScan()
    #expect(model.scan.request.ports == .off, "a port stage nobody asked for")
    model.stopScanning()
    model.defaults.set(true, forKey: Preferences.Key.deepScan)
    model.defaults.set("192.168.7.0/24", forKey: Preferences.Key.subnetOverride)
    model.startScan()
    #expect(model.scan.request.ports == .newHosts)
    #expect(model.scan.request.network?.description == "192.168.7.0/24")
    model.defaults.removeObject(forKey: Preferences.Key.deepScan)
    model.defaults.removeObject(forKey: Preferences.Key.subnetOverride)
  }

  @Test("The fake helper walks the three states and back, registering nothing")
  func helperStates() async throws {
    let helper = FakeHelperService()
    #expect(helper.state == .notInstalled)
    try helper.install()
    #expect(helper.state == .requiresApproval)
    helper.openLoginItems()
    #expect(helper.state == .installed)
    try await helper.uninstall()
    #expect(helper.state == .notInstalled)
  }
}
