// AppModel.swift — the app's state, and the only place a stream meets a view.
//
// `@Observable`, not `ObservableObject`. With per-property change tracking a list of
// devices does not re-render because an unrelated counter moved, and during a scan the
// counters move constantly. At the rates core emits, that is a correctness-of-frame-rate
// property rather than a nicety.
//
// This type is main-actor — the whole app target is, by default. It never awaits a scan
// from a view body; it owns an actor-isolated `ScanRunner` and consumes what that
// produces. Nothing here is ever passed INTO core.

import Foundation
import ZhenCore
import ZhenScan
import Observation
import SwiftUI

/// Everything on screen.
@Observable
final class AppModel {
    // MARK: Navigation

    /// Which room is showing.
    var room: Room = .devices
    /// The selected device's stable id, or nil for the list.
    var selection: DeviceRowModel.ID?
    /// The device-list search term.
    var searchText = ""
    /// The activity filter.
    var category: EventCategory = .all

    // MARK: Scan state

    /// Identifies the current scan attempt.
    ///
    /// **This is what `.task(id:)` keys on.** Bumping it starts a scan; SwiftUI cancels
    /// the previous task, the cancellation reaches `AsyncStream.onTermination`, and the
    /// sockets close. There is no `stopScan()` to forget to call because there is nothing
    /// to call — lifetime is the view's.
    private(set) var scanID = UUID()
    /// Whether a scan is running right now.
    private(set) var isScanning = false
    /// What the live-scan screen shows.
    private(set) var liveState: LiveScanState = .starting
    /// The stage strip.
    private(set) var stages: [StageModel] = Presentation.stages(running: nil, finished: [], detail: [:])
    /// Elapsed, as the header shows it.
    private(set) var elapsed = "0:00"

    // MARK: Results

    /// The device table.
    private(set) var devices: [DeviceRowModel] = []
    /// The activity log.
    private(set) var days: [EventDayModel] = []
    /// The histogram above it.
    private(set) var buckets: [HistogramBucket] = []
    /// What the last run could not do. **Does not clear when a scan ends** — a green dot
    /// over an incomplete run is a lie of omission.
    private(set) var degradations: [DegradationModel] = []
    /// What the sidebar footer says.
    private(set) var activity: ScanActivity = .never
    /// A setup failure that stopped the app scanning at all.
    private(set) var setupFailure: String?

    /// Settings, bound straight to the controls.
    var settings = AppSettings()

    /// What Settings says about the privileged helper.
    ///
    /// Refreshed from `SMAppService` rather than remembered. Starts as `.notInstalled`
    /// because that is the honest answer before the first look, and the first look
    /// happens in `prepare()` before any screen can show it.
    private(set) var helperState: HelperState = .notInstalled

    /// Milliseconds from process start to the first device reaching the screen.
    ///
    /// Miller's 1968 threshold is about 100 ms to feel instantaneous, and it is the whole
    /// reason core exposes a streaming API alongside the terminal one. A number nobody
    /// measures is a number that regresses.
    private(set) var millisToFirstDevice: Double?

    private let store: any HistoryStore
    /// Built on the first `prepare()` rather than in `init`.
    ///
    /// Constructing it asks whether a capture device can be had, and with the helper in
    /// play that question crosses a connection — so it is async, and an `init` cannot
    /// await. Deferring it also gets the window on screen before anything touches the
    /// network, which is the right order for the same reason the first device is
    /// measured to the millisecond.
    private var runner: ScanRunner?
    /// Whether `prepare()` has already run, so `.task` firing twice costs nothing.
    private var isPrepared = false
    private let launchedAt = MonotonicInstant.now
    /// Whether history outlives the process. Settings reads it rather than claiming.
    private(set) var isHistoryPersistent = false
    private var target = "—"

    /// Builds the model, resolving the platform once.
    init() {
        // The same file the command line writes. A person who runs `zhen scan` in a
        // terminal and then opens this is entitled to see the same network, and two
        // tools each keeping their own history would agree only until one of them ran.
        //
        // With nowhere to put a file, history is kept for the session and the Settings
        // screen says so. That is a real degradation and not a failure: a scan with
        // nothing to write to is still a scan, and refusing to launch over a missing
        // home directory would be the app deciding its filing matters more than its job.
        // Before resolving a store to write into: history written under the former name
        // is copied across if this path has none yet. Copy, never move — see
        // `HistoryLocation.migrateLegacyStore`.
        HistoryLocation.migrateLegacyStore(to: HistoryLocation.resolve())
        let store: any HistoryStore = HistoryLocation.resolve()
            .map { LogHistoryStore(url: $0) } ?? InMemoryHistoryStore()
        self.store = store
        self.isHistoryPersistent = HistoryLocation.resolve() != nil
    }

