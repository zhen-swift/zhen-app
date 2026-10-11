import Foundation
import ZhenCore

/// One device as the Devices table shows it: a `Device` flattened into the values its cells
/// display and sort by.
///
/// Identity is the strongest key core would file the device under — a universal MAC, then a
/// Bonjour instance, then a DHCP name, then a randomised MAC, then the lease — never the
/// address alone, which moves. A list keyed on the address tears down and rebuilds a row
/// every time a lease changes.
nonisolated struct DeviceItem: Identifiable, Hashable, Sendable {
  typealias ID = String

  let id: ID
  let device: Device
  /// Whether the most recent run saw it. Presence is a fact about a run, not a device.
  let isOnline: Bool
  /// A name given in this app. It outranks every discovered source.
  let userName: String?
  /// It is absent, and a device that did answer now holds its address.
  let isReassigned: Bool

  /// The name to show, or nil for an unidentified device.
  var name: String? { userName ?? device.displayName }

  var isUnidentified: Bool { name == nil }

  /// What we know about it, said plainly. For an unidentified device this line is the
  /// whole row's worth of information, so it never says nothing.
  var subtitle: String {
    var parts: [String] = []
    if let model = device.displayModel { parts.append(model) }
    if let vendor = device.vendor { parts.append(vendor) }
    if device.vendor == nil {
      switch device.mac {
      case .none: parts.append(String(localized: "no hardware address"))
      case .some(let mac) where mac.isLocallyAdministered:
        parts.append(String(localized: "randomized MAC"))
        parts.append(String(localized: "no vendor"))
      case .some: parts.append(String(localized: "no vendor"))
      }
    }
    let via = Set(device.discoveredVia)
    if via.contains(.localInterface) {
      parts.append(String(localized: "this Mac"))
    } else if via.contains(.probeReply) || via.contains(.arpReply) {
      parts.append(String(localized: "responds to ping"))
    } else if via.contains(.neighborTable) {
      parts.append(String(localized: "in ARP table, no ping reply"))
    }
    // Sentence case: only the first letter of the line is raised, so "ARP" and "MAC" and a
    // model string like "AppleTV5,3" keep their own capitals.
    let line = parts.joined(separator: " · ")
    return line.prefix(1).uppercased() + line.dropFirst()
  }

  var identification: Identification { device.identification }
  var lastSeen: Date { Date(timeIntervalSince1970: device.lastSeen.timeIntervalSince1970) }
  var firstSeen: Date { Date(timeIntervalSince1970: device.firstSeen.timeIntervalSince1970) }

  /// The address a person reads: the IPv4 one when there is one. A link-local IPv6
  /// address drops its `%en0` scope here — every one in the list shares the scanning
  /// interface, and the four characters were what pushed the column past the window at
  /// its minimum (ledger, stage A). The scoped form stays in `fullAddress`.
  var address: String {
    if let v4 = device.ipv4Addresses.first { return v4.description }
    return fullAddress.split(separator: "%").first.map(String.init) ?? fullAddress
  }

  /// The primary address exactly as core writes it, scope included.
  var fullAddress: String { device.primaryAddress.description }
  var mac: String? { device.mac?.description }
  var isPrivateMAC: Bool { device.mac?.isLocallyAdministered ?? false }

  /// Whether a search term finds this device: by name, by what is known, by address, by
  /// MAC — the way a person types, ignoring case and accents.
  func matches(_ term: String) -> Bool {
    let term = term.trimmingCharacters(in: .whitespaces)
    guard !term.isEmpty else { return true }
    return [name ?? String(localized: "Unidentified device"), subtitle, address, mac ?? ""]
      .contains { $0.localizedStandardContains(term) }
  }

  // ── Sort keys ──────────────────────────────────────────────────────────────────

  /// Online first.
  var statusRank: Int { isOnline ? 0 : 1 }
  /// Named devices alphabetically, then the unidentified ones.
  var nameSortKey: String { name.map { "0" + $0.lowercased() } ?? "1" + address }
  var identificationRank: Int { identification.rank }
  /// Address order: core's own, IPv4 before IPv6, numeric within each.
  ///
  /// Not a string. `KeyPathComparator` compares strings with localized-standard ordering,
  /// which reads runs of digits as numbers: a hex key put `.10` (`…8320a`) before `.1`
  /// (`…83201`). Caught by `DevicesUITests.testSortingAndSearch`, pinned by
  /// `DeviceItemTests.addressOrder`.
  var addressSortKey: IPAddress { device.ipv4Addresses.first.map(IPAddress.v4) ?? device.primaryAddress }
  /// Hardware order by value; devices without a MAC last.
  var macSortKey: UInt64 { device.mac?.raw ?? .max }

  /// The default order: status, then most recently seen.
  static let defaultOrder: [KeyPathComparator<DeviceItem>] = [
    KeyPathComparator(\.statusRank),
    KeyPathComparator(\.lastSeen, order: .reverse),
  ]
}

nonisolated extension DeviceItem {
  /// The stable key for a device: core's strongest identifier for it.
  static func identity(of device: Device, in network: IPv4Network?) -> ID {
    if let network, let key = HostIdentifier.candidates(for: device, in: network).first {
      return "\(key.kind.rawValue):\(key.value)"
    }
    if let mac = device.mac { return "\(HostIdentifier.fromMAC(mac).kind.rawValue):\(mac)" }
    return "address:\(device.primaryAddress)"
  }

  /// Rows for a store's devices, with identities made unique and reassignment worked out.
  static func rows(
    from stored: [StoredDevice], network: IPv4Network?, userNames: [ID: String] = [:]
  ) -> [DeviceItem] {
    let heldNow = Set(stored.filter(\.isPresent).flatMap(\.device.ipv4Addresses))
    var seen: [ID: Int] = [:]
    return stored.map { entry in
      var id = identity(of: entry.device, in: network)
      seen[id, default: 0] += 1
      if let count = seen[id], count > 1 { id += "#\(count)" }
      let reassigned = !entry.isPresent && entry.device.ipv4Addresses.contains { heldNow.contains($0) }
      return DeviceItem(
        id: id, device: entry.device, isOnline: entry.isPresent,
        userName: userNames[id], isReassigned: reassigned
      )
    }
  }
}
