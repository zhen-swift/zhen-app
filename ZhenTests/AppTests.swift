import Foundation
import Testing
@testable import Zhen
@testable import ZhenCore
@testable import ZhenScan

// The wiring, checked where it is objectively checkable.
//
// The screens are checked by looking at them and the design system's own suite pins the
// contrast table. What is left — and what this file covers — is the three places a
// silent, invisible wrong answer is possible: the Bonjour declaration, the mapping from
// core's vocabulary to the design system's, and the store's identity join.

@Suite("The Bonjour declaration cannot drift from what is browsed")
struct InfoPlistTests {
    /// The repository root, five levels up from this file.
    ///
    /// Counted rather than guessed: this file is at
    /// `zhen-app/ZhenTests/AppTests.swift`, so reaching the
    /// root takes five. An earlier version used four, landed in `Packages/`, and every
    /// test that read a file through it took its `guard … else { return }` and reported
    /// success without checking anything. A skip that looks like a pass is worse than a
    /// failure, so this is computed once and asserted below.
    static let repositoryRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // ZhenTests
        .deletingLastPathComponent()   // zhen-app
        .deletingLastPathComponent()   // the repository

    @Test("The repository root resolves, so the file-reading tests are not silently skipping")
    func rootResolves() {
        #expect(FileManager.default.fileExists(
            atPath: Self.repositoryRoot.appendingPathComponent("Package.swift").path
        ) == false)
        #expect(FileManager.default.fileExists(
            atPath: Self.repositoryRoot.appendingPathComponent("zhen/Package.swift").path
        ), "repositoryRoot is not the repository root")
    }

    /// Parses the generated plist.
    private func generated() throws -> [String: Any] {
        let data = Data(InfoPlist.xml().utf8)
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(parsed as? [String: Any])
    }

    @Test("The generated plist is valid and carries the bundle identity")
    func identity() throws {
        let plist = try generated()
        #expect(plist["CFBundleIdentifier"] as? String == "com.jctec.zhen")
        #expect(plist["CFBundleName"] as? String == "Zhen")
        #expect(plist["CFBundleExecutable"] as? String == "Zhen")
        #expect(plist["NSPrincipalClass"] as? String == "NSApplication")
    }

    @Test("Every browsed service type is declared, and nothing else is")
    func bonjourServicesMatchExactly() throws {
        // Document 03's note on the Local Network permission: a type that is browsed but
        // undeclared returns NOTHING, silently, with no error anywhere — the failure
        // looks exactly like a network with no such device on it. Core runs the
        // equivalent check for the CLI's hand-written plist; this app's is generated from
        // the same array, so the test is proving the generator rather than a human's
        // diligence. It still earns its place: nothing else would catch someone
        // "simplifying" the generator to a literal.
        let declared = try #require(try generated()["NSBonjourServices"] as? [String])
        #expect(declared == BonjourVocabulary.browsedTypes)
        #expect(declared.count == 17)
        #expect(declared.contains("_googlecast._tcp"))
        #expect(declared.contains("_sleep-proxy._udp"))
    }

    @Test("The usage description says what a person needs to decide")
    func usageDescription() throws {
        // This string is the entire explanation shown before the one decision that
        // determines whether the app works at all.
        let usage = try #require(try generated()["NSLocalNetworkUsageDescription"] as? String)
        #expect(usage.contains("network"))
        #expect(usage.count > 40, "the usage description is too short to explain anything")
    }

    @Test("The checked-in App/Info.plist matches the generator")
    func checkedInPlistAgrees() throws {
        // `Scripts/build-app.sh` generates the plist by asking the binary. The Xcode
        // project cannot — it needs a file on disk before anything is compiled — so
        // `App/Info.plist` is checked in, and a checked-in copy of a generated file is
        // exactly the drift this whole arrangement exists to prevent.
        //
        // Regenerate with:
        //     swift run --package-path zhen-app Zhen \
        //         --print-info-plist > App/Info.plist
        let url = Self.repositoryRoot.appendingPathComponent("zhen-app/Resources/Info.plist")
        guard let data = try? Data(contentsOf: url) else {
            Issue.record("App/Info.plist is missing — the Xcode app target cannot build without it")
            return
        }
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        let plist = try #require(parsed as? [String: Any])
        #expect(plist["NSBonjourServices"] as? [String] == BonjourVocabulary.browsedTypes)
        #expect(plist["CFBundleIdentifier"] as? String == "com.jctec.zhen")
        #expect(plist["CFBundleExecutable"] as? String == "Zhen")
        // Byte-for-byte, so a hand edit anywhere in the file is caught rather than only
        // an edit to the two keys above.
        #expect(String(decoding: data, as: UTF8.self) == InfoPlist.xml() + "\n")
    }

    @Test("The built bundle, when one exists, matches the generator")
    func builtBundleAgrees() throws {
        // Skipped rather than failed when the bundle is absent: `swift test` must work
        // without anyone having run the build script first.
        let bundle = Self.repositoryRoot
            .appendingPathComponent("build/Zhen.app/Contents/Info.plist")
        guard let data = try? Data(contentsOf: bundle) else { return }
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        let plist = try #require(parsed as? [String: Any])
        #expect(plist["NSBonjourServices"] as? [String] == BonjourVocabulary.browsedTypes)
        #expect(plist["CFBundleIdentifier"] as? String == "com.jctec.zhen")
    }
}

