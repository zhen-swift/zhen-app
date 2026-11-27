import Foundation
import Synchronization
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// Each network keeps its own history (zhen-core 0.10.0), and all of it can be erased.
///
/// Every model here is live, over `NetworkHistories` in a scratch directory and a stand-in
/// engine: the real history is never opened.
@MainActor
struct NetworkHistoryTests {
  nonisolated static let router = MACAddress("78:20:51:74:CB:28")!
  nonisolated static let otherRouter = MACAddress("C8:69:CD:5E:01:E1")!

  /// A scratch root, the router the engine reads now, and a model over both.
  @MainActor final class Harness {
    let root: URL
    let histories: NetworkHistories
    let defaults: UserDefaults
    let suite: String
    let capture: ScanReport
    /// The router the next engine reads. A class, so the engine's closure can share it.
    let gateway: Router

    init(gateway: MACAddress?) throws {
      root = FileManager.default.temporaryDirectory.appending(path: "zhen-networks-\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
      histories = NetworkHistories(layout: .perNetwork(root: root))
      suite = "zhen.networks.\(UUID().uuidString)"
      defaults = try #require(UserDefaults(suiteName: suite))
      capture = try FixtureNetwork.capture()
      self.gateway = Router(gateway)
    }

    isolated deinit {
      try? FileManager.default.removeItem(at: root)
      defaults.removePersistentDomain(forName: suite)
    }

    func model() -> NetworkModel {
      var environment = AppEnvironment.parse(arguments: [], environment: [:], now: .now)
      environment.dataSource = .live
      let capture = capture
      let gateway = gateway
      let engine: LiveScanRunner.Factory = { store, _ in
        CountingEngine(store: store, report: capture, gateway: gateway.mac.withLock { $0 })
      }
      return NetworkModel(environment: environment, defaults: defaults, engine: engine, histories: histories)
    }

    func scan(_ model: NetworkModel) async {
      model.startScan()
      await model.performScan()
    }
  }

  nonisolated final class Router: Sendable {
    let mac: Mutex<MACAddress?>
    init(_ mac: MACAddress?) { self.mac = Mutex(mac) }
  }

  @Test("A scan records into its own network's history, keyed by the router")
  func scanRecordsIntoItsNetwork() async throws {
    let harness = try Harness(gateway: Self.router)
    let model = harness.model()
    await model.load()
    await harness.scan(model)

    let subnet = harness.capture.run.target
    let expected = harness.histories.directURL(for: NetworkIdentity(subnet: subnet, gateway: Self.router))
    #expect(model.historyURL == expected)
    #expect(model.currentHistoryURL == expected)
    #expect(FileManager.default.fileExists(atPath: expected.path))
    #expect(!model.devices.isEmpty)
    #expect(model.networks.map(\.id) == [expected])
    #expect(!model.hasOtherNetworks, "one network: the picker has nothing to offer")
  }

  /// Gate. Break: skip the chooser in `LiveScanRunner.run` — the scan on the second router
  /// lands in the first router's history.
  @Test("Two routers on one subnet keep two histories, and the other one is read only")
  func twoRoutersTwoHistories() async throws {
    let harness = try Harness(gateway: Self.router)
    let model = harness.model()
    await model.load()
    await harness.scan(model)
    let home = try #require(model.currentHistoryURL)

    // The Mac moves to a second router handing out the same subnet, the app still open.
    harness.gateway.mac.withLock { $0 = Self.otherRouter }
    await harness.scan(model)
    let away = try #require(model.currentHistoryURL)
    #expect(away != home, "the second router's scan was recorded into the first one's history")
    #expect(model.historyURL == away)
    #expect(Set(model.networks.map(\.id)) == [home, away])
    #expect(model.networks.first?.id == away)
    #expect(model.networks.first?.isCurrent == true)
    #expect(model.hasOtherNetworks)

    // A relaunch on the second router opens its history, not the first one's.
    let relaunched = harness.model()
    await relaunched.load()
    #expect(relaunched.currentHistoryURL == away)

    // Looking back at home: its devices, read only.
    let homeChoice = try #require(model.networks.first { $0.id == home })
    await model.show(homeChoice)
    #expect(model.historyURL == home)
    #expect(!model.isViewingCurrentNetwork)
    #expect(!model.devices.isEmpty)
    let id = try #require(model.devices.first?.id)
    model.scanPorts(id)
    #expect(model.portScanTarget == nil, "a port scan ran against another network's device")

    // Scan Now comes back to the network this Mac is on first.
    await harness.scan(model)
    #expect(model.historyURL == away)
    #expect(model.isViewingCurrentNetwork)
  }

