import Foundation
import Testing
import ZhenCore

@testable import Zhen

/// The Devices table at the size of a /16, the widest network Zhen will scan: 65 534 hosts.
@MainActor
struct ScaleTests {
  static func rows(_ count: Int) throws -> [DeviceItem] {
    let capture = try FixtureNetwork.capture()
    let template = try #require(capture.devices.first { $0.mac?.isLocallyAdministered == true })
    return (0..<count).map { index in
      var device = template
      device.addresses = [.v4(IPv4Address(raw: 0x0A00_0000 + UInt32(index) + 1))]
      device.mac = MACAddress(raw: 0x0200_0000_0000 + UInt64(index))
      return DeviceItem(id: "d\(index)", device: device, isOnline: index.isMultiple(of: 3), userName: nil, isReassigned: false)
    }
  }

  /// Gate. Worked out once per change to the devices and once a minute. Measured in a
  /// Debug build (unoptimised): 5.2 s at 65 534 rows before, 0.135 s after. Break: measure
  /// every row's text again in `TextMeasure.widest`.
  @Test("Column widths for a /16 take under 250 ms in Debug", arguments: [10_000, 65_534])
  func columnWidths(_ count: Int) throws {
    let rows = try Self.rows(count)
    let clock = ContinuousClock()
    let start = clock.now
    let widths = DevicesView.ColumnWidths(rows: rows, now: .now)
    let took = clock.now - start
    print("ColumnWidths, \(count) rows: \(took)")
    #expect(widths.address > 0)
    #expect(took < .milliseconds(250), "\(count) rows took \(took)")
  }
}

extension ScaleTests {
  @Test("The computed address length is the written one", arguments: ["0.0.0.0", "10.0.0.1", "192.168.50.37", "255.255.255.255"])
  func addressLength(_ text: String) throws {
    var rows = try Self.rows(1)
    var device = rows[0].device
    device.addresses = [.v4(try #require(IPv4Address(text)))]
    rows[0] = DeviceItem(id: "a", device: device, isOnline: true, userName: nil, isReassigned: false)
    #expect(DevicesView.ColumnWidths.addressLength(rows[0]) == rows[0].address.count)
  }
}

extension ScaleTests {
  /// Gate. Break: drop the cache check in `ColumnWidths.cached`.
  @Test("Within a minute and with the devices unchanged, the widths are not worked out again")
  func cached() async throws {
    let model = await ScanningBehaviourTests.loadedModel()
    let now = Date.now
    _ = DevicesView.ColumnWidths.cached(for: model, now: now)
    let clock = ContinuousClock()
    let start = clock.now
    for _ in 0..<1_000 { _ = DevicesView.ColumnWidths.cached(for: model, now: now) }
    let took = clock.now - start
    #expect(took < .milliseconds(20), "1 000 cached reads took \(took)")
  }
}

extension ScaleTests {
  /// Gate: the shortcut measures what the long way would. Break: format only the youngest
  /// of each age group in `LastSeenCellView.distinctTexts`.
  @Test("Grouped last-seen texts are exactly as wide as every row's text")
  func lastSeenWidthIsExact() throws {
    let now = Date.now
    var generator = SystemRandomNumberGenerator()
    let rows = try Self.rows(3_000).enumerated().map { index, row in
      var device = row.device
      // Ages from seconds to a year, densest around the minute/hour/day boundaries.
      let age = [59.0, 61, 3_599, 3_601, 86_399, 86_401][index % 6] * Double.random(in: 0.5...40, using: &generator)
      device.lastSeen = Timestamp(millisecondsSinceEpoch: Int64((now.timeIntervalSince1970 - age) * 1000))
      return DeviceItem(id: row.id, device: device, isOnline: index.isMultiple(of: 7), userName: nil, isReassigned: false)
    }
    let every = rows.map { DevicesView.LastSeenCellView.text(for: $0, now: now) }
    let grouped = DevicesView.LastSeenCellView.distinctTexts(for: rows, now: now)
    #expect(TextMeasure.widest(grouped, .headline) == TextMeasure.widest(every, .headline))
  }
}

extension ScaleTests {
  /// Gate. Search runs per keystroke. Break: look the row words up with `String(localized:)`
  /// again in `DeviceItem.subtitle` — 33.9 s for this, measured.
  @Test("Searching a /16 takes under a second in Debug")
  func search() throws {
    let rows = try Self.rows(65_534)
    let clock = ContinuousClock()
    let start = clock.now
    let found = rows.filter { $0.matches("10.0.1") }
    let took = clock.now - start
    print("search, 65 534 rows: \(took)")
    #expect(!found.isEmpty)
    #expect(took < .seconds(1), "took \(took)")
  }
}
