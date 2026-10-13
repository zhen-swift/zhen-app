import Foundation

/// Changes to the history file, from this app or from `zhen scan` in a terminal.
///
/// Polled, once a second, by inode, size and modification time. A vnode source was the
/// obvious tool and the wrong one here: compaction replaces the file by rename, so a source
/// on the old inode goes silent at exactly the moment history changes most, and before the
/// first scan there is no file to open at all. Re-arming across both is a state machine; a
/// `stat` a second is one line of logic and costs nothing measurable (ledger, phase 3).
nonisolated enum HistoryWatcher {
  /// What identifies one version of the file. Nil while it does not exist.
  struct Stamp: Equatable, Sendable {
    let inode: Int
    let size: Int
    let modified: Date
  }

  static func stamp(of url: URL) -> Stamp? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
    return Stamp(
      inode: (attributes[.systemFileNumber] as? Int) ?? 0,
      size: (attributes[.size] as? Int) ?? 0,
      modified: (attributes[.modificationDate] as? Date) ?? .distantPast
    )
  }

  /// One element each time the file changes, for as long as the consuming task lives.
  ///
  /// The baseline is the file as it is when this is called, not when the first poll runs:
  /// a write landing in between was otherwise never reported (caught by
  /// `ScanningBehaviourTests.terminalScanAppears`, which failed one run in two).
  static func changes(
    of url: URL, every interval: Duration = .seconds(1), clock: any Clock<Duration> = ContinuousClock()
  ) -> AsyncStream<Void> {
    let baseline = stamp(of: url)
    return AsyncStream { continuation in
      let task = Task {
        var last = baseline
        while !Task.isCancelled {
          do { try await clock.sleep(for: interval) } catch { break }
          let now = stamp(of: url)
          if now != last {
            last = now
            continuation.yield()
          }
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}
