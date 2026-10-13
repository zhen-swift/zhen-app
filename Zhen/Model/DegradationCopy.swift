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
    /// Zhen's own Settings, where the helper is installed, approved and removed.
    case reviewHelperSettings
  }

  let cause: String
  let consequence: String
  let action: Action?

  init(_ degradation: Degradation) {
    consequence = degradation.reason
    let reason = degradation.reason
    if reason.contains("Local Network") && degradation.stage == .discovery {
      cause = String(localized: .localNetworkAccessAppearsDenied)
      action = .openLocalNetworkSettings
    } else if reason.contains("Local Network") {
      cause = String(localized: .noNamesCouldRead)
      action = .openLocalNetworkSettings
    } else if reason.contains("privileged helper") {
      // Core's sentences for a helper that is absent or refused both name it; the remedy
      // for either is in Zhen's Settings, not System Settings.
      cause = String(localized: .layer2SweepDidNotRun)
      action = .reviewHelperSettings
    } else if reason.contains("timed out") {
      cause = String(localized: .someRepliesArrivedLate)
      action = nil
    } else {
      cause = String(localized: .ranWithPartialResults(degradation.stage.label))
      action = degradation.recoverable ? .scanAgain : nil
    }
  }
}
