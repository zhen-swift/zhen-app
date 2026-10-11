import SwiftUI
import ZhenCore

extension LiveScanView {
  static func title(of stage: Stage) -> LocalizedStringKey {
    switch stage {
    case .setup: "Setup"
    case .discovery: "Discovery"
    case .naming: "Naming"
    case .deepScan: "Deep scan"
    }
  }

  func detail(of stage: Stage) -> String {
    let scan = model.scan
    switch (stage, scan.stageStates[stage] ?? .queued) {
    case (_, .skipped): return String(localized: "Not requested")
    case (_, .queued): return String(localized: "Queued")
    case (.discovery, _): return String(localized: "\(scan.found.count) hosts answered")
    case (.naming, .done):
      let named = scan.found.count { !$0.facts.allNames.isEmpty }
      return String(localized: "\(named) names found")
    case (.naming, _): return String(localized: "Asking Bonjour, UPnP and NetBIOS")
    case (.deepScan, .done): return String(localized: "Ports checked")
    case (.deepScan, _): return String(localized: "Checking common ports")
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