    /// Resolves the platform. Called from the root view's `.task`, once.
    ///
    /// A setup failure lands in `setupFailure` and the app still opens: there is a
    /// screen that says what went wrong, which is worth more than a window that never
    /// appears.
    func prepare() async {
        guard !isPrepared else { return }
        isPrepared = true
        do {
            let runner = try await ScanRunner(store: store)
            self.runner = runner
            self.target = "\(runner.interface.network) · \(runner.interface.name)"
        } catch {
            self.runner = nil
            self.setupFailure = Self.describe(error)
        }
        await refreshHelperState()

        // The launch scan. `.task(id: scanID)` fires once on first appearance, and
        // until this commit the runner existed by then because it was built in `init`.
        // It is built here now, concurrently with that task, so the first firing can
        // find `runner` nil and skip — which looks exactly like an app that launches
        // and does not scan. Bumping the key re-arms it, and `requestScan` already
        // declines when there is no runner or one is in flight.
        requestScan()
    }

    /// Re-reads the helper's registration from the system.
    func refreshHelperState() async {
        helperState = await HelperInstaller.state()
    }

    /// Registers the helper, then re-reads what the system says about it.
    ///
    /// The re-read is the point. `register()` returning without throwing means the
    /// registration was accepted, not that the daemon is running — the usual next state
    /// is `requiresApproval`, which is a thing a person has to go and do. Showing the
    /// registration we asked for rather than the one the system holds would tell them
    /// they are finished when they are not.
    func installHelper() {
        Task {
            if let failure = HelperInstaller.install() {
                helperState = .unavailable(reason: failure)
                return
            }
            await refreshHelperState()
        }
    }

    /// Unregisters it, then re-reads.
    ///
    /// Also rebuilds the scanner, because the composition decided whether the privileged
    /// engines exist at all when `prepare()` ran. Leaving that alone would keep a
    /// composite engine pointed at a helper that is gone, and every sweep would spend
    /// its connection timeout discovering it on the way to the fallback that was always
    /// there.
    func removeHelper() {
        Task {
            if let failure = HelperInstaller.remove() {
                helperState = .unavailable(reason: failure)
                return
            }
            await refreshHelperState()
            isPrepared = false
            await prepare()
        }
    }

    /// What Settings says about where history goes.
    ///
    /// Read from the store that was actually opened rather than stated, because the
    /// answer depends on whether a path resolved at launch and the screen has no other
    /// way to know. Claiming persistence the app does not have is worse than admitting
    /// the session-only case: a person who believes their history is kept will not
    /// notice it is not until the day they go looking for something old.
    var historyDescription: String {
        isHistoryPersistent
            ? "history kept on disk, shared with the command line"
            : "history kept in memory for this session"
    }

    /// The sidebar footer's target line.
    var targetDescription: String { target }
    /// The device count badge.
    var deviceCount: Int { devices.count }
    /// The event count badge.
    var eventCount: Int { days.reduce(0) { $0 + $1.events.count } }

    /// What the device list should render.
    var listState: DeviceListState {
        if let setupFailure {
            return .loaded(devices: [], degradations: [
                DegradationModel(cause: "No interface to scan", consequence: setupFailure,
                                 actionTitle: nil),
            ])
        }
        if devices.isEmpty {
            return hasScanned ? .nothingAnswered : .neverScanned
        }
        return .loaded(devices: devices, degradations: degradations)
    }

    private var hasScanned = false

    /// Starts a scan by changing the key the view's task is bound to.
    func requestScan() {
        guard runner != nil, !isScanning else { return }
        scanID = UUID()
    }

    // MARK: The scan itself

