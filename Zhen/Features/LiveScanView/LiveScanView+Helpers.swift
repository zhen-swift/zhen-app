import SwiftUI
import ZhenCore

extension LiveScanView {
  static func title(of stage: Stage) -> LocalizedStringResource {
    switch stage {
    case .setup: .setup
    case .discovery: .discovery
    case .naming: .naming
    case .deepScan: .deepScan
    }
  }

  func detail(of stage: Stage) -> String {
    let scan = model.scan
    let state = scan.stageStates[stage] ?? .queued
    let line = summary(of: stage, state: state)
    // "13 hosts answered · 1.2 s": a finished stage says what it cost.
    guard state == .done, let took = scan.stageDurations[stage] else { return line }
    let seconds = took.formatted(.units(allowed: [.seconds], width: .narrow, fractionalPart: .show(length: 1)))
    return "\(line) · \(seconds)"
  }

  private func summary(of stage: Stage, state: ScanSession.StageState) -> String {
    let scan = model.scan
    switch (stage, state) {
    case (_, .skipped): return String(localized: .notRequested)
    case (_, .queued): return String(localized: .queued)
    case (.discovery, _): return String(localized: .hostsAnswered(scan.found.count))
    case (.naming, .done):
      let named = scan.found.count { !$0.facts.allNames.isEmpty }
      return String(localized: .namesFound(named))
    case (.naming, _): return String(localized: .askingBonjourUpnpNetbios)
    case (.deepScan, .done): return String(localized: .portsChecked)
    case (.deepScan, _): return String(localized: .checkingCommonPorts)
    case (.setup, _): return ""
    }
  }

  static func cardState(_ state: ScanSession.StageState) -> StageCard.State {
    switch state {
    case .queued: .queued
    case .running(let fraction): .running(fraction)
    case .done: .done
    case .skipped: .skipped
    }
  }
}
