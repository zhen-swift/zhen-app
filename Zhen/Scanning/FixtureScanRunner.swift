import Foundation
import ZhenCore
import ZhenScan

/// A scanner that replays the fixture network instead of probing one.
///
/// Used under `-UITesting` and `-ShowcaseData`, so a test can watch a whole scan — hosts
/// streaming in, names resolving, a degradation arriving, the hand-back — without a network
/// and without ever touching the history file.
nonisolated struct FixtureScanRunner: ScanRunning {
  let store: any HistoryStore
  let capture: ScanReport
  let variant: FixtureNetwork.Variant
  /// Which capture `capture` is, so its history has the right cast.
  var dataset: FixtureNetwork.Dataset = .home
  /// Time between events, so a person or a UI test can see the stream.
  let pace: Duration
  let clock: any Clock<Duration>
  /// Whether a scan finds `guest` too: a device the fixture history has never seen.
  var addsNewDevice = false

  /// The latest fixture run: what a scan finds. An empty network's scan finds the home one.
  private var latest: ScanReport? {
    FixtureNetwork.history(variant == .empty ? .home : variant, capture: capture, dataset: dataset, now: .now).last
  }

  func run(_ request: ScanRequest, progress: ProgressSink) async -> ScanOutcome {
    let started = Timestamp.now
    let latest = self.latest
    let network = request.network ?? capture.run.target
    // Only what the request covers. An IPv6-only device has no IPv4 address to be inside a
    // target, and a full scan finds it anyway, the way discovery's neighbour reads do.
    let replayed = (latest?.devices ?? []) + (addsNewDevice ? [Self.guest(from: capture)].compactMap(\.self) : [])
    let devices = replayed.filter { device in
      request.network == nil || device.ipv4Addresses.contains(where: network.contains)
    }
    var stages: [StageTiming] = []
    var announced = 0

    progress(.stageStarted(.discovery))
    for (index, device) in devices.enumerated() {
      guard await pause() else { break }
      // `HostFacts` is an IPv4 host: the engine never streams an IPv6-only one, it reaches
      // the report from the neighbour table. Streamed here, it showed as "0.0.0.0".
      if !device.ipv4Addresses.isEmpty { progress(.hostFound(Self.facts(device, named: false))) }
      announced += 1
      progress(.stageProgress(.discovery, completed: index + 1, total: devices.count))
    }
    stages.append(StageTiming(stage: .discovery, elapsedMillis: Self.elapsed(since: started)))
    var stageStart = Timestamp.now
    progress(.stageFinished(stages[stages.count - 1]))

    let degradations = FixtureNetwork.degradations(variant, capture: capture)
    if !Task.isCancelled, !devices.isEmpty {
      progress(.stageStarted(.naming))
      for degradation in degradations where degradation.stage != .discovery { progress(.degraded(degradation)) }
      for device in devices where !device.names.isEmpty && !device.ipv4Addresses.isEmpty {
        guard await pause() else { break }
        progress(.hostUpdated(Self.facts(device, named: true)))
      }
      stages.append(StageTiming(stage: .naming, elapsedMillis: Self.elapsed(since: stageStart)))
      stageStart = .now
      progress(.stageFinished(stages[stages.count - 1]))
    }
    for degradation in degradations where degradation.stage == .discovery { progress(.degraded(degradation)) }

    // Which devices the port stage probes, decided the way core decides it: "new" is a
    // device history has no first-seen for.
    let known = await store.firstSeen(for: devices.map { Self.facts($0, named: true) }, in: network)
    let probed = Set(request.ports.targets(among: devices.compactMap(\.ipv4Addresses.first), known: known))
    if !probed.isEmpty, !Task.isCancelled {
      progress(.stageStarted(.deepScan))
      _ = await pause()
      stages.append(StageTiming(stage: .deepScan, elapsedMillis: Self.elapsed(since: stageStart)))
      progress(.stageFinished(stages[stages.count - 1]))
    }

    let finished = Timestamp.now
    var run = capture.run
    run.id = UUID()
    run.target = network
    run.startedAt = started
    run.finishedAt = finished
    run.outcome = Task.isCancelled ? .cancelled : (variant == .partial ? .deadlineExpired : .complete)
    run.timing = Timing(stages: stages, counters: ProbeCounterSnapshot(probesSent: 0, repliesSeen: 0, peakConcurrency: 0, inFlight: 0))
    // Stopped: what had answered is kept. Nothing is discarded because someone pressed stop.
    let found = Array(devices.prefix(announced))
    let report = ScanReport(
      run: run,
      devices: found.map { device in
        var seen = device
        seen.lastSeen = finished
        if let address = seen.ipv4Addresses.first, probed.contains(address) {
          if seen.ports.isEmpty { seen.ports = Self.closedPorts(at: address) }
        } else {
          // Not probed this run, so it carries no port observations, as from the engine.
          seen.ports = []
        }
        return seen
      },
      degradations: degradations
    )
    return .finished(CompletedScan(report: report, events: await store.record(report)))
  }

  /// A port probe of addresses the fixture knows: what the latest fixture run recorded for
  /// the device at each, or the common ports closed when it recorded none — folded into
  /// the store the way core folds one, as ports and not as a run.
  func probePorts(_ request: PortProbeRequest, progress: ProgressSink) async -> PortProbeOutcome {
    let latest = self.latest
    var ports: [IPAddress: [PortObservation]] = [:]
    for case .v4(let address) in request.addresses {
      guard await pause() else { break }
      guard let device = latest?.devices.first(where: { $0.ipv4Addresses.contains(address) }) else { continue }
      ports[.v4(address)] = (device.ports.isEmpty ? Self.closedPorts(at: address) : device.ports)
        .filter { $0.address == nil || $0.address == .v4(address) }
    }
    let result = PortScanResult(ports: ports, outcome: Task.isCancelled ? .cancelled : .complete)
    let events = await store.recordPorts(result, targeted: request.addresses, at: .now)
    return .finished(CompletedPortScan(result: result, events: events))
  }

  /// A phone that has just joined: documentation-range MAC and an address no fixture run
  /// has used, a Bonjour name, first seen now.
  static func guest(from capture: ScanReport) -> Device? {
    guard var guest = capture.devices.first(where: { $0.mac?.isLocallyAdministered == false }) ?? capture.devices.first else {
      return nil
    }
    guest.addresses = [.v4(IPv4Address(raw: 0xC0A8_322C))]  // 192.168.50.44
    guest.mac = MACAddress(raw: 0x0000_5E00_5344)            // 00:00:5E:00:53:44
    guest.names = [NameCandidate(value: "Guest Phone", source: .mdns, rank: 1)]
    guest.vendor = nil
    guest.ports = []
    guest.firstSeen = .now
    guest.lastSeen = .now
    return guest
  }

  /// What a deep scan of a fixture device with no recorded ports finds: the common ports,
  /// every one closed. A real scan of a quiet device says the same.
  static func closedPorts(at address: IPv4Address) -> [PortObservation] {
    [22, 80, 443, 445, 548].map {
      PortObservation(port: $0, proto: .tcp, state: .closed, address: .v4(address))
    }
  }

  /// Waits one beat. False when the scan was stopped.
  private func pause() async -> Bool {
    do {
      try await clock.sleep(for: pace)
      return true
    } catch {
      return false
    }
  }

  private static func elapsed(since start: Timestamp) -> Double {
    Double(Timestamp.now.millisecondsSinceEpoch - start.millisecondsSinceEpoch)
  }

  /// What discovery knows about a device (address, hardware, round trip), and, once named,
  /// what naming adds.
  static func facts(_ device: Device, named: Bool) -> HostFacts {
    HostFacts(
      ip: device.ipv4Addresses.first ?? IPv4Address(raw: 0),
      mac: device.mac,
      allNames: named ? device.names : [],
      vendor: device.vendor,
      ttl: device.ttl,
      rtt: device.rtt,
      discoveredVia: Set(device.discoveredVia)
    )
  }
}
