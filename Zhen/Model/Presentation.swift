// Presentation.swift — the one place core's vocabulary becomes the design system's.
//
// `ZhenDesign` deliberately does not depend on `ZhenCore`: a design system that
// imports the scanner cannot be rendered without one, and every fixture and preview in it
// exists because it has no such dependency. So the two vocabularies meet exactly here,
// and nowhere else.
//
// Everything below is a pure function of a value type. No view calls into core, no view
// model formats a string twice, and the fixtures keep working because they are the same
// flat types this file produces.

import Foundation
import ZhenCore
import ZhenScan

/// Turns core's records into the flat models the design system renders.
enum Presentation {
    // MARK: Device list

    /// The whole list, which is the only level at which a repeated address is visible.
    ///
    /// `row` cannot answer this on its own: whether an absent device's address has been
    /// taken is a fact about the OTHER rows. So the addresses currently answering are
    /// collected once and every absent row is checked against them.
    ///
    /// Nothing is merged, nothing is hidden and nothing is reordered. Two devices that
    /// held one address at different times remain two records — `HistoryLedger`'s
    /// anti-collapse guard is right to refuse to join them on a lease, and this is a
    /// presentation pass that does not get a vote on identity.
    static func rows(_ stored: [StoredDevice], now: Timestamp) -> [DeviceRowModel] {
        let live = Set(stored.filter(\.isPresent).map(\.device.ip))
        return stored.map { row($0, now: now, addressesInUse: live) }
    }

    /// One device, as a table row.
    static func row(
        _ stored: StoredDevice, now: Timestamp, addressesInUse: Set<IPv4Address> = []
    ) -> DeviceRowModel {
        let device = stored.device
        return DeviceRowModel(
            id: identity(device),
            name: device.displayName ?? "Unidentified device",
            subtitle: subtitle(device),
            presence: stored.isPresent ? .online : .offline,
            identification: level(device.identification),
            ip: device.ip.description,
            addressState: addressState(stored, addressesInUse: addressesInUse),
            mac: device.mac?.description,
            isPrivateMAC: device.mac?.isLocallyAdministered ?? false,
            // The GATEWAY chip is not set, and it is not an oversight — see
            // `Presentation.gatewayIsNotKnowable`.
            isGateway: false,
            lastSeen: relative(device.lastSeen, now: now)
        )
    }

    /// What a row's address means at the moment it is drawn.
    ///
    /// A present device is at its address. An absent one is at the address it was last
    /// at, which is worth keeping — "seen fourteen hours ago at this address" is
    /// information — and worth marking when something else answers there now, because
    /// otherwise the list shows one address twice and looks broken while being right.
    static func addressState(
        _ stored: StoredDevice, addressesInUse: Set<IPv4Address>
    ) -> AddressState {
        guard !stored.isPresent else { return .current }
        return addressesInUse.contains(stored.device.ip) ? .reassigned : .lastKnown
    }

    /// The second line, which is the whole product for a device nothing could name.
    ///
    /// Built from what IS known rather than from placeholders. A row of em dashes says
    /// "this is broken"; "Randomized MAC · no vendor · in ARP table, no ping reply" says
    /// "here is everything there is to know", which is a different and true statement.
    static func subtitle(_ device: Device) -> String {
        var parts: [String] = []

        if let source = device.names.best?.source {
            parts.append("Named by \(source.label)")
        } else {
            parts.append("No name advertised")
        }
        if let model = device.displayModel { parts.append(model) }

        if let vendor = device.vendor {
            parts.append(vendor)
        } else if device.mac?.isLocallyAdministered == true {
            // The randomised MAC is the REASON there is no vendor, so the two are said
            // together. Separately they read as two unrelated gaps.
            parts.append("randomized MAC · no vendor")
        } else {
            parts.append("no vendor")
        }

        // How we know it is there at all. A host with a round trip answered us; one
        // without is in the kernel's neighbour table because the machine has talked to
        // it, which is weaker evidence and worth saying out loud.
        parts.append(device.rtt == nil ? "in ARP table, no ping reply" : "responds to ping")
        return parts.joined(separator: " · ")
    }

    /// Core's confidence, as the design system's.
    ///
    /// Two enums rather than one shared type, because the design module has no
    /// dependency on core. They are the same three cases and this is the only place the
    /// mapping exists.
    static func level(_ identification: ZhenCore.Identification) -> ZhenDesign.Identification {
        switch identification {
        case .identified: .identified
        case .partial: .partial
        case .minimal: .minimal
        }
    }

    // MARK: Device detail

