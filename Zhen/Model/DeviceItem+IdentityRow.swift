import Foundation
import ZhenCore

/// One hardware address in the identity card: A3's "one row per MAC with the reason it
/// merged and a date range".
nonisolated struct IdentityRow: Identifiable, Hashable, Sendable {
  var id: String { mac }
  let mac: String
  let isPrivate: Bool
  /// The address the device presents now. Its dot is the accent; the rest are secondary.
  let isCurrent: Bool
  /// How it came to be this device's.
  let reason: String
  /// "since 3 Oct" for the current address, the span it was seen over for the others.
  let span: String
}

nonisolated extension DeviceItem {
  /// The identity card's rows: the current address first, then the earlier ones, newest
  /// first. From zhen-core's MAC history, which is kept on the ledger's record rather than
  /// on the device — a device carries the last thing observed, and these are history.
  var identityRows: [IdentityRow] {
    let rows = macHistory
      .sorted { $0.lastSeen > $1.lastSeen }
      .map { sighting in
        let current = sighting.mac == device.mac
        let first = Date(timeIntervalSince1970: sighting.firstSeen.timeIntervalSince1970)
        let last = Date(timeIntervalSince1970: sighting.lastSeen.timeIntervalSince1970)
        return IdentityRow(
          mac: sighting.mac.description,
          isPrivate: sighting.mac.isLocallyAdministered,
          isCurrent: current,
          reason: Self.reason(sighting.link),
          span: current || first >= last
            ? String(localized: .since(first.formatted(date: .abbreviated, time: .omitted)))
            : (first..<last).formatted(date: .abbreviated, time: .omitted)
        )
      }
    // The current address first, whatever its span; the rest stay newest first.
    return rows.filter(\.isCurrent) + rows.filter { !$0.isCurrent }
  }

  private static func reason(_ link: MACSighting.Link) -> String {
    switch link {
    case .original: String(localized: .macFirstAddress)
    case .rotation(let kind): String(localized: .macRotatedRecognisedBy(identifierName(kind)))
    case .merge(let kind): String(localized: .macMergedShared(identifierName(kind)))
    }
  }

  private static func identifierName(_ kind: HostIdentifierKind) -> String {
    switch kind {
    case .universalMAC: String(localized: .hardwareMac)
    case .randomizedMAC: String(localized: .rotatingMac)
    case .mdnsInstance: String(localized: .bonjourName)
    case .dhcpHostname: String(localized: .dhcpName)
    case .ipLease: String(localized: .address)
    }
  }
}
