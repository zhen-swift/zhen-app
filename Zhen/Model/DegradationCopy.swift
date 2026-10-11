import Foundation
import ZhenCore

/// A degradation as a person reads it: what was lost, the engine's own explanation, and
/// what they can do about it.
///
/// The explanation is core's sentence, verbatim. The app renders; it never re-measures or
/// re-words a finding. What this adds is a short cause to scan for and the one action that
/// helps — and it recognises the Local Network case by the sentence core writes for it,
/// because the grant cannot be queried and core says so.
nonisolated struct DegradationCopy: Hashable, Sendable {
  enum Action: Hashable, Sendable {
    case openLocalNetworkSettings
    case scanAgain
  }

  let cause: String
  let consequence: String
  let action: Action?

  init(_ degradation: Degradation) {
    consequence = degradation.reason
    let reason = degradation.reason
    if reason.contains("Local Network") && degradation.stage == .discovery {
      cause = String(localized: "Local Network access appears to be denied")
      action = .openLocalNetworkSettings
    } else if reason.contains("Local Network") {
      cause = String(localized: "No names could be read")
      action = .openLocalNetworkSettings
    } else if reason.contains("timed out") {
      cause = String(localized: "Some replies arrived late")
      action = nil
    } else {
      cause = String(localized: "\(degradation.stage.label) ran with partial results")
      action = degradation.recoverable ? .scanAgain : nil
    }
  }
}
