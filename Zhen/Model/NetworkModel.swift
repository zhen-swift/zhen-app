import Foundation
import Observation
import ZhenCore
import ZhenScan

/// The network as this window knows it: the devices and events in history, the latest run,
/// and the scan in progress.
///
/// One per app, shared by every window, owned by the `App` with `@State`. It reads the same
/// history file `zhen scan` writes, so a scan in a terminal and a scan here are one history.
@Observable
final class NetworkModel {
  let environment: AppEnvironment
  let scan = ScanSession()
  @ObservationIgnored let store: any HistoryStore
  @ObservationIgnored private let pipeline: ScanPipeline
  @ObservationIgnored let defaults: UserDefaults
  @ObservationIgnored let helper: any HelperService
  @ObservationIgnored private let clock: any Clock<Duration>
  @ObservationIgnored private let liveRunner: LiveScanRunner?

  private(set) var devices: [DeviceItem] = []
  private(set) var events: [DerivedEvent] = []
  private(set) var latestRun: ScanRun?
  /// What went wrong in the latest run. Kept after the live scan hands back, and across a
  /// relaunch, so a partial run never reads as a complete one.
  private(set) var lastDegradations: [Degradation] = []
  private(set) var hasLoaded = false
  /// The interface scans go out of, once known.
  private(set) var interface: NetworkInterface?
  /// Names given in this app, by device.
  private(set) var userNames: [DeviceItem.ID: String] = [:]

  init(environment: AppEnvironment) {
    self.environment = environment
    switch environment.dataSource {
    case .live:
      let url = HistoryLocation.resolve(environment: environment.processEnvironment)
      let store: any HistoryStore = url.map { LogHistoryStore(url: $0) } ?? InMemoryHistoryStore()
      let runner = LiveScanRunner(store: store)
      self.store = store
      self.liveRunner = runner
      self.pipeline = ScanPipeline(runner: runner)
      self.defaults = .standard
      self.helper = LiveHelperService()
    case .fixture(let variant):
      let store = InMemoryHistoryStore()
      self.store = store
      self.liveRunner = nil
      let capture = (try? FixtureNetwork.capture()) ?? ScanReport(run: FixtureNetwork.emptyRun)
      self.pipeline = ScanPipeline(runner: FixtureScanRunner(
        store: store, capture: capture, variant: variant,
        pace: environment.scanPace, clock: ContinuousClock()
      ))
      // A throwaway domain: a test can never change, or be changed by, real preferences.
      let suite = "com.jctec.zhen.fixture"
      UserDefaults().removePersistentDomain(forName: suite)
      self.defaults = UserDefaults(suiteName: suite) ?? .standard
      self.helper = FakeHelperService()
    }
    self.clock = ContinuousClock()
    userNames = (defaults.dictionary(forKey: Keys.userNames) as? [String: String]) ?? [:]
  }

  /// Fills the model, seeding the fixture network first when this launch uses one.
  func load() async {
    if case .fixture(let variant) = environment.dataSource, !hasLoaded,
       let capture = try? FixtureNetwork.capture() {
      for report in FixtureNetwork.history(variant, capture: capture, now: environment.launchedAt) {
        _ = await store.record(report)
      }
      lastDegradations = FixtureNetwork.degradations(variant, capture: capture)
      remember(lastDegradations, for: FixtureNetwork.history(variant, capture: capture, now: environment.launchedAt).last?.run.id)
      interface = NetworkInterface(
        name: capture.run.interface, address: capture.run.target.networkAddress,
        network: capture.run.target
      )
    } else if let liveRunner, interface == nil {
      interface = await liveRunner.interface()
    }
    await reload()
    hasLoaded = true
  }

  /// Rereads history. Cheap: the store is an actor holding one ledger.
  func reload() async {
    let stored = await store.devices()
    let run = await store.latestRun()
    events = await store.events()
    latestRun = run
    devices = DeviceItem.rows(from: stored, network: run?.target ?? interface?.network, userNames: userNames)
    if let run, let saved = recalledDegradations(for: run.id) { lastDegradations = saved }
  }

  /// Starts a scan with the person's settings; the window's `.task(id: scan.runToken)` runs it.
  func startScan() {
    let preferences = Preferences(defaults)
    scan.start(ScanRequest(network: preferences.subnetOverride, deepScan: preferences.deepScan))
  }

  /// Starts a scan of a particular network, ports or not: Scan Ports on one device.
  func startScan(deepScan: Bool, network: IPv4Network?) {
    scan.start(ScanRequest(network: network, deepScan: deepScan))
  }

  /// Scans every `minutes`, for as long as the calling task lives. Zero is off.
  func scanAutomatically(every minutes: Int) async {
    guard minutes > 0 else { return }
    while !Task.isCancelled {
      do { try await clock.sleep(for: .seconds(minutes * 60)) } catch { return }
      if !scan.isRunning { startScan() }
    }
  }

  /// Applies the event-retention setting to the store.
  func applyRetention(days: Int) async {
    await store.setRetention(days > 0 ? .days(days) : .forever)
  }

  /// Runs the scan the session asked for. Called from the window's task, so closing the
  /// window or stopping the scan cancels it.
  func performScan() async {
    guard scan.runToken != nil else { return }
    let outcome = await scan.run(with: pipeline)
    switch outcome {
    case .finished(let completed):
      lastDegradations = completed.report.degradations
      remember(lastDegradations, for: completed.report.run.id)
    case .unavailable(let degradation):
      lastDegradations = [degradation]
    }
    await reload()
  }

  /// Gives a device a name of its own. Local only: nothing is written back to the device.
  func rename(_ id: DeviceItem.ID, to name: String?) {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    userNames[id] = (trimmed?.isEmpty ?? true) ? nil : trimmed
    defaults.set(userNames, forKey: Keys.userNames)
    devices = devices.map {
      $0.id == id ? DeviceItem(id: $0.id, device: $0.device, isOnline: $0.isOnline,
                               userName: userNames[id], isReassigned: $0.isReassigned) : $0
    }
  }

  func device(_ id: DeviceItem.ID) -> DeviceItem? {
    devices.first { $0.id == id }
  }

  // ── Degradations across a relaunch ────────────────────────────────────────────────

  private enum Keys {
    static let degradations = "lastRunDegradations"
    static let degradationsRun = "lastRunDegradationsRun"
    static let userNames = "userNames"
  }

  private func remember(_ degradations: [Degradation], for run: UUID?) {
    guard let run, let data = try? JSONEncoder().encode(degradations) else { return }
    defaults.set(data, forKey: Keys.degradations)
    defaults.set(run.uuidString, forKey: Keys.degradationsRun)
  }

  private func recalledDegradations(for run: UUID) -> [Degradation]? {
    guard defaults.string(forKey: Keys.degradationsRun) == run.uuidString,
          let data = defaults.data(forKey: Keys.degradations) else { return nil }
    return try? JSONDecoder().decode([Degradation].self, from: data)
  }
}

extension NetworkModel {
  /// Fills the model from a ledger directly. For previews, which cannot await a store.
  func seed(ledger: HistoryLedger, degradations: [Degradation]) {
    latestRun = ledger.latestRun
    events = ledger.events()
    devices = DeviceItem.rows(from: ledger.devices(), network: ledger.latestRun?.target, userNames: userNames)
    lastDegradations = degradations
    if let run = ledger.latestRun {
      interface = NetworkInterface(name: run.interface, address: run.target.networkAddress, network: run.target)
    }
    hasLoaded = true
  }
}