    /// Consumes one scan. Called from `.task(id: scanID)` and cancelled by SwiftUI.
    ///
    /// ── Why the coalescing is here and not in the view ────────────────────────────
    ///
    /// Core emits far faster than 60 Hz — a `/24` sweep is hundreds of progress events in
    /// under half a second — and SwiftUI will try to keep up with every one until it
    /// cannot. Two children run concurrently: one drains the stream into a plain buffer
    /// that nothing observes, the other publishes a snapshot at display rate. The
    /// observable properties therefore change about sixty times a second no matter what
    /// the network does.
    func runScan() async {
        guard let runner, !isScanning else { return }
        // Before the scan, because the scan is what folds a run in and a fold is the
        // only moment anything is pruned. Set here rather than at construction: the
        // picker can change while the app is open, and a retention setting that needed a
        // relaunch would be a second version of the defect it is fixing.
        await store.setRetention(settings.retentionPolicy)
        isScanning = true
        liveState = .starting
        stages = Presentation.stages(running: .discovery, finished: [], detail: [:])
        defer { isScanning = false }

        let started = MonotonicInstant.now
        let (events, sink, finish) = ProbeStream.sinking(buffering: .progress)
        let batch = EventBatch()

        let budget = settings.budget
        let deep = settings.deepScanNewDevices
        let completed: CompletedScan? = await withTaskGroup(of: CompletedScan?.self) { group in
            // The scan. Non-isolated all the way down: `runner` is a `Sendable` struct
            // over core's engines, and the only thing crossing back is a frozen value.
            group.addTask {
                let result = await runner.run(budget: budget, deepScan: deep, progress: sink)
                finish()
                return result
            }
            // The drain. Appends to a buffer nothing observes.
            group.addTask {
                for await event in events { await batch.append(event) }
                await batch.close()
                return nil
            }

            // The publisher runs HERE, in the group's body, which is already on the main
            // actor — rather than as a third `@MainActor` child. A main-actor child in a
            // group of non-isolated ones is what the region-based isolation checker
            // cannot reason about, and the annotation that silences it would be exactly
            // the annotation this package's target split exists to avoid.
            while !(await batch.isClosed) {
                try? await Task.sleep(for: .milliseconds(16))
                apply(await batch.drain(), since: started)
            }

            var finished: CompletedScan?
            for await value in group where value != nil { finished = value }
            return finished
        }

        // Anything the last tick missed, including everything after cancellation.
        apply(await batch.drain(), since: started)
        if let completed { await commit(completed) }
    }

    /// Folds a batch of progress events into the live screen.
    private func apply(_ events: [ProbeEvent], since started: MonotonicInstant) {
        guard !events.isEmpty else { return }
        var running = currentStage
        var done = finishedStages
        var detail = stageDetail
        var newDegradations = degradations

        for event in events {
            switch event {
            case .stageStarted(let stage):
                running = stage
            case .stageProgress(let stage, let completed, let total):
                running = stage
                detail[stage] = "\(completed) of \(total)"
            case .stageFinished(let timing):
                done.insert(timing.stage)
                detail[timing.stage] = "\(timing.hostsFound.map { "\($0) found · " } ?? "")"
                    + String(format: "%.1f s", timing.elapsedMillis / 1000)
            case .hostFound(let host), .hostUpdated(let host):
                findings[host.ip] = host
                if millisToFirstDevice == nil {
                    let millis = MonotonicInstant.now.duration(since: launchedAt).milliseconds
                    millisToFirstDevice = millis
                    // Miller's threshold is ~100 ms to feel instantaneous, and it is the
                    // reason core has a streaming API at all. Written to stderr because a
                    // number nobody can read is a number that regresses unnoticed.
                    FileHandle.standardError.write(Data(
                        String(format: "zhen: first device on screen at %.0f ms\n", millis).utf8
                    ))
                }
            case .degraded(let degradation):
                let model = Presentation.degradation(degradation)
                if !newDegradations.contains(model) { newDegradations.append(model) }
            }
        }

        currentStage = running
        finishedStages = done
        stageDetail = detail
        degradations = newDegradations
        stages = Presentation.stages(running: running, finished: done, detail: detail)
        elapsed = Presentation.elapsed(MonotonicInstant.now.duration(since: started).milliseconds)
        liveState = .running(findings: findings.values
            .sorted { $0.ip < $1.ip }
            .map(Self.finding))
    }