@Suite("Core's records become the design system's models")
struct PresentationTests {
    private func device(
        ip: String, mac: String?, name: String? = nil, model: String? = nil,
        rtt: Double? = nil, ttl: UInt8? = nil
    ) -> Device {
        var names: [NameCandidate] = []
        if let name { names.append(NameCandidate(value: name, source: .mdns, rank: 1, model: model)) }
        let facts = HostFacts(
            ip: IPv4Address(ip)!,
            mac: mac.flatMap(MACAddress.init),
            allNames: names,
            ttl: ttl,
            rtt: rtt.map { RTTSample(millis: $0) }
        )
        return Device(observing: facts, in: IPv4Network("10.10.20.0/24")!, lastSeen: .now)
    }

    @Test("A named device reads as what it is")
    func namedSubtitle() {
        let subtitle = Presentation.subtitle(
            device(ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1",
                   name: "Sala de entretenimiento", model: "AppleTV5,3", rtt: 14.7, ttl: 64)
        )
        #expect(subtitle == "Named by Bonjour · AppleTV5,3 · no vendor · responds to ping")
    }

    @Test("The acceptance case reads as an answer, not as a gap")
    func anonymousSubtitle() {
        // Nothing named it, the MAC rotates so there is no vendor to look up, and it
        // never answered a ping — the emptiest row the product can produce. Every clause
        // is something we know rather than something missing.
        let subtitle = Presentation.subtitle(
            device(ip: "10.10.20.12", mac: "32:37:C0:BC:FC:29")
        )
        #expect(subtitle == "No name advertised · randomized MAC · no vendor · in ARP table, no ping reply")
        #expect(!subtitle.contains("—"), "an em dash here would read as a missing value")
    }

    @Test("Answering a ping is distinguished from being in the neighbour table")
    func evidenceClause() {
        // The distinction is real: one host replied to us, the other is remembered by the
        // kernel because this machine talked to it. Collapsing them would overstate what
        // the scan observed.
        let pinged = Presentation.subtitle(device(ip: "10.10.20.3", mac: "86:9F:FD:F7:9C:B3", rtt: 61.7, ttl: 32))
        let quiet = Presentation.subtitle(device(ip: "10.10.20.24", mac: "36:98:A5:EB:A9:61"))
        #expect(pinged.hasSuffix("responds to ping"))
        #expect(quiet.hasSuffix("in ARP table, no ping reply"))
    }

    @Test("The confidence meter is bound to identification, never to key stability")
    func meterBinding() {
        // The case that proves it: a rotating private MAC AND a clean Bonjour name. The
        // join key is weak; what the thing IS, we know.
        let macbook = device(ip: "10.10.20.8", mac: "52:A1:8A:E0:7A:8A", name: "JC\u{2019}s MacBook Pro")
        #expect(macbook.identityStability == .moderate)
        #expect(Presentation.level(macbook.identification) == .identified)
        // And the inverse: a universal MAC that nothing named.
        let router = device(ip: "10.10.20.1", mac: "78:20:51:74:CB:28", rtt: 14.4, ttl: 64)
        #expect(router.identityStability == .strong)
        #expect(Presentation.level(router.identification) != .identified)
    }