    /// One device, in full.
    static func detail(_ stored: StoredDevice, now: Timestamp, events: [DerivedEvent]) -> DeviceDetailModel {
        let device = stored.device
        return DeviceDetailModel(
            id: identity(device),
            name: device.displayName ?? "Unidentified device",
            symbol: symbol(for: device),
            presence: stored.isPresent ? .online : .offline,
            summary: summary(device, stored: stored, now: now),
            headerFacts: [
                KeyValuePair("IP address", device.ip.description, isAddress: true),
                KeyValuePair("Current MAC", device.mac?.description, isAddress: true),
                KeyValuePair("First seen", absolute(device.firstSeen)),
            ],
            isPrivateMAC: device.mac?.isLocallyAdministered ?? false,
            identityHistory: [
                IdentityRecordModel(
                    mac: device.mac?.description ?? device.ip.description,
                    reason: "first sighting",
                    range: "\(absolute(device.firstSeen)) → \(relative(device.lastSeen, now: now))",
                    isCurrent: true
                ),
            ],
            identityCaption: identityCaption(device),
            names: nameCandidates(device),
            ports: device.openPorts.map {
                PortModel(
                    port: "\($0.port)/\($0.proto.rawValue)",
                    service: $0.service?.name ?? "unknown",
                    detail: $0.service?.product
                )
            },
            portsCaption: device.ports.isEmpty ? nil : "from the last deep scan",
            events: events.filter { $0.subject == (device.displayName ?? "Unidentified device") }
                .prefix(5).map(event)
        )
    }

    /// The header's explanatory line.
    static func summary(_ device: Device, stored: StoredDevice, now: Timestamp) -> String {
        var parts = [subtitle(device)]
        let evidence = device.identificationEvidence
        parts.append(
            "\(level(device.identification).label) — \(evidence.independentSources) of "
            + "\(NameSource.allCases.count) sources agree"
        )
        if !stored.isPresent { parts.append("last seen \(relative(device.lastSeen, now: now))") }
        return parts.joined(separator: " · ")
    }

    /// The caption on the identity card.
    ///
    /// **The only place `identityStability` appears in the entire app.** A person who
    /// opened this card is asking exactly that question; nobody scanning the device list
    /// is, which is why the meter next to every row is bound to `identification` instead.
    static func identityCaption(_ device: Device) -> String {
        switch device.identityStability {
        case .strong:
            "identity key: universal MAC · stable across rotations and renames"
        case .moderate:
            "identity key: a name that survives MAC rotation · stable while the name holds"
        case .weak:
            "identity key: rotating MAC and nothing stronger · this record may fragment"
        case .ephemeral:
            "identity key: an address lease and nothing else · identity holds only while the lease does"
        }
    }

    /// Every name source, winners and losers, with the ones that offered nothing shown.
    ///
    /// The absences are the point. A card listing only what answered cannot distinguish
    /// "we asked Bonjour and it was quiet" from "we never asked Bonjour".
    static func nameCandidates(_ device: Device) -> [NameCandidateModel] {
        let winner = device.names.best
        return NameSource.allCases.map { source in
            let offered = device.names.filter { $0.source == source }
            let best = offered.min()
            return NameCandidateModel(
                source: source == .administrative ? "You" : source.label,
                candidate: best?.value,
                isWinner: best != nil && best == winner,
                absenceNote: source == .administrative ? "— not set" : "— not advertised"
            )
        }
    }

    /// A device-kind glyph, inferred from the model string.
    ///
    /// Presentational only, and a guess. Core does not classify devices and should not —
    /// "this is a laptop" is not something a scan observes. The icon is a hint; every
    /// fact beside it is measured.
    static func symbol(for device: Device) -> String {
        let hay = ((device.displayModel ?? "") + " " + (device.displayName ?? "")).lowercased()
        if hay.contains("appletv") || hay.contains("apple tv") { return Symbols.tv }
        if hay.contains("macbook") { return Symbols.laptop }
        if hay.contains("imac") || hay.contains("macmini") || hay.contains("macstudio")
            || hay.contains("mac studio") || hay.contains("mac") { return Symbols.desktop }
        if hay.contains("iphone") || hay.contains("ipad") { return Symbols.phone }
        if hay.contains("printer") || hay.contains("laserjet") { return Symbols.printer }
        return Symbols.unknown
    }

    // MARK: Events, degradations, scan

    /// One derived event, as an activity row.
    static func event(_ event: DerivedEvent) -> EventModel {
        let kind: EventKind = switch event.kind {
        case .appeared: .appeared
        case .disappeared: .disappeared
        case .ipChanged: .ipChanged
        case .renamed: .renamed
        case .merged: .merged
        }
        return EventModel(
            id: event.id.uuidString,
            time: clock(event.at),
            kind: kind,
            subject: event.subject,
            detail: event.detail
        )
    }