    /// Publishes the finished artifact.
    ///
    /// **Everything shown as fact comes from here**, not from the events above. The
    /// progress channel is lossy by design; the envelope is not.
    /// Shows what history already knows, before anything is scanned.
    ///
    /// Without this the store was written and never read back at launch: the app opened
    /// on "No scan yet" with a full history file beside it, scanned, and only then
    /// remembered — which is indistinguishable from not persisting at all for the one
    /// moment a person is looking to see whether it remembered.
    ///
    /// `hasScanned` stays false. Nothing has been scanned in this run, and the empty
    /// states depend on that distinction: a store with no devices in it means "nothing
    /// answered last time", not "nothing answered just now".
    func loadHistory() async {
        guard !hasScanned, devices.isEmpty else { return }
        let now = Timestamp.now
        let stored = await store.devices()
        guard !stored.isEmpty else { return }
        devices = Presentation.rows(stored, now: now)
        let log = await store.events()
        days = Presentation.days(log, now: now)
        buckets = Self.histogram(log, now: now)
        // Dated from the run that wrote it, not from now — "last scan just now" on an
        // app that has not scanned would be a lie told at launch.
        if let run = await store.latestRun() {
            activity = .idle(relative: Presentation.relative(
                run.finishedAt ?? run.startedAt, now: now
            ))
        }
    }

    private func commit(_ completed: CompletedScan) async {
        hasScanned = true
        let now = Timestamp.now
        let stored = await store.devices()
        devices = Presentation.rows(stored, now: now)
        let log = await store.events()
        days = Presentation.days(log, now: now)
        buckets = Self.histogram(log, now: now)
        degradations = completed.report.degradations.map(Presentation.degradation)
        activity = degradations.isEmpty
            ? .idle(relative: "just now")
            : .partial(relative: "just now", unavailableSources: degradations.count)
        findings.removeAll()
        currentStage = nil
        finishedStages = []
        stageDetail = [:]
        if completed.report.run.outcome == .cancelled {
            liveState = .stopped(findings: [], elapsed: elapsed)
        }
        // Back to the list. A finished scan should not need dismissing.
        if room == .devices { selection = nil }
    }

    /// The detail model for the current selection, if it resolves to a device.
    func detail(for id: DeviceRowModel.ID) async -> DeviceDetailModel? {
        let now = Timestamp.now
        let log = await store.events()
        guard let match = await store.devices().first(where: {
            Presentation.identity($0.device) == id
        }) else { return nil }
        return Presentation.detail(match, now: now, events: log)
    }

    // MARK: Live-scan scratch state
    //
    // Not observable. These accumulate at stream rate and are read once per published
    // frame; making them observable would defeat the coalescing entirely.

    @ObservationIgnored private var findings: [IPv4Address: HostFacts] = [:]
    @ObservationIgnored private var currentStage: Stage?
    @ObservationIgnored private var finishedStages: Set<Stage> = []
    @ObservationIgnored private var stageDetail: [Stage: String] = [:]

    private static func finding(_ host: HostFacts) -> ScanFindingModel {
        ScanFindingModel(
            id: host.ip.description,
            name: host.displayName,
            detail: host.displayName == nil
                ? "found · still being named"
                : "named by \(host.allNames.best?.source.label ?? "a scan")",
            ip: host.ip.description,
            mac: host.mac?.description,
            note: host.mac?.isLocallyAdministered == true
                ? "randomized MAC — vendor lookup not possible"
                : (host.rtt == nil ? "in ARP table only" : "responds to ping")
        )
    }

    private static func histogram(_ events: [DerivedEvent], now: Timestamp) -> [HistogramBucket] {
        guard !events.isEmpty else { return [] }
        let hours = 48
        var counts = [Int](repeating: 0, count: hours)
        for event in events {
            let ago = Int((now.millisecondsSinceEpoch - event.at.millisecondsSinceEpoch) / 3_600_000)
            let index = hours - 1 - min(max(ago, 0), hours - 1)
            counts[index] += 1
        }
        return counts.enumerated().map { HistogramBucket(hour: $0.offset, count: $0.element) }
    }

    private static func describe(_ error: PlatformError) -> String {
        switch error {
        case .unavailable(let what): "\(what) This machine has no interface this app can scan through."
        case .denied(let what): "\(what) Scanning was refused by the system."
        case .notFound(let what): "\(what)"
        case .systemError(let code, let api): "\(api) failed with errno \(code)."
        }
    }
}

/// The buffer between the scanner's rate and the screen's.
///
/// An actor rather than a lock because both ends are already async and the critical
/// section is an array append. Nothing observes it, which is the point: the view model's
/// published properties change at display rate no matter how fast core emits.
actor EventBatch {
    private var pending: [ProbeEvent] = []
    private var closed = false

    func append(_ event: ProbeEvent) { pending.append(event) }

    /// Marks the stream finished, which is what ends the publisher loop.
    func close() { closed = true }

    /// Whether the producer has finished.
    var isClosed: Bool { closed }

    func drain() -> [ProbeEvent] {
        defer { pending.removeAll(keepingCapacity: true) }
        return pending
    }
}

