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
    consequence = Self.forTheApp(degradation.reason)
    let reason = degradation.reason
    if reason.contains("Local Network") && degradation.stage == .discovery {
      cause = String(localized: "Local Network access appears to be denied")
      action = .openLocalNetworkSettings
    } else if reason.contains("Local Network") {
      cause = String(localized: "No names could be read")
      action = .openLocalNetworkSettings
    } else if reason.contains("privileged helper") {
      // Core's sentences for a helper that is absent or refused both name it; the remedy
      // for either is in Zhen's Settings, not System Settings.
      cause = String(localized: "The layer-2 sweep did not run")
      action = .reviewHelperSettings
    } else if reason.contains("timed out") {
      cause = String(localized: "Some replies arrived late")
      action = nil
    } else {
      cause = String(localized: "\(degradation.stage.label) ran with partial results")
      action = degradation.recoverable ? .scanAgain : nil
    }
  }

  /// Core's sentence without its advice for the command-line build.
  ///
  /// `ProbePermissionAdvice.appleLocalNetwork` ends by warning that "a command-line build
  /// has no bundle of its own, so the grant may be listed under the terminal application".
  /// True for `zhen`, wrong inside Zhen.app — which has a bundle, and is where the grant is
  /// listed. That one sentence is removed; the finding itself is core's, untouched (Q6).
  static func forTheApp(_ reason: String) -> String {
    let marker = "A command-line build has no bundle of its own"
    guard let start = reason.range(of: marker) else { return reason }
    let tail = reason[start.upperBound...]
    let end = tail.range(of: ". ")?.upperBound ?? reason.endIndex
    return (String(reason[..<start.lowerBound]) + String(reason[end...]))
      .replacing("  ", with: " ")
      .trimmingCharacters(in: .whitespaces)
  }
}
