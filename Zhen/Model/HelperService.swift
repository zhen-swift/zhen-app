import Foundation

/// Where the privileged helper stands with the system.
nonisolated enum HelperState: Equatable, Sendable {
  case notInstalled
  /// Registered with launchd, waiting for the person to allow it in Login Items. Its own
  /// state: there is nothing left to install, and the useful button opens the pane.
  case requiresApproval
  case installed
  /// The system could not find or register it; the sentence says why.
  case unavailable(String)
}

/// The privileged helper, as the Settings panel drives it.
///
/// A protocol so that tests and `-UITesting` never register anything: registration needs a
/// Developer ID and an administrator's consent, and neither belongs in a test.
protocol HelperService {
  var state: HelperState { get }
  func install() throws
  func uninstall() async throws
  func openLoginItems()
  /// What the running helper says it is, asked over its own connection — nil when nothing
  /// answers. `state` is what was registered; this is what will actually answer.
  func version() async -> String?
}

/// The helper as a test or screenshot sees it: state in memory, nothing registered.
final class FakeHelperService: HelperService {
  private(set) var state: HelperState = .notInstalled

  func install() throws { state = .requiresApproval }
  func uninstall() async throws { state = .notInstalled }
  func openLoginItems() { if state == .requiresApproval { state = .installed } }
  func version() async -> String? { state == .installed ? "fixture" : nil }
}
