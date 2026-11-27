import Foundation
import Observation
import ZhenCore
import ZhenScan

/// The network as this window knows it: the devices and events in history, the latest run,
/// and the scan in progress.
///
/// One per app, shared by every window, owned by the `App` with `@State`. It reads the same
/// history files `zhen scan` writes, so a scan in a terminal and a scan here are one history.
///
/// Each network has its own history (zhen-core 0.10.0). The one in view is the network this
/// Mac is on, unless the person picked another: that one is read only, and a scan returns to
/// the current network first.
@Observable
final class NetworkModel {
  let environment: AppEnvironment
  let scan = ScanSession()
  /// The store of the network in view.
  @ObservationIgnored private(set) var store: any HistoryStore
  /// The store of the network this Mac is on: what scans and port scans record into. The
  /// same as `store` unless the person is looking at another network.
  @ObservationIgnored private var currentStore: any HistoryStore
  /// Where each network's history is kept. Nil under fixtures, and where there is nowhere.
  @ObservationIgnored let histories: NetworkHistories?
  @ObservationIgnored private let pipeline: ScanPipeline
  @ObservationIgnored let defaults: UserDefaults
  @ObservationIgnored let helper: any HelperService
  @ObservationIgnored let notifier: any Notifier
  @ObservationIgnored private let clock: any Clock<Duration>
  @ObservationIgnored private let liveRunner: LiveScanRunner?
  /// The history file in view, when this launch uses one.
  private(set) var historyURL: URL?
  /// The history file of the network this Mac is on, once known.
  private(set) var currentHistoryURL: URL?
  /// The network this Mac is on, as last read.
  @ObservationIgnored private var currentIdentity: NetworkIdentity?
  /// Every network with a history, for the picker: the current one first.
  private(set) var networks: [NetworkChoice] = []

  private(set) var devices: [DeviceItem] = [] {
    didSet { devicesRevision &+= 1 }
  }
  /// Changes whenever `devices` does: what work derived from the whole list is cached by.
  @ObservationIgnored private(set) var devicesRevision = 0
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
  /// The hardware address of each named device, so its name can follow it when its ID
  /// changes (see `carryAcrossNewIDs`).
  @ObservationIgnored private var nameAnchors: [DeviceItem.ID: String] = [:]
  /// Old ID → new ID, for devices whose ID changed this session: an open detail page or a
  /// stored path still finds its device.
  @ObservationIgnored private var aliases: [DeviceItem.ID: DeviceItem.ID] = [:]
  /// Port scans of single devices run in this session, by device: whether one is running,
  /// and why one found nothing. What they found is in history, where core folded it.
  private(set) var portScans: [DeviceItem.ID: PortScan] = [:]
  /// The device whose ports are being scanned. The window's `.task(id:)` runs it.
  private(set) var portScanTarget: PortScanTarget?

