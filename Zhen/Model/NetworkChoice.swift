import Foundation
import ZhenCore

/// A network with a history, as the network picker lists it.
///
/// Since zhen-core 0.10.0 each network keeps its own history: a subnet, and the router's
/// hardware address where it could be read. Two routers that both hand out
/// `192.168.1.0/24` are two networks, so the picker names each one's router as well.
nonisolated struct NetworkChoice: Identifiable, Hashable, Sendable {
  /// The history file. Unique, because each network's directory is named for its key.
  var id: URL
  var identity: NetworkIdentity
  /// When its latest scan started. Nil for the current network before its first scan.
  var lastScan: Date?
  /// The router's name or vendor, as this network's own history knows it.
  var router: String?
  /// Whether this is the network the Mac is on now, which scans record into.
  var isCurrent: Bool

  /// The picker's row identifier: `network-<key>`.
  var accessibilityIdentifier: String { "network-\(identity.key)" }

  /// The choices, from what core lists: the current network first, even before it has a
  /// history of its own, then the others, most recently scanned first.
  static func list(
    known: [KnownNetwork], current: URL?, currentIdentity: NetworkIdentity?, routers: [URL: String]
  ) -> [NetworkChoice] {
    var choices = known.map { network in
      NetworkChoice(
        id: network.url, identity: network.identity,
        lastScan: network.latestRun.map { Date(timeIntervalSince1970: $0.startedAt.timeIntervalSince1970) },
        router: routers[network.url], isCurrent: network.url == current
      )
    }
    if let current, !choices.contains(where: { $0.id == current }), let currentIdentity {
      choices.append(NetworkChoice(
        id: current, identity: currentIdentity, lastScan: nil, router: nil, isCurrent: true
      ))
    }
    // Stable: core's order (most recent first) among the others.
    let currentFirst = choices.filter(\.isCurrent) + choices.filter { !$0.isCurrent }
    return currentFirst
  }

  /// The name a history gives a network's router: the device with the gateway's hardware
  /// address, by its name, else its vendor.
  static func routerName(in devices: [StoredDevice], gateway: MACAddress?) -> String? {
    guard let gateway else { return nil }
    let router = devices.first { $0.device.mac == gateway || $0.macHistory.contains { $0.mac == gateway } }
    return router?.device.displayName ?? router?.device.vendor
  }
}
