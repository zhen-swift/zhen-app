import Foundation
import ZhenCore

/// In-memory models for `#Preview`s, built from the fixture network.
///
/// Synchronous on purpose: the history is folded through a `HistoryLedger` — the value
/// type every store holds — so a preview renders its finished state on the first frame,
/// with no store, no task and no network.
enum PreviewContainer {
  static let capture: ScanReport = (try? FixtureNetwork.capture()) ?? ScanReport(run: FixtureNetwork.emptyRun)

  static func model(_ variant: FixtureNetwork.Variant) -> NetworkModel {
    let environment = AppEnvironment.parse(arguments: ["-UITesting", "-Fixture", variant.rawValue], environment: [:], now: .now)
    let model = NetworkModel(environment: environment)
    var ledger = HistoryLedger()
    for report in FixtureNetwork.history(variant, capture: capture, now: environment.launchedAt) {
      _ = ledger.record(report)
    }
    model.seed(ledger: ledger, degradations: FixtureNetwork.degradations(variant, capture: capture))
    return model
  }

  /// A model mid-scan: discovery done, naming running, one degradation in.
  static func scanning(_ variant: FixtureNetwork.Variant) -> NetworkModel {
    let model = model(variant)
    model.startScan()
    let devices = capture.devices
    var events: [ProbeEvent] = [.stageStarted(.discovery)]
    events += devices.map { .hostFound(FixtureScanRunner.facts($0, named: false)) }
    events += [.stageFinished(StageTiming(stage: .discovery, elapsedMillis: 640)), .stageStarted(.naming)]
    events += devices.prefix(3).map { .hostUpdated(FixtureScanRunner.facts($0, named: true)) }
    events += FixtureNetwork.degradations(.partial, capture: capture).map(ProbeEvent.degraded)
    model.scan.apply(events)
    return model
  }

  static var events: [DerivedEvent] { model(.home).events }

  static var namedDeviceID: DeviceItem.ID {
    model(.home).devices.first { $0.device.displayModel != nil }?.id ?? ""
  }

  static var anonymousDeviceID: DeviceItem.ID {
    model(.home).devices.first { $0.isUnidentified && $0.isPrivateMAC }?.id ?? ""
  }
}
