import ZhenCore

extension ScanRun {
  /// Whether this run's port stage ran. History keeps no time on a port observation, so
  /// this is how the detail knows whether "checked" can be dated by the run.
  nonisolated var checkedPorts: Bool { timing.stages.contains { $0.stage == .deepScan } }
}