  /// - Parameters:
  ///   - environment: what this launch is: live, or a fixture.
  ///   - testDefaults: a test's own domain. Fixture models otherwise share one, which each
  ///     clears when it is made — fine for one app, a race between parallel tests.
  ///   - engine: for a live launch, what builds the scanner. zhen-core's `ScanRunner`
  ///     unless a test is driving the real history file with a stand-in engine.
  ///   - histories: for a live launch, where each network's history is kept. Resolved from
  ///     the process unless a test keeps them in a scratch directory.
  init(
    environment: AppEnvironment, defaults testDefaults: UserDefaults? = nil,
    engine: LiveScanRunner.Factory? = nil, histories testHistories: NetworkHistories? = nil
  ) {
    self.environment = environment
    switch environment.dataSource {
    case .live:
      let histories = testHistories ?? NetworkHistories.resolve(environment: environment.processEnvironment)
      // `ZHEN_HISTORY` names one file for every network, known now. Otherwise which file is
      // the current network's is known once `load` has read the network.
      let url: URL? = if case .single(let file) = histories?.layout { file } else { nil }
      let store: any HistoryStore = url.map { LogHistoryStore(url: $0) } ?? InMemoryHistoryStore()
      let runner = engine.map { LiveScanRunner(store: store, make: $0) } ?? LiveScanRunner(store: store)
      self.histories = histories
      self.historyURL = url
      self.currentHistoryURL = url
      self.store = store
      self.currentStore = store
      self.liveRunner = runner
      self.pipeline = ScanPipeline(runner: runner)
      self.defaults = testDefaults ?? .standard
      self.helper = LiveHelperService()
      self.notifier = LiveNotifier()
    case .fixture(let variant):
      let store = InMemoryHistoryStore()
      self.store = store
      self.currentStore = store
      self.histories = nil
      self.historyURL = nil
      self.liveRunner = nil
      let dataset = environment.fixtureDataset
      let capture = (try? FixtureNetwork.capture(dataset)) ?? ScanReport(run: FixtureNetwork.emptyRun)
      self.pipeline = ScanPipeline(runner: FixtureScanRunner(
        store: store, capture: capture, variant: variant, dataset: dataset,
        pace: environment.scanPace, clock: ContinuousClock(), addsNewDevice: environment.newDeviceOnScan
      ))
      // A throwaway domain: a test can never change, or be changed by, real preferences.
      if let testDefaults {
        self.defaults = testDefaults
      } else {
        let suite = "com.jctec.zhen.fixture"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        // Key by key, through the instance in use. `removePersistentDomain` from another
        // instance left cached values readable: a Settings capture in phase 3 showed the
        // subnet a previous UI test had typed.
        for key in (defaults.persistentDomain(forName: suite) ?? [:]).keys {
          defaults.removeObject(forKey: key)
        }
        self.defaults = defaults
      }
      self.helper = FakeHelperService()
      self.notifier = FakeNotifier()
    }
    self.clock = ContinuousClock()
    userNames = (defaults.dictionary(forKey: Keys.userNames) as? [String: String]) ?? [:]
    nameAnchors = (defaults.dictionary(forKey: Keys.nameAnchors) as? [String: String]) ?? [:]
  }

  /// Fills the model, seeding the fixture network first when this launch uses one.
  func load() async {
    if case .fixture(let variant) = environment.dataSource, !hasLoaded,
       let capture = try? FixtureNetwork.capture(environment.fixtureDataset) {
      let history = FixtureNetwork.history(
        variant, capture: capture, dataset: environment.fixtureDataset, now: environment.launchedAt
      )
      for report in history {
        _ = await store.record(report)
      }
      lastDegradations = FixtureNetwork.degradations(variant, capture: capture)
      remember(lastDegradations, for: history.last?.run.id)
      interface = NetworkInterface(
        name: capture.run.interface, address: capture.run.target.networkAddress,
        network: capture.run.target
      )
    } else if let liveRunner, interface == nil {
      await openCurrentNetwork(through: liveRunner)
    }
    // Retention is a property of the store, not of the Settings window: applied here, it
    // holds for every run this launch records, Settings opened or not.
    await applyRetention(days: Preferences(defaults).retentionDays)
    await reload()
    await refreshNetworks()
    hasLoaded = true
  }

  /// Rereads history whenever the file in view changes, for as long as the calling task
  /// lives: a scan run in a terminal appears in the open window. The host restarts it when
  /// the network in view changes.
  func watchHistory() async {
    guard let historyURL else { return }
    let changes = HistoryWatcher.changes(of: historyURL)
    // Anything written before the watch began is read now; anything after, as it lands.
    await reload()
    for await _ in changes {
      await reload()
    }
  }

