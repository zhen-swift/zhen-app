import Foundation
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// Phase 3, stage 2: what the detail, the live scan and the degradations now say.
@MainActor
struct DetailDepthTests {
  let capture: ScanReport

  init() throws {
    capture = try FixtureNetwork.capture()
  }

  func item(_ device: Device, userName: String? = nil) -> DeviceItem {
    DeviceItem(id: "test", device: device, isOnline: true, userName: userName, isReassigned: false)
  }

  /// Gate. Break: `.prefix(1)` on `offered` in `nameOffers` — one name per source, as before.
  @Test("Known by lists every name a source offered, once each, with the winner marked")
  func everyCandidate() throws {
    var device = try #require(capture.devices.first { $0.names.contains { $0.source == .mdns } })
    device.names = [
      NameCandidate(value: "Living Room", source: .mdns, rank: 1),
      NameCandidate(value: "Living Room", source: .mdns, rank: 3),
      NameCandidate(value: "AirPlay Speaker", source: .mdns, rank: 5),
    ]
    let offers = item(device).nameOffers
    let bonjour = offers.filter { $0.source == .mdns }
    #expect(bonjour.map(\.value) == ["Living Room", "AirPlay Speaker"], "a losing name was hidden, or a repeat shown twice")
    #expect(bonjour.map(\.isFirstOfSource) == [true, false])
    #expect(bonjour.map(\.isWinner) == [true, false])
    // Every other source is still listed, and says it offered nothing.
    for source in NameSource.allCases where source != .mdns {
      #expect(offers.filter { $0.source == source }.map(\.value) == [nil])
    }
  }

  @Test("A name of your own wins: no discovered source is marked")
  func userNameWins() throws {
    let device = try #require(capture.devices.first { !$0.names.isEmpty })
    let offers = item(device, userName: "Mine").nameOffers
    #expect(offers.allSatisfy { !$0.isWinner })
  }

  @Test("The identity caption is a sentence, never a raw stability value")
  func identityCaption() throws {
    var device = try #require(capture.devices.first { $0.mac?.isLocallyAdministered == true })
    device.names = [NameCandidate(value: "Phone", source: .mdns, rank: 1)]
    device.identityStability = .moderate
    let caption = item(device).identityCaption
    #expect(caption.hasPrefix("identity key: "))
    #expect(caption.contains("stabilised by Bonjour name"), "\(caption)")
    for raw in Stability.allCases.map(\.rawValue) {
      #expect(!caption.contains(raw), "\(caption) shows \(raw)")
    }
  }

  @Test("Identity changes are merges, renames and moves; presence is not identity")
  func identityKinds() {
    #expect(DerivedEvent.Kind.merged.isIdentityChange)
    #expect(DerivedEvent.Kind.renamed.isIdentityChange)
    #expect(DerivedEvent.Kind.ipChanged.isIdentityChange)
    #expect(!DerivedEvent.Kind.appeared.isIdentityChange)
    #expect(!DerivedEvent.Kind.disappeared.isIdentityChange)
  }

  /// Gate. Break: drop the `privileged helper` branch in `DegradationCopy.init`.
  @Test("A helper that did not help offers a way to Zhen's Settings, not System Settings")
  func helperDegradation() {
    let absent = Degradation(
      stage: .setup,
      reason: "No packet-capture device could be opened, so the layer-2 ARP sweep did not run and hosts that answer only ARP will be missing. Install the privileged helper from Settings, or re-run under sudo, to include it.",
      recoverable: true
    )
    #expect(DegradationCopy(absent).action == .reviewHelperSettings)
    let refused = Degradation(stage: .setup, reason: "The privileged helper declined to open a capture device (busy).", recoverable: true)
    #expect(DegradationCopy(refused).action == .reviewHelperSettings)
  }

  /// Gate. Break: match by address alone in `knownDevice(for:)`.
  @Test("A host is matched to a known device by its MAC, never by a shared address alone")
  func knownDeviceMatch() async throws {
    let model = await ScanningBehaviourTests.loadedModel()
    let known = try #require(model.devices.first { $0.device.mac != nil && !$0.device.ipv4Addresses.isEmpty })
    let address = try #require(known.device.ipv4Addresses.first)
    let same = HostFacts(ip: address, mac: known.device.mac)
    #expect(model.knownDevice(for: same)?.id == known.id)
    // Same address, a different hardware address: a lease that changed hands.
    let stranger = HostFacts(ip: address, mac: MACAddress(raw: 0x0200_5E00_99AA))
    #expect(model.knownDevice(for: stranger) == nil, "claimed a stranger is a known device")
  }

  @Test("A finished stage keeps core's measured duration")
  func stageDurations() {
    let session = ScanSession()
    session.start(ScanRequest())
    session.apply([.stageStarted(.discovery), .stageFinished(StageTiming(stage: .discovery, elapsedMillis: 1_250))])
    #expect(session.stageDurations[.discovery] == .milliseconds(1_250))
  }
}