    /// Events grouped under day headers.
    static func days(_ events: [DerivedEvent], now: Timestamp) -> [EventDayModel] {
        guard !events.isEmpty else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: Date(timeIntervalSince1970: event.at.timeIntervalSince1970))
        }
        return grouped.keys.sorted(by: >).map { day in
            EventDayModel(
                title: dayTitle(day, calendar: calendar),
                events: (grouped[day] ?? []).sorted { $0.at > $1.at }.map(event)
            )
        }
    }

    /// Core's degradation, as the banner's row.
    ///
    /// The consequence sentence is core's own — it is written for a person there, which
    /// is the whole reason `Degradation.reason` is prose and not an error code. The app
    /// supplies only the action, because only the app can perform one.
    static func degradation(_ degradation: Degradation) -> DegradationModel {
        DegradationModel(
            cause: degradation.stage.label + (degradation.recoverable ? "" : " — unavailable"),
            consequence: degradation.reason,
            actionTitle: degradation.reason.contains("Local Network") ? "Open System Settings…" : nil
        )
    }

    /// Core's stage timings, as the live scan's cards.
    static func stages(running: Stage?, finished: Set<Stage>, detail: [Stage: String]) -> [StageModel] {
        let order: [(Stage, ScanStage)] = [
            (.discovery, .discovery), (.naming, .naming), (.deepScan, .deepScan),
        ]
        return order.map { core, design in
            let state: StageState = finished.contains(core) ? .done
                : (running == core ? .running(nil) : .queued)
            return StageModel(stage: design, state: state, detail: detail[core] ?? defaultDetail(core))
        }
    }

    private static func defaultDetail(_ stage: Stage) -> String {
        switch stage {
        case .setup: "Interfaces and descriptor limits"
        case .discovery: "ARP + ping sweep"
        case .naming: "Bonjour, UPnP and NetBIOS"
        case .deepScan: "Ports on the hosts that answered"
        }
    }

    // MARK: Formatting
    //
    // Every duration and every stamp the UI shows was measured in core, and is displayed
    // at the precision core recorded — no re-rounding that turns a 0.4 ms answer into
    // 0 ms.

    /// A stable per-device identity for SwiftUI's list diffing.
    ///
    /// **Not the IP address.** Addresses move, and an unstable key turns every update
    /// into a full teardown and rebuild instead of a diff of what actually changed.
    /// The strongest identifier the device has is the key, which is the same value the
    /// store joins on.
    static func identity(_ device: Device) -> String {
        if let mac = device.mac { return "mac:\(mac)" }
        if let name = device.displayName { return "name:\(name)" }
        return "ip:\(device.ip)"
    }

    static func relative(_ stamp: Timestamp, now: Timestamp) -> String {
        let seconds = max(0, (now.millisecondsSinceEpoch - stamp.millisecondsSinceEpoch) / 1000)
        switch seconds {
        case 0..<45: return "now"
        case 45..<5400: return "\(max(1, seconds / 60)) min ago"
        case 5400..<172_800: return "\(seconds / 3600) h ago"
        default: return "\(seconds / 86_400) d ago"
        }
    }

    static func absolute(_ stamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date(timeIntervalSince1970: stamp.timeIntervalSince1970))
    }

    static func clock(_ stamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: stamp.timeIntervalSince1970))
    }

    static func dayTitle(_ day: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let name = formatter.string(from: day)
        if calendar.isDateInToday(day) { return "Today — \(name)" }
        if calendar.isDateInYesterday(day) { return "Yesterday — \(name)" }
        return name
    }

    static func elapsed(_ millis: Double) -> String {
        let total = Int(millis / 1000)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Why no device ever carries the GATEWAY chip.
    ///
    /// The artboards show one and the component exists, but the default-route gateway's
    /// ADDRESS is not public API. `DarwinInterfaceProvider` reads the routing table to
    /// find which interface the default route uses and returns only its index;
    /// `RouteMessage.gateway` — the field that holds the answer — is internal to
    /// `ZhenDarwin`, and `NetworkInterface` carries name, address, network and
    /// hardware address but not the router.
    ///
    /// The available guess is "the first host address on the subnet", which is right on
    /// most home networks and wrong on some, and a scanner whose pitch is that it does
    /// not guess should not label a device from a convention. So the chip stays unset
    /// until core exposes the gateway.
    static let gatewayIsNotKnowable = true
}