/// Scan and history preferences, bound straight to the Settings controls.
///
/// Persisted, because a preference that resets when you quit is not a preference. Every
/// one of these was a value the app forgot the moment it closed — you would set a scan
/// budget, quit, and be back to the default without ever being told.
///
/// `UserDefaults` rather than the history store. These are about how this copy of the
/// app behaves, not about what is on the network; putting them in the shared history
/// file would mean the command line inherited the app's preferences, which is not a
/// thing either of them asked for.
@Observable
final class AppSettings {
    /// How long a scan may take.
    var budgetLabel: String = "20 seconds" {
        didSet { AppSettings.save(.budget, budgetLabel) }
    }
    /// Whether to probe ports on hosts that answered.
    var deepScanNewDevices: Bool = false {
        didSet { AppSettings.save(.deepScan, deepScanNewDevices) }
    }
    /// How long events are kept.
    var keepEventsFor: String = "Forever" {
        didSet { AppSettings.save(.retention, keepEventsFor) }
    }
    /// Automatic rescans.
    var scanInterval: String = "Off" {
        didSet { AppSettings.save(.interval, scanInterval) }
    }

    /// Reads what was stored last time.
    ///
    /// Assigned in `init` rather than in the property initializers because `@Observable`
    /// rewrites stored properties and a `Self.` reference in one of their initializers
    /// does not survive the expansion. Assigning here also means `didSet` has not run
    /// yet, so loading does not immediately write back what it just read.
    init() {
        budgetLabel = AppSettings.load(
            .budget, from: AppSettings.budgetOptions, default: budgetLabel
        )
        keepEventsFor = AppSettings.load(
            .retention, from: AppSettings.retentionOptions, default: keepEventsFor
        )
        scanInterval = AppSettings.load(
            .interval, from: AppSettings.intervalOptions, default: scanInterval
        )
        deepScanNewDevices = UserDefaults.standard.bool(forKey: Key.deepScan.rawValue)
    }

    // ── Storage ─────────────────────────────────────────────────────────────────
    //
    // Keys are spelled out in one enum rather than inline at eight call sites. A typo in
    // a defaults key does not fail: it silently reads the default forever, which is the
    // same symptom as not persisting at all and is harder to notice, because it works
    // correctly once per launch.
    private enum Key: String {
        case budget = "scan.budget"
        case deepScan = "scan.deepScanNewDevices"
        case retention = "history.keepEventsFor"
        case interval = "scan.interval"
    }

    /// A stored choice, if it is still one of the choices.
    ///
    /// An option removed between versions falls back rather than leaving a picker
    /// showing a value it cannot offer — which renders as an empty menu button and looks
    /// like a bug in the control rather than a stale preference.
    private static func load(
        _ key: Key, from options: [String], default fallback: String
    ) -> String {
        guard let stored = UserDefaults.standard.string(forKey: key.rawValue),
              options.contains(stored)
        else { return fallback }
        return stored
    }

    private static func save(_ key: Key, _ value: String) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private static func save(_ key: Key, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    /// The retention policy as core wants it.
    ///
    /// The strings are what the picker offers and A3 wrote; this is the only place they
    /// mean anything. A year is 365 days and not 365.25 — a person choosing "1 year" is
    /// asking for roughly a year of events, and a leap day either way is not a thing
    /// anybody is measuring against.
    ///
    /// An unrecognized string falls back to keeping everything, which is the direction
    /// that cannot lose history a person did not ask to lose.
    var retentionPolicy: RetentionPolicy {
        switch keepEventsFor {
        case "30 days": .days(30)
        case "90 days": .days(90)
        case "1 year": .days(365)
        default: .forever
        }
    }

    /// The budget as core wants it.
    var budget: Duration {
        switch budgetLabel {
        case "5 seconds": .seconds(5)
        case "10 seconds": .seconds(10)
        case "60 seconds": .seconds(60)
        default: .seconds(20)
        }
    }

    static let budgetOptions = ["5 seconds", "10 seconds", "20 seconds", "60 seconds"]
    static let intervalOptions = ["Off", "Every 5 minutes", "Every 15 minutes", "Every 60 minutes"]
    static let retentionOptions = ["30 days", "90 days", "1 year", "Forever"]
}
