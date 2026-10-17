import Foundation
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// The invented network the marketing captures show (`-ShowcaseData`). It was written, not
/// scanned, so these hold it to what a scan could have reported: core's identification
/// rules, documentation-range identifiers, and a history with every kind of event.
struct ShowcaseFixtureTests {
  let capture: ScanReport

  init() throws {
    capture = try FixtureNetwork.capture(.showcase)
  }

  @Test("The showcase capture decodes with this zhen-core's schema")
  func decodes() throws {
    try capture.validateSchema()
    #expect(capture.devices.count >= 12)
  }

  @Test("Only synthetic addresses: documentation MACs, locally administered MACs, 192.168.50.0/24")
  func onlySyntheticIdentifiers() {
    for device in capture.devices {
      if let mac = device.mac {
        #expect(mac.isLocallyAdministered || mac.description.hasPrefix("00:00:5E:00:53"))
      }
      for v4 in device.ipv4Addresses {
        #expect(IPv4Network(base: IPv4Address(raw: 0xC0A8_3200), prefix: 24).contains(v4))
      }
    }
  }

  /// Gate. Break: mark a device without a vendor `"has_vendor": true` in the JSON.
  @Test("Every device claims only what its evidence supports, by core's own rules")
  func evidenceIsCores() {
    for device in capture.devices {
      let evidence = IdentificationEvidence(facts: FixtureScanRunner.facts(device, named: true))
      #expect(device.identificationEvidence == evidence, "\(device.primaryAddress)")
      #expect(device.identification == Identification(evidence: evidence), "\(device.primaryAddress)")
      let keys = HostIdentifier.candidates(for: device, in: capture.run.target)
      #expect(device.identityStability == Stability(strongestOf: keys), "\(device.primaryAddress)")
    }
  }

  @Test("Mostly named, with vendors, and still some honestly unnamed")
  func mostlyIdentified() {
    let identified = capture.devices.filter { $0.identification == .identified }
    #expect(Double(identified.count) / Double(capture.devices.count) >= 0.7)
    #expect(capture.devices.contains { $0.displayName == nil })
    for device in capture.devices where device.mac?.isLocallyAdministered == false {
      #expect(device.vendor != nil, "a universal MAC has a vendor: \(device.primaryAddress)")
    }
  }

  @Test("Every part in the history is played by a device the capture has")
  func castIsComplete() {
    let cast = FixtureNetwork.Dataset.showcase.cast(for: capture.devices)
    let parts = [cast.mover, cast.lateArrival, cast.lastArrival, cast.speaker, cast.television, cast.leaver, cast.router]
    #expect(parts.allSatisfy { $0 != nil })
    #expect(Set(parts).count == parts.count, "one device plays two parts")
  }

  /// Gate. Break: drop the router from the showcase cast in `FixtureNetwork.Dataset`.
  @Test("48 hours of showcase history derive every event kind the store can emit but merged")
  func historyDerivesEvents() async {
    let store = InMemoryHistoryStore()
    for report in FixtureNetwork.history(.home, capture: capture, dataset: .showcase, now: .now) {
      _ = await store.record(report)
    }
    let expected: Set<DerivedEvent.Kind> = [.appeared, .disappeared, .ipChanged, .renamed, .portOpened, .portClosed]
    let kinds = Set(await store.events().map(\.kind))
    #expect(kinds.isSuperset(of: expected), "missing: \(expected.subtracting(kinds))")
  }

  @Test("Stripped, the showcase network has no name, vendor or model anywhere")
  func unidentifiedVariant() throws {
    let latest = try #require(FixtureNetwork.history(.unidentified, capture: capture, dataset: .showcase, now: .now).last)
    #expect(!latest.devices.isEmpty)
    for device in latest.devices {
      #expect(device.names.isEmpty && device.vendor == nil && device.displayModel == nil)
      #expect(device.mac?.isLocallyAdministered ?? true)
    }
  }

  @Test("-ShowcaseData loads the showcase network; -UITesting keeps the home one")
  func launchArgumentsChooseTheDataset() {
    let showcase = AppEnvironment.parse(arguments: ["-ShowcaseData"], environment: [:], now: .now)
    #expect(showcase.fixtureDataset == .showcase)
    #expect(showcase.dataSource == .fixture(.home))
    let stripped = AppEnvironment.parse(arguments: ["-Fixture", "unidentified", "-ShowcaseData"], environment: [:], now: .now)
    #expect(stripped.fixtureDataset == .showcase && stripped.dataSource == .fixture(.unidentified))
    let testing = AppEnvironment.parse(arguments: ["-UITesting"], environment: [:], now: .now)
    #expect(testing.fixtureDataset == .home)
  }
}
