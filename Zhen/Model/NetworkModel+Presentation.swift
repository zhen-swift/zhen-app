import Foundation
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

  func footerTitle(at now: Date) -> String {
    if scan.isRunning { return String(localized: "Scanning…") }
    guard let finished = latestRun?.finishedAt ?? latestRun?.startedAt else {
      return String(localized: "Never scanned")
    }
    let date = Date(timeIntervalSince1970: finished.timeIntervalSince1970)
    let ago = date.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    return String(localized: "Last scan \(ago)")
  }

  /// "192.168.50.0/24 · en0".
  var footerSubtitle: String {
    let network = scan.isRunning ? (scan.request.network ?? interface?.network) : (latestRun?.target ?? interface?.network)
    let name = latestRun?.interface ?? interface?.name
    switch (network, name) {
    case let (network?, name?): return "\(network) · \(name)"
    case let (network?, nil): return network.description
    case let (nil, name?): return name
    case (nil, nil): return String(localized: "No network yet")
    }
  }

  /// "13 devices · 11 online · 5 unidentified".
  var devicesSummary: String {
    let devices = devices.count
    return String(localized: "\(devices) devices · \(onlineCount) online · \(unidentifiedCount) unidentified")
  }
}