  @Test("A launch with no readable router joins its subnet's latest history")
  func unknownRouterJoinsLatest() async throws {
    let harness = try Harness(gateway: Self.router)
    let first = harness.model()
    await first.load()
    await harness.scan(first)
    let home = try #require(first.currentHistoryURL)

    // macOS 27: an unprivileged app reads the ARP cache as empty.
    harness.gateway.mac.withLock { $0 = nil }
    let model = harness.model()
    await model.load()
    #expect(model.currentHistoryURL == home)
    #expect(!model.devices.isEmpty)
  }

  /// Gate. Break: drop `await histories?.eraseAll()` from `eraseAllHistory` — the network
  /// not in view survives.
  @Test("Erase All History erases every network, and the names given to devices")
  func eraseAllHistory() async throws {
    let harness = try Harness(gateway: Self.router)
    let first = harness.model()
    await first.load()
    await harness.scan(first)
    harness.gateway.mac.withLock { $0 = Self.otherRouter }
    let model = harness.model()
    await model.load()
    await harness.scan(model)
    let id = try #require(model.devices.first?.id)
    model.rename(id, to: "Kitchen")
    #expect(model.networks.count == 2)

    await model.eraseAllHistory()

    #expect(model.devices.isEmpty)
    #expect(model.events.isEmpty)
    #expect(model.latestRun == nil)
    #expect(model.userNames.isEmpty)
    #expect(await harness.histories.known().isEmpty, "a network's history survived the erase")
    #expect(!model.hasOtherNetworks)
    // A relaunch finds nothing either.
    let relaunched = harness.model()
    await relaunched.load()
    #expect(relaunched.devices.isEmpty)
    #expect(relaunched.userNames.isEmpty)
  }

  @Test("Erase under fixtures empties the in-memory store")
  func eraseUnderFixtures() async {
    let model = await ScanningBehaviourTests.loadedModel()
    #expect(!model.devices.isEmpty)
    await model.eraseAllHistory()
    #expect(model.devices.isEmpty)
    #expect(model.latestRun == nil)
    #expect(model.isViewingCurrentNetwork)
  }

  @Test("ZHEN_HISTORY is one file for every network, and nothing is read to choose one")
  func overrideIsOneFile() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "zhen-single-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "history.ndjson")
    var environment = AppEnvironment.parse(arguments: [], environment: ["ZHEN_HISTORY": file.path], now: .now)
    environment.dataSource = .live
    let capture = try FixtureNetwork.capture()
    let engine: LiveScanRunner.Factory = { store, _ in
      CountingEngine(store: store, report: capture, gateway: Self.router)
    }
    let model = NetworkModel(environment: environment, engine: engine)
    await model.load()
    model.startScan()
    await model.performScan()
    #expect(model.historyURL?.standardizedFileURL == file.standardizedFileURL)
    #expect(model.networks.isEmpty)
    #expect(FileManager.default.fileExists(atPath: file.path))
    let networks = directory.appending(path: NetworkHistories.networksDirectory)
    #expect(!FileManager.default.fileExists(atPath: networks.path))
  }

  @Test("The picker names a network by its subnet, its router and when it was last scanned")
  func choiceTitles() {
    let subnet = IPv4Network("192.168.1.0/24")!
    let current = NetworkChoice(
      id: URL(filePath: "/a"), identity: NetworkIdentity(subnet: subnet, gateway: Self.router),
      lastScan: .now, router: "Fritz!Box", isCurrent: true
    )
    #expect(RootView.NetworkPickerView.title(of: current).hasSuffix("192.168.1.0/24 · Fritz!Box"))
    #expect(current.accessibilityIdentifier == "network-192.168.1.0-24_78205174CB28")
  }
}