    @Test("Key stability appears in the caption and nowhere else")
    func stabilityIsOnlyInTheCaption() {
        let weak = device(ip: "10.10.20.12", mac: "32:37:C0:BC:FC:29")
        #expect(Presentation.identityCaption(weak).contains("may fragment"))
        // The row carries no trace of it.
        let row = Presentation.row(StoredDevice(device: weak, isPresent: true), now: .now)
        #expect(!row.subtitle.lowercased().contains("fragment"))
        #expect(!row.subtitle.lowercased().contains("stability"))
    }

    @Test("Sources that offered nothing are shown, not hidden")
    func absentSourcesAreListed() {
        let named = device(ip: "10.10.20.8", mac: "52:A1:8A:E0:7A:8A", name: "JC\u{2019}s MacBook Pro")
        let candidates = Presentation.nameCandidates(named)
        // Every source, every time — the absence is how a person sees that we asked.
        #expect(candidates.count == NameSource.allCases.count)
        #expect(candidates.filter(\.isWinner).count == 1)
        #expect(candidates.first { $0.source == "Bonjour" }?.candidate == "JC\u{2019}s MacBook Pro")
        #expect(candidates.first { $0.source == "UPnP" }?.candidate == nil)
        // A user override is "not set", not "not advertised": nobody asked the network.
        #expect(candidates.first { $0.source == "You" }?.absenceNote == "— not set")
    }

    @Test("Row identity is stable and is not the address")
    func identityIsNotTheAddress() {
        // Addresses move. An unstable key turns every list update into a teardown and
        // rebuild rather than a diff of what changed.
        let before = device(ip: "10.10.20.9", mac: "52:A1:8A:E0:7A:8A", name: "JC\u{2019}s MacBook Pro")
        let after = device(ip: "10.10.20.8", mac: "52:A1:8A:E0:7A:8A", name: "JC\u{2019}s MacBook Pro")
        #expect(Presentation.identity(before) == Presentation.identity(after))
        #expect(!Presentation.identity(after).contains("10.10.20"))
    }

    @Test("No device is labelled the gateway, because the gateway is not knowable")
    func gatewayChipIsNeverSet() {
        // Core does not expose the default route's address — see
        // `Presentation.gatewayIsNotKnowable`. Guessing "the .1 address" would be right
        // on most home networks and wrong on some, and this tool's pitch is that it does
        // not guess.
        let router = Presentation.row(
            StoredDevice(device: device(ip: "10.10.20.1", mac: "78:20:51:74:CB:28", rtt: 14.4, ttl: 64),
                         isPresent: true),
            now: .now
        )
        #expect(!router.isGateway)
    }
}

// Every one of these runs against BOTH conformances, and that is the point of the
// suite rather than a convenience.
//
// Two stores behind one protocol are only one idea if they behave identically, and
// "identically" is not a thing a protocol can require — it has no opinion about whether
// two devices swapping DHCP leases merge. Running the same expectations against both is
// what turns the seam from a shape into a claim. `HistoryLedger` is what makes them
// pass, but a test that reached for the ledger directly would prove the rules and not
// the stores, and it is the stores the rest of the app talks to.
//
// The two are the two that ship. Until the 2026-09-11 ruling this suite ran against the
// in-memory store and the SwiftData one — and `LogHistoryStore`, which is what the app
// and the command line actually open, was in neither. The seam was being proved against
// a conformance nobody ran.
enum StoreUnderTest: String, Sendable, CaseIterable, CustomStringConvertible {
    case inMemory
    case log
    var description: String { rawValue }
}

/// A class rather than a struct, so `deinit` can take the temporary files away.
///
/// Swift Testing makes one instance per test, which makes a deinit exactly a teardown.
/// The alternative was a `defer` in every test, threaded through a helper that is
/// parameterised over two constructors — more places to forget it than tests to use it.
@Suite("The session store joins on identity, not on address")
final class HistoryStoreTests: Sendable {
    private let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("zhen-store-\(UUID().uuidString)", isDirectory: true)

    deinit { try? FileManager.default.removeItem(at: directory) }

