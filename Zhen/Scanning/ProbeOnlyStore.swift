import Foundation
import ZhenCore

/// History, read but never written: what a port scan of one device runs over.
///
/// `ScanRunner` records every run it finishes, and core judges presence by the latest run
/// alone. A /32 recorded there became the latest run, and the ledger reported every other
/// device as disappeared — one Scan Ports took the whole network offline until the next
/// full scan (phase 3, stage 1). zhen-core 0.6.0 has no way to scan ports without a run,
/// and this phase does not change core, so the run happens and is simply not kept.
///
/// Reads pass through, so the runner still knows when each address was first seen.
nonisolated struct ProbeOnlyStore: HistoryStore {
  let base: any HistoryStore

  func record(_ report: ScanReport) async -> [DerivedEvent] { [] }
  func setRetention(_ policy: RetentionPolicy) async {}
  func firstSeen(for facts: [HostFacts], in network: IPv4Network) async -> [IPv4Address: Timestamp] {
    await base.firstSeen(for: facts, in: network)
  }
  func devices() async -> [StoredDevice] { await base.devices() }
  func events() async -> [DerivedEvent] { await base.events() }
  func latestRun() async -> ScanRun? { await base.latestRun() }
}
