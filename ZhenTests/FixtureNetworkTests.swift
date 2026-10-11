import Foundation
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// The fixture network: it decodes, it holds the acceptance case, and its history yields
/// every kind of event through core's own ledger.
struct FixtureNetworkTests {
  let capture: ScanReport

  init() throws {
    capture = try FixtureNetwork.capture()
  }

  @Test("The capture decodes with this zhen-core's schema")
  func decodes() throws {
    try capture.validateSchema()
    #expect(capture.devices.count >= 10)
  }

  @Test("It contains the acceptance case: several hosts with a randomised MAC and no name, vendor or model")
  func acceptanceCase() {
    let anonymous = capture.devices.filter {
      $0.mac?.isLocallyAdministered == true && $0.names.isEmpty && $0.vendor == nil && $0.displayModel == nil
    }
    #expect(anonymous.count >= 3)
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

  @Test("48 hours of history derive every event kind the store can emit but merged")
  func historyDerivesEvents() async {
    let store = InMemoryHistoryStore()
    for report in FixtureNetwork.history(.home, capture: capture, now: .now) {
      _ = await store.record(report)
    }
    let kinds = Set(await store.events().map(\.kind))
    #expect(kinds.isSuperset(of: [.appeared, .disappeared, .ipChanged, .renamed]))
    let devices = await store.devices()
    #expect(devices.contains { !$0.isPresent }, "some devices must be offline in the latest run")
  }

  @Test("The unidentified variant has no name, vendor or model anywhere, and every MAC randomised")
  func unidentifiedVariant() throws {
    let latest = try #require(FixtureNetwork.history(.unidentified, capture: capture, now: .now).last)
    #expect(!latest.devices.isEmpty)
    for device in latest.devices {
      #expect(device.names.isEmpty && device.vendor == nil && device.displayModel == nil)
      #expect(device.mac?.isLocallyAdministered ?? true)
      #expect(device.identification == .minimal)
    }
  }

  @Test("The silent variant degrades with core's Local Network sentence")
  func silentVariant() {
    let degradations = FixtureNetwork.degradations(.silent, capture: capture)
    #expect(degradations.count == 1)
    #expect(DegradationCopy(degradations[0]).action == .openLocalNetworkSettings)
  }
}
