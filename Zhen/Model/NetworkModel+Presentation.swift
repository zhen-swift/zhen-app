import Foundation
import SwiftUI
import ZhenCore

/// What the screens say about the model, worked out once here rather than in each view.
extension NetworkModel {
  /// Activity's window: the last 48 hours.
  static let activityWindow: TimeInterval = 48 * 3_600

  var eventsInWindow: [DerivedEvent] {
    let cutoff = Date.now.addingTimeInterval(-Self.activityWindow).timeIntervalSince1970
    return events.filter { $0.at.timeIntervalSince1970 >= cutoff }
  }

  var onlineCount: Int { devices.count { $0.isOnline } }
  var unidentifiedCount: Int { devices.count(where: \.isUnidentified) }

  /// Whether the latest run is less than a complete answer: it hit its deadline, was
  /// stopped, or lost a source on the way.
  var latestRunIsPartial: Bool {
    guard let latestRun else { return false }
    return latestRun.outcome != .complete || !lastDegradations.isEmpty
  }

  var footerTone: StatusDot.Tone {
    if scan.isRunning { return .accent }
    if latestRun == nil { return .offline }
    return latestRunIsPartial ? .warning : .online
  }

  /// What the footer's dot means, in words: the dot's own tone word is an event's
  /// ("Merged" for the accent), which told VoiceOver a scan in progress was a merge.
  var footerStatusLabel: LocalizedStringResource {
    if scan.isRunning { return .scanning }
    if latestRun == nil { return .neverScanned }
    return latestRunIsPartial ? .partialResults : .complete
  }

  func footerTitle(at now: Date) -> String {
    if scan.isRunning { return String(localized: .scanningEllipsis) }
    guard let finished = latestRun?.finishedAt ?? latestRun?.startedAt else {
      return String(localized: .neverScanned)
    }
    let date = Date(timeIntervalSince1970: finished.timeIntervalSince1970)
    // Under a minute reads "just now": the relative style said "in 0 sec." for a scan that
    // had just finished, the clocks a few milliseconds apart.
    if now.timeIntervalSince(date) < 60 { return String(localized: .lastScanJustNow) }
    let ago = date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    return String(localized: .lastScan(ago))
  }

  /// "192.168.50.0/24 · en0".
  var footerSubtitle: String {
    let network = scan.isRunning ? (scan.request.network ?? interface?.network) : (latestRun?.target ?? interface?.network)
    let name = latestRun?.interface ?? interface?.name
    switch (network, name) {
    case let (network?, name?): return "\(network) · \(name)"
    case let (network?, nil): return network.description
    case let (nil, name?): return name
    case (nil, nil): return String(localized: .noNetworkYet)
    }
  }

  /// The device history already has for a host that just answered, when that is known
  /// rather than guessed: the same hardware address. An address alone matches only where
  /// neither side has a MAC — a lease changes hands, and A3 forbids claiming two records
  /// are one machine on the strength of a shared address.
  func knownDevice(for facts: HostFacts) -> DeviceItem? {
    if let mac = facts.mac { return devices.first { $0.device.mac == mac } }
    return devices.first { $0.device.mac == nil && $0.device.ipv4Addresses.contains(facts.ip) }
  }

  /// "13 devices · 11 online · 10 unidentified".
  var devicesSummary: String {
    let devices = devices.count
    return String(localized: .devicesOnlineUnidentified(devices: devices, onlineCount, unidentifiedCount))
  }
}
