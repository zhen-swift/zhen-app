import Foundation
import ZhenCore

/// The fixture network: one anonymised capture of a real home LAN, and the history a store
/// is fed so the app has something true-shaped to show without a network.
///
/// `home-network.json` is the output of `Scripts/anonymise-scan.py` over a real
/// `zhen scan --json --deep` of the home network. Every run here is that capture, moved in
/// time and changed in one way per run, and then folded through zhen-core's own ledger — so
/// every event the app shows was derived by the same rules a real scan's would be, not
/// written by hand.
nonisolated enum FixtureNetwork {
  /// Which network a launch sees.
  enum Variant: String, Sendable, CaseIterable {
    /// The capture, with 48 hours of history behind it.
    case home
    /// The same network with every name, vendor and model removed and every MAC
    /// randomised: the acceptance case.
    case unidentified
    /// No scan has ever run.
    case empty
    /// The latest run hit its deadline and lost its name sources.
    case partial
    /// A scan completed and nothing answered: the Local Network permission, probably.
    case silent
  }

  enum LoadError: Error, Equatable {
    case missing
    case unreadable(String)
  }

  static let resourceName = "home-network"

  /// A run with nothing in it, for the one case the capture cannot be read: a broken
  /// bundle. The app then shows an empty network rather than stopping.
  static let emptyRun = ScanRun(
    id: Script.runID(255),
    startedAt: Timestamp(millisecondsSinceEpoch: 0),
    target: IPv4Network(base: IPv4Address(raw: 0xC0A8_3200), prefix: 24),
    interface: "en0",
    engine: EngineDescriptor(name: "fixture", kind: .unprivileged, capabilities: []),
    outcome: .complete,
    timing: Timing(stages: [], counters: ProbeCounterSnapshot(probesSent: 0, repliesSeen: 0, peakConcurrency: 0, inFlight: 0))
  )

  /// The committed capture.
  static func capture(in bundle: Bundle = .main) throws(LoadError) -> ScanReport {
    guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
      throw .missing
    }
    do {
      return try JSONDecoder().decode(ScanReport.self, from: Data(contentsOf: url))
    } catch {
      throw .unreadable(String(describing: error))
    }
  }

  /// The degradations the latest run of a variant carries, as the scanner would report them.
  ///
  /// Built with zhen-core's own heuristics, so the sentences are the engine's, not ours —
  /// worded for an app, as the engine words them inside one.
  static func degradations(_ variant: Variant, capture: ScanReport) -> [Degradation] {
    switch variant {
    case .home, .unidentified, .empty:
      return []
    case .partial:
      let silent = NameSourceSilenceHeuristic.evaluate(
        [
          NameSourceActivity(source: .mdns, answered: 0, failed: false),
          NameSourceActivity(source: .ssdp, answered: 0, failed: false),
          NameSourceActivity(source: .netbios, answered: 0, failed: false),
        ],
        hostsProbed: capture.devices.count,
        advice: .appleLocalNetworkInApp
      )
      return capture.degradations + [silent].compactMap { $0 }
    case .silent:
      let denial = LocalNetworkDenialHeuristic.evaluate(
        repliesSeen: 0, probesSent: 254, neighborEntries: 9, advice: .appleLocalNetworkInApp
      )
      return [denial].compactMap { $0 }
    }
  }

  /// The runs to fold into a store, oldest first. The newest finishes a few minutes
  /// before `now`.
  static func history(_ variant: Variant, capture: ScanReport, now: Date) -> [ScanReport] {
    let script = Script(capture: capture, now: now)
    switch variant {
    case .empty:
      return []
    case .silent:
      return [script.report(at: script.schedule.count - 1, devices: [], outcome: .complete,
                            degradations: degradations(.silent, capture: capture))]
    case .home, .partial:
      return script.reports(variant: variant, strip: false)
    case .unidentified:
      return script.reports(variant: variant, strip: true)
    }
  }
}

