import Foundation

/// A performance gate's time budget, as measured on a developer's Mac.
///
/// CI's virtual Mac runs the same Debug build two to three times slower (macos-26 runner,
/// measured: search 2.06 s against 1 s here). `ci.yml` sets `TEST_RUNNER_ZHEN_BUDGET_SCALE`,
/// which reaches the tests as `ZHEN_BUDGET_SCALE`, and every budget scales by it. Each gate's
/// regression is 20× its budget or more, so a scaled budget still catches every one.
nonisolated enum Budget {
  static let scale = ProcessInfo.processInfo.environment["ZHEN_BUDGET_SCALE"].flatMap(Double.init) ?? 1

  static func of(_ duration: Duration) -> Duration { duration * scale }
}