    /// A fresh, empty store of the given kind.
    ///
    /// The file-backed one gets a real file: it is the conformance whose behaviour is a
    /// file, and giving it anything else would be testing a different type.
    /// A clock the tests move by hand, for the conformances that have one.
    ///
    /// `LogHistoryStore` applies retention when it replays the file as well as when it
    /// folds a run in, so a test built on synthetic 1970-relative timestamps would find
    /// every event outside a thirty-day window measured from the real today. That is the
    /// store being right and the test being wrong about what time it is.
    /// `nonisolated` because this package builds with `.defaultIsolation(MainActor.self)`
    /// and the store reads the clock from whatever context it replays the file on.
    nonisolated final class TestClock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Timestamp
        init(_ value: Timestamp) { self.value = value }
        var now: Timestamp { lock.lock(); defer { lock.unlock() }; return value }
        func set(_ value: Timestamp) { lock.lock(); self.value = value; lock.unlock() }
    }

    private func store(_ kind: StoreUnderTest, clock: TestClock? = nil) throws -> any HistoryStore {
        switch kind {
        case .inMemory:
            return InMemoryHistoryStore()
        case .log:
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            let url = directory.appendingPathComponent("\(UUID().uuidString).ndjson")
            guard let clock else { return LogHistoryStore(url: url) }
            return LogHistoryStore(url: url, clock: { clock.now })
        }
    }

    private func report(
        _ devices: [Device], runID: UUID = UUID(), at: Timestamp = .now
    ) -> ScanReport {
        ScanReport(
            run: ScanRun(
                id: runID, startedAt: at, finishedAt: at,
                target: IPv4Network("10.10.20.0/24")!, interface: "en0",
                engine: EngineDescriptor(name: "test", kind: .unprivileged, capabilities: []),
                outcome: .complete, timing: Timing()
            ),
            devices: devices
        )
    }

    private func device(ip: String, mac: String?, name: String? = nil, at: Timestamp = .now) -> Device {
        var names: [NameCandidate] = []
        if let name { names.append(NameCandidate(value: name, source: .mdns, rank: 1)) }
        return Device(
            observing: HostFacts(ip: IPv4Address(ip)!, mac: mac.flatMap(MACAddress.init), allNames: names),
            in: IPv4Network("10.10.20.0/24")!, firstSeen: at, lastSeen: at
        )
    }

    // What the setting is for, asked of every conformance. The rule is `HistoryLedger`'s
    // and is tested there against a clock nobody has to wait for; what is tested here is
    // that each store hands the policy on and writes the result down.
    @Test("A retention policy reaches the store, and takes events rather than devices",
          arguments: StoreUnderTest.allCases)
    func retentionPrunesEventsOnly(kind: StoreUnderTest) async throws {
        let day: (Int) -> Timestamp = { Timestamp(millisecondsSinceEpoch: Int64($0) * 86_400_000) }
        let clock = TestClock(day(101))
        let store = try store(kind, clock: clock)
        await store.setRetention(.days(30))
        let first = device(ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1", at: day(100))
        let second = device(ip: "10.10.20.8", mac: "52:A1:8A:E0:7A:8A", at: day(101))

        _ = await store.record(report([first], at: day(100)))
        _ = await store.record(report([first, second], at: day(101)))
        #expect(await store.events().count == 1, "the second device did not appear")

        clock.set(day(191))
        _ = await store.record(report([first, second], at: day(191)))
        #expect(await store.events().isEmpty, "an event outside the window was kept")
        #expect(await store.devices().count == 2,
                "retention deleted a device record, so it will be reported as new")
    }

    @Test("A store keeps every event unless it is told otherwise",
          arguments: StoreUnderTest.allCases)
    func defaultRetentionIsForever(kind: StoreUnderTest) async throws {
        let store = try store(kind)
        let day: (Int) -> Timestamp = { Timestamp(millisecondsSinceEpoch: Int64($0) * 86_400_000) }
        let first = device(ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1", at: day(0))
        let second = device(ip: "10.10.20.8", mac: "52:A1:8A:E0:7A:8A", at: day(1))
        _ = await store.record(report([first], at: day(0)))
        _ = await store.record(report([first, second], at: day(1)))
        _ = await store.record(report([first, second], at: day(10_000)))
        #expect(await store.events().count == 1, "a store nobody configured deleted an event")
    }

    @Test("A first run produces no events, because everything is new",
          arguments: StoreUnderTest.allCases)
    func firstRunIsQuiet(kind: StoreUnderTest) async throws {
        // Eight "appeared" rows on a first launch is noise, not history.
        let store = try store(kind)
        let events = await store.record(report([
            device(ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1"),
            device(ip: "10.10.20.8", mac: "52:A1:8A:E0:7A:8A"),
        ]))
        #expect(events.isEmpty)
        #expect(await store.devices().count == 2)
    }

    @Test("First-seen survives into the next run", arguments: StoreUnderTest.allCases)
    func firstSeenIsPreserved(kind: StoreUnderTest) async throws {
        // `Device(observing:…)` defaults first-seen to last-seen, which is right on a
        // first-ever run and silently wrong afterwards. The store is what makes it right.
        let store = try store(kind)
        let early = Timestamp(millisecondsSinceEpoch: 1_000_000)
        _ = await store.record(report([device(ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1", at: early)]))
        let facts = HostFacts(ip: IPv4Address("10.10.20.2")!, mac: MACAddress("C8:69:CD:7F:33:E1"))
        let seen = await store.firstSeen(for: [facts], in: IPv4Network("10.10.20.0/24")!)
        #expect(seen[IPv4Address("10.10.20.2")!] == early)
    }

    @Test("A device that moves address stays one device and says so",
          arguments: StoreUnderTest.allCases)
    func addressChangeIsOneDevice(kind: StoreUnderTest) async throws {
        let store = try store(kind)
        _ = await store.record(report([device(ip: "10.10.20.9", mac: "52:A1:8A:E0:7A:8A", name: "Mac")]))
        let events = await store.record(report([device(ip: "10.10.20.8", mac: "52:A1:8A:E0:7A:8A", name: "Mac")]))
        #expect(await store.devices().count == 1, "a moved device must not become two")
        #expect(events.contains { $0.kind == .ipChanged })
    }

    @Test("A device that stops answering is marked absent, not deleted",
          arguments: StoreUnderTest.allCases)
    func disappearanceIsAState(kind: StoreUnderTest) async throws {
        // Offline is a fact about a RUN, and the row stays: "seen two hours ago" is
        // information, and deleting it would silently shrink the network.
        let store = try store(kind)
        _ = await store.record(report([
            device(ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1"),
            device(ip: "10.10.20.25", mac: "20:1C:3A:91:9E:54"),
        ]))
        let events = await store.record(report([device(ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1")]))
        let devices = await store.devices()
        #expect(devices.count == 2)
        #expect(devices.first { $0.device.ip.description == "10.10.20.25" }?.isPresent == false)
        #expect(events.contains { $0.kind == .disappeared })
    }

    @Test("Two devices swapping leases do not merge", arguments: StoreUnderTest.allCases)
    func antiCollapseGuard(kind: StoreUnderTest) async throws {
        // A wrong merge is far worse than a missed one: merging is recoverable and
        // un-merging is not. An ipLease match is the last resort, and only when nothing
        // stronger matched.
        let store = try store(kind)
        _ = await store.record(report([
            device(ip: "10.10.20.30", mac: "AA:BB:CC:00:00:01"),
            device(ip: "10.10.20.31", mac: "AA:BB:CC:00:00:02"),
        ]))
        _ = await store.record(report([
            device(ip: "10.10.20.31", mac: "AA:BB:CC:00:00:01"),
            device(ip: "10.10.20.30", mac: "AA:BB:CC:00:00:02"),
        ]))
        #expect(await store.devices().count == 2, "the two devices merged when they swapped leases")
    }
}

// Retention is the one setting that deletes, which makes "does it reach the store" the
// wrong question to leave to inspection: for a release it did not reach it at all, and
// nothing failed — the picker saved a choice to `UserDefaults` and no code read it.
@Suite("The retention picker means something")
struct RetentionTests {
    @Test("Every option the picker offers maps to a policy")
    func everyOptionMaps() {
        let settings = AppSettings()
        let original = settings.keepEventsFor
        defer { settings.keepEventsFor = original }

        var seen: Set<RetentionPolicy> = []
        for option in AppSettings.retentionOptions {
            settings.keepEventsFor = option
            seen.insert(settings.retentionPolicy)
        }
        // Four options, four distinct policies. An option added to the list without a
        // case added to the mapping falls through to `.forever` and silently becomes a
        // second "Forever" — which reads, from the screen, as a setting that does nothing.
        #expect(seen.count == AppSettings.retentionOptions.count,
                "two options mean the same thing, so one of them does nothing")

        settings.keepEventsFor = "Forever"
        #expect(settings.retentionPolicy == .forever)
        settings.keepEventsFor = "30 days"
        #expect(settings.retentionPolicy == .days(30))
        settings.keepEventsFor = "1 year"
        #expect(settings.retentionPolicy == .days(365))
    }

    @Test("An unrecognized stored choice keeps everything rather than deleting something")
    func unknownFallsBackToForever() {
        let settings = AppSettings()
        let original = settings.keepEventsFor
        defer { settings.keepEventsFor = original }
        settings.keepEventsFor = "a fortnight"
        #expect(settings.retentionPolicy == .forever,
                "an unreadable preference deleted history nobody asked to delete")
    }
}

@Suite("Two devices at one address are legible as two devices")
struct SharedAddressPresentationTests {
    private static let network = IPv4Network("10.10.20.0/24")!

    private func stored(ip: String, mac: String, present: Bool) -> StoredDevice {
        StoredDevice(
            device: Device(
                observing: HostFacts(ip: IPv4Address(ip)!, mac: MACAddress(mac)),
                in: Self.network,
                firstSeen: Timestamp(millisecondsSinceEpoch: 1_700_000_000_000),
                lastSeen: Timestamp(millisecondsSinceEpoch: 1_700_000_000_000)
            ),
            isPresent: present
        )
    }

    @Test("The one that answered owns the address; the one that did not says so")
    func reassignedAddressIsMarked() {
        // The case from the running app: 10.10.20.119 held by two records with
        // different MACs, one seen fourteen hours ago and one answering now. The ledger
        // is right to keep both — its anti-collapse guard refuses to join on a lease
        // because two devices swapping leases must never become one — and the list was
        // showing the same bold address twice with nothing to say which held it.
        let rows = Presentation.rows(
            [
                stored(ip: "10.10.20.119", mac: "A2:6A:35:C9:0A:BD", present: false),
                stored(ip: "10.10.20.119", mac: "92:B8:DD:93:29:03", present: true),
            ],
            now: Timestamp(millisecondsSinceEpoch: 1_700_000_050_000)
        )
        #expect(rows.count == 2, "a presentation pass merged two records")
        let absent = rows.first { $0.presence == .offline }
        let present = rows.first { $0.presence == .online }
        #expect(present?.addressState == .current)
        #expect(absent?.addressState == .reassigned,
                "the absent row did not say its address had been taken")
        // Both rows keep the address. Dropping it would shrink the network silently,
        // and "last seen here" is the information the row exists to carry.
        #expect(absent?.ip == "10.10.20.119")
        #expect(present?.ip == "10.10.20.119")
    }

    @Test("An absent device nobody replaced is last-known, not reassigned")
    func absentAloneIsLastKnown() {
        // The distinction matters: `reassigned` asserts the address moved, which the
        // app watched happen. With nothing else at that address there is nothing to
        // assert, and claiming it would be inventing an observation.
        let rows = Presentation.rows(
            [stored(ip: "10.10.20.50", mac: "A2:6A:35:C9:0A:BD", present: false)],
            now: Timestamp(millisecondsSinceEpoch: 1_700_000_050_000)
        )
        #expect(rows.first?.addressState == .lastKnown)
    }

    @Test("The row says it aloud, for somebody who cannot see the colour")
    func accessibilityCarriesIt() {
        // The whole fix is a contrast change and a chip. Neither reaches VoiceOver, so
        // the sentence has to.
        let rows = Presentation.rows(
            [
                stored(ip: "10.10.20.119", mac: "A2:6A:35:C9:0A:BD", present: false),
                stored(ip: "10.10.20.119", mac: "92:B8:DD:93:29:03", present: true),
            ],
            now: Timestamp(millisecondsSinceEpoch: 1_700_000_050_000)
        )
        let absent = try? #require(rows.first { $0.presence == .offline })
        #expect(absent?.accessibilityDescription.contains("another device now holds") == true)
    }
}