nonisolated extension FixtureNetwork {
  /// The 48 hours behind the capture: one change per run, so each event in Activity has a
  /// single, explainable cause. The router's ports carry the two port events.
  struct Script {
    let capture: ScanReport
    let now: Date

    /// Hours before `now` at which each run finished. The last is the capture itself.
    let schedule: [Double] = [-47, -41, -35, -29, -23, -17, -11, -5, -2, -0.75, -0.1]

    private var hosts: [Device] { capture.devices }
    private var anonymous: [Int] {
      hosts.indices.filter { hosts[$0].mac?.isLocallyAdministered == true && hosts[$0].names.isEmpty }
    }

    func reports(variant: Variant, strip: Bool) -> [ScanReport] {
      schedule.indices.map { run in
        var devices = hosts.indices.compactMap { index in device(index, inRun: run) }
        if strip { devices = devices.map(Self.unidentified) }
        let latest = run == schedule.count - 1
        return report(
          at: run, devices: devices,
          outcome: latest && variant == .partial ? .deadlineExpired : .complete,
          degradations: latest ? FixtureNetwork.degradations(variant, capture: capture) : []
        )
      }
    }

    /// Device `index` as run `run` saw it, or nil when it did not answer.
    private func device(_ index: Int, inRun run: Int) -> Device? {
      var device = hosts[index]
      let lateArrival = anonymous.count > 3 ? anonymous[3] : nil
      let lastArrival = anonymous.count > 4 ? anonymous[4] : nil
      let mover = anonymous.first
      let speaker = hosts.firstIndex { $0.names.contains { $0.source == .mdns && $0.model == nil } && $0.ports.isEmpty && $0.names.count == 1 && !$0.discoveredVia.isEmpty }
      let television = hosts.firstIndex { $0.names.contains { $0.model != nil } }
      let leaver = hosts.firstIndex { $0.mac?.isLocallyAdministered == false && $0.names.isEmpty && $0.discoveredVia == [.neighborTable] }
      let quiet = hosts.indices.last { hosts[$0].ipv4Addresses.isEmpty && hosts[$0].mac?.isLocallyAdministered == false }
      let router = hosts.firstIndex { $0.ports.contains { $0.port == 80 && $0.state == .open } }

      if index == lateArrival, run < 2 { return nil }
      if index == lastArrival, run < 7 { return nil }
      if index == speaker, run == 3 { return nil }
      if index == leaver, run >= 8 { return nil }
      if index == quiet, run >= 9 { return nil }

      if index == mover, run < 5, let v4 = device.ipv4Addresses.first {
        // It held another lease before; the move at run 5 is an "address changed".
        let earlier = IPv4Address(raw: v4.raw + 30)
        device.addresses.remove(.v4(v4))
        device.addresses.insert(.v4(earlier))
      }
      if index == television, run < 6 {
        // Named by its model until someone gave it a room: a "renamed" at run 6.
        device.names = device.names.map {
          NameCandidate(value: "Apple TV", source: $0.source, rank: $0.rank, model: $0.model)
        }
      }
      if index == router, let v4 = device.ipv4Addresses.first {
        // 80/tcp answered closed in the first run and open from the second: a "port
        // opened". 8080/tcp was open until the latest run, which found it closed: a "port
        // closed". Runs 1 and 10 carry no other change.
        if run < 1 {
          device.ports = device.ports.map { port in
            guard port.port == 80 else { return port }
            var closed = port
            closed.state = .closed
            closed.service = nil
            return closed
          }
        }
        device.ports.append(PortObservation(port: 8080, proto: .tcp, state: run < 10 ? .open : .closed, address: .v4(v4)))
        device.ports.sort(by: PortObservation.canonicalOrder)
      }
      let seen = timestamp(run)
      device.lastSeen = seen
      device.firstSeen = timestamp(firstRun(of: index) ?? run)
      return device
    }

    private func firstRun(of index: Int) -> Int? {
      schedule.indices.first { run in
        let lateArrival = anonymous.count > 3 ? anonymous[3] : nil
        let lastArrival = anonymous.count > 4 ? anonymous[4] : nil
        if index == lateArrival { return run >= 2 }
        if index == lastArrival { return run >= 7 }
        return true
      }
    }

    func timestamp(_ run: Int) -> Timestamp {
      let finished = now.addingTimeInterval(schedule[run] * 3_600)
      return Timestamp(millisecondsSinceEpoch: Int64((finished.timeIntervalSince1970 * 1_000).rounded()))
    }

    func report(at run: Int, devices: [Device], outcome: Outcome, degradations: [Degradation]) -> ScanReport {
      let finished = timestamp(run)
      let duration = (capture.run.finishedAt?.millisecondsSinceEpoch ?? capture.run.startedAt.millisecondsSinceEpoch)
        - capture.run.startedAt.millisecondsSinceEpoch
      var scan = capture.run
      scan.id = Self.runID(run)
      scan.startedAt = Timestamp(millisecondsSinceEpoch: finished.millisecondsSinceEpoch - duration)
      scan.finishedAt = finished
      scan.outcome = outcome
      return ScanReport(run: scan, devices: devices, degradations: degradations)
    }

    /// A stable id per run, so a relaunch of the same fixture is the same history.
    static func runID(_ run: Int) -> UUID {
      let n = UInt8(truncatingIfNeeded: run)
      return UUID(uuid: (0x5A, 0x4E, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, n))
    }

    /// The acceptance case: no name, no vendor, no model, a randomised MAC.
    static func unidentified(_ device: Device) -> Device {
      let evidence = IdentificationEvidence(
        hasDistinctName: false, nameSourceIsSelfSufficient: false, hasModel: false,
        hasVendor: false, hasOSHint: false, independentSources: 0
      )
      let mac = device.mac.map { MACAddress(raw: $0.raw | (0x02 << 40)) }
      return Device(
        addresses: device.addresses, mac: mac, names: [], vendor: nil,
        identification: Identification(evidence: evidence), identificationEvidence: evidence,
        identityStability: .weak, rtt: device.rtt, discoveredVia: device.discoveredVia,
        firstSeen: device.firstSeen, lastSeen: device.lastSeen
      )
    }
  }
}