  /// Rereads history. Cheap: the store is an actor holding one ledger.
  func reload() async {
    let stored = await store.devices()
    let run = await store.latestRun()
    events = await store.events()
    latestRun = run
    let network = run?.target ?? interface?.network
    var rows = DeviceItem.rows(from: stored, network: network, userNames: userNames)
    if carryAcrossNewIDs(rows) {
      rows = DeviceItem.rows(from: stored, network: network, userNames: userNames)
    }
    devices = rows
    // The latest run's own degradations, or none known: a run the command line recorded
    // left nothing here, and the previous run's warnings are not this one's (review, part 7).
    if let run { lastDegradations = recalledDegradations(for: run.id) ?? [] }
  }

  /// Whether a scan of any kind is running. One at a time: both would contend for the
  /// same capture device and the same descriptor budget.
  var isBusy: Bool { scan.isRunning || portScanTarget != nil }

  /// Starts a scan with the person's settings; the window's `.task(id: scan.runToken)` runs it.
  func startScan() {
    guard portScanTarget == nil else { return }
    let preferences = Preferences(defaults)
    scan.start(ScanRequest(
      network: preferences.subnetOverride, budget: preferences.budget, ports: preferences.portStage
    ))
  }

  /// Runs the stopped scan again, exactly as it was asked for.
  func scanAgain() {
    guard portScanTarget == nil else { return }
    scan.start(scan.request)
  }

  /// Stops whichever scan is running.
  func stopScanning() {
    scan.stop()
    portScanTarget = nil
  }

  /// Scans one device's ports, without taking over the window or recording a run.
  func scanPorts(_ id: DeviceItem.ID) {
    // Another network's devices are not here to answer: the probe would record into this one.
    guard !isBusy, isViewingCurrentNetwork, let item = device(id), let address = item.device.ipv4Addresses.first else { return }
    portScans[id] = PortScan(state: .running, ports: portScans[id]?.ports ?? [], at: .now)
    portScanTarget = PortScanTarget(id: id, address: address, isOnline: item.isOnline)
  }

  /// Runs the port scan `scanPorts` asked for. Called from the window's task, so closing
  /// the window or Stop Scan cancels it; what had answered is kept either way.
  ///
  /// A probe, not a run: zhen-core folds the ports into the device history holds and
  /// leaves every other device as it was, so the result survives a relaunch.
  func performPortScan() async {
    guard let target = portScanTarget else { return }
    await liveRunner?.note(helper.state)
    let outcome = await pipeline.probePorts(PortProbeRequest(
      addresses: [.v4(target.address)], budget: Preferences(defaults).budget
    ))
    portScans[target.id] = PortScan.result(of: outcome, for: target.address, isOnline: target.isOnline)
    if portScanTarget == target { portScanTarget = nil }
    await reload()
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
    await store.setRetention(Self.retention(days: days))
    await currentStore.setRetention(Self.retention(days: days))
  }

  static func retention(days: Int) -> RetentionPolicy {
    days > 0 ? .days(days) : .forever
  }

  /// Runs the scan the session asked for. Called from the window's task, so closing the
  /// window or stopping the scan cancels it.
  func performScan() async {
    guard scan.runToken != nil else { return }
    // A scan records into the network this Mac is on, so that is the one it shows.
    if !isViewingCurrentNetwork {
      showCurrentNetwork()
      await reload()
    }
    await liveRunner?.note(helper.state)
    let knownBefore = Set(devices.map(\.id))
    let started = Date.now
    let outcome = await scan.run(with: pipeline)
    var unavailable: Degradation?
    switch outcome {
    case .finished(let completed):
      remember(completed.report.degradations, for: completed.report.run.id)
      // History now holds ports at least as fresh as anything scanned this session.
      if scan.request.ports != .off { portScans = [:] }
    case .unavailable(let degradation):
      unavailable = degradation
    }
    await reload()
    await refreshNetworks()
    // A scan that could not start recorded no run; its reason must outlive the reload,
    // which restores the previous run's degradations.
    if let unavailable { lastDegradations = [unavailable] }
    // The interface the footer and Settings show, as the engine now sees it: it was read
    // once at launch and went stale when the Mac changed networks.
    if let liveRunner { interface = await liveRunner.interface() ?? interface }
    if Preferences(defaults).notifyNewDevices {
      let arrivals = NewDeviceNotice.newDevices(devices, knownBefore: knownBefore, scanStarted: started)
      for message in NewDeviceNotice.messages(for: arrivals) {
        notifier.post(title: message.title, body: message.body, id: message.id)
      }
    }
  }

