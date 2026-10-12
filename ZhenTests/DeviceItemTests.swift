import Foundation
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// The rules behind the Devices table: identity, order, what a row says, and the column
/// widths it is measured to.
struct DeviceItemTests {
  let capture: ScanReport
  let rows: [DeviceItem]

  init() async throws {
    capture = try FixtureNetwork.capture()
    let store = InMemoryHistoryStore()
    for report in FixtureNetwork.history(.home, capture: capture, now: .now) { _ = await store.record(report) }
    rows = DeviceItem.rows(from: await store.devices(), network: capture.run.target)
  }

  @Test("Every row has its own identity, and none is an address alone when a MAC exists")
  func identities() {
    #expect(Set(rows.map(\.id)).count == rows.count)
    for row in rows where row.device.mac != nil {
      #expect(!row.id.hasPrefix("ip_lease"), "\(row.id) is keyed on its lease")
    }
  }

  @Test("A device that moved address keeps its identity")
  func identitySurvivesAMove() throws {
    var device = try #require(capture.devices.first { $0.mac?.isLocallyAdministered == true && $0.ipv4Addresses.count == 1 })
    let before = DeviceItem.identity(of: device, in: capture.run.target)
    let v4 = try #require(device.ipv4Addresses.first)
    device.addresses = [.v4(IPv4Address(raw: v4.raw + 1))]
    #expect(DeviceItem.identity(of: device, in: capture.run.target) == before)
  }

  @Test("Default order: online first, then most recently seen")
  func defaultOrder() {
    let sorted = rows.sorted(using: DeviceItem.defaultOrder)
    let firstOffline = sorted.firstIndex { !$0.isOnline } ?? sorted.count
    #expect(sorted[firstOffline...].allSatisfy { !$0.isOnline })
    let offline = sorted[firstOffline...].map(\.lastSeen)
    #expect(offline == offline.sorted(by: >))
  }

  @Test("An unidentified device says what is known, never nothing")
  func unidentifiedSubtitle() throws {
    let anonymous = try #require(rows.first { $0.isUnidentified && $0.isPrivateMAC && $0.device.discoveredVia.contains(.probeReply) })
    #expect(anonymous.subtitle == "Randomized MAC · no vendor · responds to ping")
    for row in rows { #expect(!row.subtitle.isEmpty) }
  }

  @Test("A model string keeps its capitals; ARP stays ARP")
  func subtitleCasing() {
    #expect(rows.contains { $0.subtitle.hasPrefix("AppleTV5,3") })
    #expect(rows.contains { $0.subtitle.contains("in ARP table") })
  }

  @Test("An absent device whose address an answering one now holds is marked reassigned")
  func reassignment() throws {
    var gone = try #require(capture.devices.first { $0.mac?.isLocallyAdministered == false && $0.names.isEmpty && !$0.ipv4Addresses.isEmpty })
    let present = try #require(capture.devices.first { $0.mac?.isLocallyAdministered == true && !$0.ipv4Addresses.isEmpty })
    gone.addresses = present.addresses
    let rows = DeviceItem.rows(
      from: [StoredDevice(device: present, isPresent: true), StoredDevice(device: gone, isPresent: false)],
      network: capture.run.target
    )
    #expect(rows.map(\.isReassigned) == [false, true])
  }

  @Test("A link-local address loses its scope in the table and keeps it in the full form")
  func linkLocalAddress() throws {
    let v6only = try #require(rows.first { $0.device.ipv4Addresses.isEmpty })
    #expect(!v6only.address.contains("%"))
    #expect(v6only.fullAddress.contains("%"))
  }

  @Test("Columns are measured: a longer address widens the address column and nothing else")
  @MainActor
  func columnsAreMeasured() throws {
    let short = rows.filter { !$0.device.ipv4Addresses.isEmpty }
    let narrow = DevicesView.ColumnWidths(rows: short, now: .now)
    let wide = DevicesView.ColumnWidths(rows: rows, now: .now)
    #expect(wide.address > narrow.address)
    #expect(wide.identity == narrow.identity)
    #expect(wide.minimumTable > narrow.minimumTable)
  }

  @Test("Search matches names, what is known, addresses and MACs, ignoring case and accents")
  func search() {
    func count(_ term: String) -> Int { rows.count { $0.matches(term) } }
    #expect(count("") == rows.count)
    #expect(count("sala de ESTAR") == 1)
    #expect(count("Sala de estar principal  ") == 1)
    #expect(count("randomized") >= 3)
    #expect(count("00:00:5e") >= 3)
    #expect(count("unidentified") >= 5)
    #expect(count("nothing like this") == 0)
  }

  @Test("Sorting by address is numeric: .1 before .10 before .13, IPv4 before IPv6")
  func addressOrder() {
    let sorted = rows.sorted(using: [KeyPathComparator(\DeviceItem.addressSortKey)]).map(\.address)
    let v4 = sorted.prefix { !$0.contains(":") }
    #expect(v4.map { Int($0.split(separator: ".").last ?? "") ?? 0 } == v4.map { Int($0.split(separator: ".").last ?? "") ?? 0 }.sorted())
    #expect(sorted.drop { !$0.contains(":") }.allSatisfy { $0.contains(":") })
  }
}

/// The Devices table's sort, as the window stores it.
@MainActor
struct SortStorageTests {
  @Test("Every column round-trips in both directions; the default order is stored as nothing")
  func roundTrip() {
    #expect(DevicesView.SortStorage.encode(DeviceItem.defaultOrder) == "")
    #expect(DevicesView.SortStorage.decode("") == DeviceItem.defaultOrder)
    for column in DevicesView.SortStorage.columns {
      for order in [SortOrder.forward, .reverse] {
        var comparator = column.comparator
        comparator.order = order
        let text = DevicesView.SortStorage.encode([comparator])
        #expect(DevicesView.SortStorage.decode(text) == [comparator], "\(column.name) \(order) stored as '\(text)'")
      }
    }
    #expect(DevicesView.SortStorage.decode("nonsense") == DeviceItem.defaultOrder)
  }
}
