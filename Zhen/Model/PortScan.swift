import Foundation
import ZhenCore
import ZhenScan

/// One device's port scan, as this session ran it.
nonisolated struct PortScan: Equatable, Sendable {
  enum State: Equatable, Sendable {
    case running
    case finished
    /// It ran and found nothing to report; the sentence says what happened.
    case failed(String)
  }

  var state: State
  /// What answered. While running, the previous session scan's ports, if any.
  var ports: [PortObservation]
  /// When it started, or when it finished once it has.
  var at: Date

  /// What a finished scan of one address amounts to.
  ///
  /// `mac` is the hardware address of the device asked about. An offline device's address
  /// may belong to another device now; whatever answers there is not this device, and its
  /// ports were once shown as this one's (review, part 7).
  static func result(of outcome: ScanOutcome, for address: IPv4Address, expecting mac: MACAddress? = nil) -> PortScan {
    switch outcome {
    case .unavailable(let degradation):
      return PortScan(state: .failed(degradation.reason), ports: [], at: .now)
    case .finished(let scan):
      if let device = scan.report.devices.first(where: { $0.ipv4Addresses.contains(address) }) {
        if let mac, let answered = device.mac, answered != mac {
          return PortScan(state: .failed(String(localized: .anotherDeviceAnswersAt(address.description))), ports: [], at: .now)
        }
        if !device.ports.isEmpty {
          return PortScan(state: .finished, ports: device.ports, at: .now)
        }
      }
      let reason = scan.report.run.outcome == .cancelled
        ? String(localized: .stoppedBeforeAnyPortAnswered)
        : String(localized: .didNotAnswerThisTimeSo(address.description))
      return PortScan(state: .failed(reason), ports: [], at: .now)
    }
  }
}

/// The device a port scan is for. A new value is a new scan.
nonisolated struct PortScanTarget: Hashable, Sendable {
  let id: DeviceItem.ID
  let address: IPv4Address
  /// The device's hardware address, when it has one: what answers must match it.
  let mac: MACAddress?
  let token = UUID()
}