  /// Gives a device a name of its own. Local only: nothing is written back to the device.
  func rename(_ id: DeviceItem.ID, to name: String?) {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    userNames[id] = (trimmed?.isEmpty ?? true) ? nil : trimmed
    nameAnchors[id] = userNames[id] == nil ? nil : device(id)?.device.mac?.description
    saveNames()
    devices = devices.map {
      $0.id == id ? DeviceItem(id: $0.id, device: $0.device, isOnline: $0.isOnline,
                               userName: userNames[id], isReassigned: $0.isReassigned,
                               macHistory: $0.macHistory) : $0
    }
  }

  /// A device's ID is the strongest key it presents now, and that can change: a run in
  /// which naming did not happen turns `mdns_instance:…` into `randomized_mac:…`. The
  /// person's name for it, its port results and an open page were all keyed by the old ID
  /// and were lost (review, part 7). Where the hardware address says it is the same device,
  /// they move to the new ID. Returns whether a name moved, so the rows are rebuilt with it.
  ///
  /// The durable fix is core's: its record key, which does not change, exposed on
  /// `StoredDevice`.
  private func carryAcrossNewIDs(_ rows: [DeviceItem]) -> Bool {
    let present = Set(rows.map(\.id))
    let byMAC = Dictionary(rows.compactMap { row in row.device.mac.map { ($0.description, row.id) } }, uniquingKeysWith: { first, _ in first })
    var namesMoved = false
    // Names, including those from an earlier launch: their anchors were saved with them.
    for (old, mac) in nameAnchors where !present.contains(old) {
      guard let new = byMAC[mac], new != old else { continue }
      if userNames[new] == nil, let name = userNames[old] {
        userNames[new] = name
        nameAnchors[new] = mac
        namesMoved = true
      }
      userNames[old] = nil
      nameAnchors[old] = nil
      alias(old, to: new)
    }
    // This session's devices: their port results and their pages.
    for previous in devices where !present.contains(previous.id) {
      guard let mac = previous.device.mac?.description, let new = byMAC[mac] else { continue }
      if let scan = portScans.removeValue(forKey: previous.id), portScans[new] == nil { portScans[new] = scan }
      alias(previous.id, to: new)
    }
    if namesMoved { saveNames() }
    return namesMoved
  }

  private func alias(_ old: DeviceItem.ID, to new: DeviceItem.ID) {
    aliases[old] = new
    aliases[new] = nil  // never a cycle: a device that flips back is found directly
  }

  private func saveNames() {
    defaults.set(userNames, forKey: Keys.userNames)
    defaults.set(nameAnchors, forKey: Keys.nameAnchors)
  }

  /// The device with this ID, or the one it became (`carryAcrossNewIDs`).
  func device(_ id: DeviceItem.ID) -> DeviceItem? {
    var current = id
    for _ in 0..<8 {
      if let found = devices.first(where: { $0.id == current }) { return found }
      guard let next = aliases[current] else { return nil }
      current = next
    }
    return nil
  }

  // ── Degradations across a relaunch ────────────────────────────────────────────────

  private enum Keys {
    static let degradations = "lastRunDegradations"
    static let degradationsRun = "lastRunDegradationsRun"
    static let userNames = "userNames"
    static let nameAnchors = "userNameAnchors"
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

// ── Networks ──────────────────────────────────────────────────────────────────────

extension NetworkModel {
  /// Whether the network in view is the one this Mac is on. Always, under fixtures and
  /// `ZHEN_HISTORY`, where there is one history.
  var isViewingCurrentNetwork: Bool { historyURL == currentHistoryURL }

  /// Whether the picker has anything to offer: a network other than the current one.
  var hasOtherNetworks: Bool { networks.contains { !$0.isCurrent } }

  /// The network in view, as the picker names it.
  var networkInView: NetworkChoice? { networks.first { $0.id == historyURL } }

  /// Reads the network this Mac is on and opens its history. With no interface, the most
  /// recently scanned network is shown instead, read only.
  fileprivate func openCurrentNetwork(through runner: LiveScanRunner) async {
    guard let histories, case .perNetwork = histories.layout else {
      // One file for every network: nothing is read to choose one (zhen-core's D6).
      interface = await runner.interface()
      return
    }
    await runner.choose { [weak self] identity in
      await self?.historyStore(for: identity) ?? InMemoryHistoryStore()
    }
    if let current = await runner.currentNetwork() {
      interface = current.interface
      await runner.use(await historyStore(for: current.identity))
    } else if let latest = await histories.known().first {
      store = openStore(at: latest.url)
      historyURL = latest.url
    }
  }

  /// The store a scan of `identity` records into, which becomes the current network and
  /// the one in view. Called by the scan runner once it has read the gateway, so through
  /// the helper's capture device when it has one; `NetworkHistories` migrates and adopts.
  fileprivate func historyStore(for identity: NetworkIdentity) async -> any HistoryStore {
    guard let histories else { return currentStore }
    let url = await histories.url(for: identity)
    currentIdentity = identity
    if url != currentHistoryURL {
      currentStore = openStore(at: url)
      currentHistoryURL = url
    }
    showCurrentNetwork()
    return currentStore
  }

  private func openStore(at url: URL) -> any HistoryStore {
    LogHistoryStore(url: url, retention: Self.retention(days: Preferences(defaults).retentionDays))
  }

  /// Puts the current network back in view. The caller reloads.
  private func showCurrentNetwork() {
    guard currentHistoryURL != nil else { return }
    store = currentStore
    historyURL = currentHistoryURL
  }

  /// Shows another network's history, read only, or the current one again.
  func show(_ network: NetworkChoice) async {
    guard network.id != historyURL, !isBusy else { return }
    if network.id == currentHistoryURL {
      showCurrentNetwork()
    } else {
      store = openStore(at: network.id)
      historyURL = network.id
    }
    await reload()
  }

  /// Rereads the list of networks. Each history is read once for its router's name, so
  /// this runs at launch, after a scan and after an erase, not on every change.
  func refreshNetworks() async {
    guard let histories, case .perNetwork = histories.layout else {
      networks = []
      return
    }
    let known = await histories.known()
    var routers: [URL: String] = [:]
    for network in known {
      let devices = network.url == historyURL
        ? await store.devices() : await LogHistoryStore(url: network.url).devices()
      routers[network.url] = NetworkChoice.routerName(in: devices, gateway: network.identity.gateway)
    }
    networks = NetworkChoice.list(
      known: known, current: currentHistoryURL, currentIdentity: currentIdentity, routers: routers
    )
  }

  /// Erases every network's history, and everything this app kept about it: the names
  /// given to devices, the last run's warnings, this session's port results. What the
  /// person asked for on 2026-11-20 was "everything" (zhen-core 0.10.0).
  ///
  /// Each history through its own store's lock, so a `zhen scan` writing at the same moment
  /// is either erased or recorded after, never half of each.
  func eraseAllHistory() async {
    guard !isBusy else { return }
    await store.erase()
    await currentStore.erase()
    await histories?.eraseAll()
    userNames = [:]
    nameAnchors = [:]
    aliases = [:]
    saveNames()
    portScans = [:]
    lastDegradations = []
    defaults.removeObject(forKey: Keys.degradations)
    defaults.removeObject(forKey: Keys.degradationsRun)
    showCurrentNetwork()
    await reload()
    await refreshNetworks()
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
