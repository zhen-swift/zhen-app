// Fixtures.swift — the real network, so the design is checked against real problems.
//
// Every value below except the event log came off 10.10.20.0/24 with the shipped
// scanner. That matters more than it sounds: lorem ipsum hides exactly the problems
// this design has to solve — long Spanish names that push a column, a curly apostrophe
// that is not the ASCII one, and rows where almost every field is empty.
//
// ── The shape of this network, which is the acceptance case ──────────────────────
//
// Ten devices. THREE have a name. Seven do not, and for six of those we have an
// address, a hardware address and nothing else at all: no name, no vendor, no model.
// Four of the seven answered a ping; two were never heard from directly and exist only
// because the kernel's neighbour table remembers talking to them; one has dropped out
// of the table since the last run and is offline.
//
// If the device list looks broken when two thirds of it is anonymous, the design is
// wrong — not the network. That row is the acceptance case for the entire product, so
// it is the majority of this fixture rather than a footnote in it.
//
// ── Where this differs from the brief ────────────────────────────────────────────
//
// The brief describes "six devices with a randomised MAC … two answered ICMP and four
// were found only in the neighbour table". The scan actually produced the inverse
// split — four answered, two were neighbour-only — and only four of the six anonymous
// devices have a locally administered MAC; `10.10.20.1` and `.26` are universal
// addresses that simply advertise no name. The measured values are used, because a
// fixture that has been tidied up is a fixture that stops catching things.
//
// Vendor is empty on every row for the same reason: OUI lookup is not built yet, so
// the scanner returns none, so the fixtures show none. When it lands, these rows gain
// a vendor and the design gets easier — not harder.

import Foundation

// MARK: - Devices

public extension DeviceRowModel {
    /// An Apple TV, named over Bonjour on four service types with `AppleTV5,3` from the
    /// TXT `am` key. The strongest identification on this network.
    static let salaDeEntretenimiento = DeviceRowModel(
        id: "10.10.20.2",
        name: "Sala de entretenimiento",
        subtitle: "Apple TV · AppleTV5,3 · named by Bonjour",
        presence: .online,
        identification: .identified,
        ip: "10.10.20.2",
        mac: "C8:69:CD:7F:33:E1",
        isPrivateMAC: false,
        lastSeen: "now"
    )

    /// The machine running the scan. Note the apostrophe: U+2019, not U+0027 — it comes
    /// off the wire that way and must survive to the screen unmangled.
    ///
    /// A rotating private MAC AND a clean Bonjour name, which is exactly the case that
    /// proves the confidence meter is bound to identification rather than to key
    /// stability: the join key here is weak and the identification is complete.
    static let jcMacBookPro = DeviceRowModel(
        id: "10.10.20.8",
        name: "JC\u{2019}s MacBook Pro",
        subtitle: "Named by Bonjour · randomized MAC · no vendor",
        presence: .online,
        identification: .identified,
        ip: "10.10.20.8",
        mac: "52:A1:8A:E0:7A:8A",
        isPrivateMAC: true,
        lastSeen: "now"
    )

    /// A laptop that joined the network between two scan runs.
    static let macBookAirGeovanna = DeviceRowModel(
        id: "10.10.20.28",
        name: "MacBook Air de Geovanna",
        subtitle: "Named by Bonjour · randomized MAC · no vendor",
        presence: .online,
        identification: .identified,
        ip: "10.10.20.28",
        mac: "A2:6A:35:C9:0A:BD",
        isPrivateMAC: true,
        lastSeen: "now"
    )

    /// The gateway. It advertises no name at all, so the only thing we know about it
    /// beyond its address is that it answers and its TTL suggests a Unix-like stack.
    ///
    /// This is why the meter is bound to identification: the gateway's hardware address
    /// is the most stable identity on the network and it still reads Partial, because a
    /// person looking at this list is asking what the thing IS.
    static let gateway = DeviceRowModel(
        id: "10.10.20.1",
        name: "Unidentified device",
        subtitle: "No name advertised · no vendor · responds to ping",
        presence: .online,
        identification: .partial,
        ip: "10.10.20.1",
        mac: "78:20:51:74:CB:28",
        isPrivateMAC: false,
        isGateway: true,
        lastSeen: "now"
    )

    /// Anonymous, but it answers — so we have a round trip and a TTL and nothing else.
    static let anonymousPinging = DeviceRowModel(
        id: "10.10.20.3",
        name: "Unidentified device",
        subtitle: "Randomized MAC · no vendor · responds to ping",
        presence: .online,
        identification: .partial,
        ip: "10.10.20.3",
        mac: "86:9F:FD:F7:9C:B3",
        isPrivateMAC: true,
        lastSeen: "now"
    )

    /// Anonymous and silent. It exists only because the kernel has talked to it — no
    /// ping reply, so no round trip and no TTL, so not even an OS hint.
    ///
    /// **The emptiest row the product can produce, and the one to design against.**
    static let anonymousNeighbourOnly = DeviceRowModel(
        id: "10.10.20.12",
        name: "Unidentified device",
        subtitle: "Randomized MAC · no vendor · in ARP table, no ping reply",
        presence: .online,
        identification: .minimal,
        ip: "10.10.20.12",
        mac: "32:37:C0:BC:FC:29",
        isPrivateMAC: true,
        lastSeen: "now"
    )

    /// Anonymous, answers slowly — 351 ms, which is Wi-Fi power saving rather than a
    /// problem.
    static let anonymousSlow = DeviceRowModel(
        id: "10.10.20.15",
        name: "Unidentified device",
        subtitle: "Randomized MAC · no vendor · responds to ping",
        presence: .online,
        identification: .partial,
        ip: "10.10.20.15",
        mac: "BE:C4:1B:56:9B:16",
        isPrivateMAC: true,
        lastSeen: "now"
    )

    /// Anonymous, neighbour-table only, second of two.
    static let anonymousQuiet = DeviceRowModel(
        id: "10.10.20.24",
        name: "Unidentified device",
        subtitle: "Randomized MAC · no vendor · in ARP table, no ping reply",
        presence: .online,
        identification: .minimal,
        ip: "10.10.20.24",
        mac: "36:98:A5:EB:A9:61",
        isPrivateMAC: true,
        lastSeen: "now"
    )

    /// Anonymous with a universal hardware address — not every unnamed device is hiding.
    static let anonymousUniversal = DeviceRowModel(
        id: "10.10.20.26",
        name: "Unidentified device",
        subtitle: "No name advertised · no vendor · responds to ping",
        presence: .online,
        identification: .partial,
        ip: "10.10.20.26",
        mac: "00:92:35:30:37:80",
        isPrivateMAC: false,
        lastSeen: "now"
    )

    /// Present in the previous run and gone from the latest one — it has aged out of the
    /// neighbour table.
    ///
    /// **Offline keeps its name at full contrast.** The artboards dim the whole row,
    /// which makes an offline device read as DISABLED rather than as "seen two hours
    /// ago". Only the secondary content dims. See <doc:Corrections>.
    static let offlineSample = DeviceRowModel(
        id: "10.10.20.25",
        name: "Unidentified device",
        subtitle: "No name advertised · no vendor",
        presence: .offline,
        identification: .minimal,
        ip: "10.10.20.25",
        mac: "20:1C:3A:91:9E:54",
        isPrivateMAC: false,
        lastSeen: "2 h ago"
    )

    /// Absent, at an address something else answers at now.
    ///
    /// The row that broke the layout. The `reassigned` chip was first placed inside the
    /// IP column, which is 104pt at its minimum — a dotted quad and nothing else — so
    /// the address wrapped mid-octet and the one row the change existed to make legible
    /// became the only one whose address did not read as an address.
    ///
    /// It carries the LONGEST real subtitle as well as the chip, deliberately. The
    /// previous fixtures had one or the other, so nothing in the suite ever measured a
    /// row with both and `WindowLayoutTests` passed while the running app clipped.
    static let reassignedSample = DeviceRowModel(
        id: "10.10.20.119-old",
        name: "Unidentified device",
        subtitle: "No name advertised · randomized MAC · no vendor · in ARP table, no ping reply",
        presence: .offline,
        identification: .minimal,
        ip: "10.10.20.119",
        addressState: .reassigned,
        mac: "A2:6A:35:C9:0A:BD",
        isPrivateMAC: true,
        lastSeen: "14 h ago"
    )

    /// The whole network, in address order — the way the device list shows it.
    static let sampleNetwork: [DeviceRowModel] = [
        .reassignedSample,
        .gateway,
        .salaDeEntretenimiento,
        .anonymousPinging,
        .jcMacBookPro,
        .anonymousNeighbourOnly,
        .anonymousSlow,
        .anonymousQuiet,
        .anonymousUniversal,
        .offlineSample,
        .macBookAirGeovanna,
    ]

    /// The header line above the table.
    static let sampleSummary = "10 devices · 9 online · 7 unidentified"
}

// MARK: - Device detail

public extension DeviceDetailModel {
    /// The scanning machine, with everything the detail screen can show.
    ///
    /// Deliberately NOT a full house: it has never been deep-scanned and it has no merge
    /// history, so two of the four cards render their empty state. Those are the states
    /// that actually ship on a first run.
    static let jcMacBookPro = DeviceDetailModel(
        id: "10.10.20.8",
        name: "JC\u{2019}s MacBook Pro",
        symbol: Symbols.laptop,
        presence: .online,
        summary: "Named by Bonjour · Identified — 1 of 5 sources agree",
        headerFacts: [
            KeyValuePair("IP address", "10.10.20.8", isAddress: true),
            KeyValuePair("Current MAC", "52:A1:8A:E0:7A:8A", isAddress: true),
            KeyValuePair("First seen", "Sep 3, 2026"),
        ],
        isPrivateMAC: true,
        identityHistory: [
            IdentityRecordModel(
                mac: "52:A1:8A:E0:7A:8A",
                reason: "first sighting of this device",
                range: "Sep 03 → now",
                isCurrent: true
            ),
        ],
        // The one place in the app where key stability is named. A person who opened
        // this card is asking exactly this question; nobody scanning the list is.
        identityCaption: "identity key: rotating MAC, stabilised by Bonjour name · no identity changes seen",
        names: [
            NameCandidateModel(source: "You", candidate: nil, isWinner: false, absenceNote: "— not set"),
            NameCandidateModel(source: "Bonjour", candidate: "JC\u{2019}s MacBook Pro", isWinner: true),
            NameCandidateModel(source: "UPnP", candidate: nil, isWinner: false),
            NameCandidateModel(source: "NetBIOS", candidate: nil, isWinner: false),
            NameCandidateModel(source: "Reverse DNS", candidate: nil, isWinner: false),
        ],
        ports: [],
        portsCaption: nil,
        events: [.geovannaAppeared, .salaNamed]
    )

    /// The acceptance case at detail level: an address, a hardware address, and nothing.
    ///
    /// Every card here is empty or nearly so, and the screen still has to read as an
    /// answer rather than as a failure.
    static let unidentified = DeviceDetailModel(
        id: "10.10.20.12",
        name: "Unidentified device",
        symbol: Symbols.unknown,
        presence: .online,
        summary: "Randomized MAC · no vendor · in ARP table, no ping reply · Minimal — nothing named it",
        headerFacts: [
            KeyValuePair("IP address", "10.10.20.12", isAddress: true),
            KeyValuePair("Current MAC", "32:37:C0:BC:FC:29", isAddress: true),
            KeyValuePair("First seen", "Sep 3, 2026"),
        ],
        isPrivateMAC: true,
        identityHistory: [
            IdentityRecordModel(
                mac: "32:37:C0:BC:FC:29",
                reason: "first sighting of this device",
                range: "Sep 03 → now",
                isCurrent: true
            ),
        ],
        identityCaption: "identity key: rotating MAC, nothing stabilises it · this record may fragment",
        names: [
            NameCandidateModel(source: "You", candidate: nil, isWinner: false, absenceNote: "— not set"),
            NameCandidateModel(source: "Bonjour", candidate: nil, isWinner: false),
            NameCandidateModel(source: "UPnP", candidate: nil, isWinner: false),
            NameCandidateModel(source: "NetBIOS", candidate: nil, isWinner: false),
            NameCandidateModel(source: "Reverse DNS", candidate: nil, isWinner: false),
        ],
        ports: [],
        portsCaption: nil,
        events: []
    )

    /// The Apple TV, which has been deep-scanned, so the ports card has content.
    static let salaDeEntretenimiento = DeviceDetailModel(
        id: "10.10.20.2",
        name: "Sala de entretenimiento",
        symbol: Symbols.tv,
        presence: .online,
        summary: "Apple TV · AppleTV5,3 · Identified — 1 of 5 sources agree",
        headerFacts: [
            KeyValuePair("IP address", "10.10.20.2", isAddress: true),
            KeyValuePair("Current MAC", "C8:69:CD:7F:33:E1", isAddress: true),
            KeyValuePair("First seen", "Sep 1, 2026"),
        ],
        isPrivateMAC: false,
        identityHistory: [
            IdentityRecordModel(
                mac: "C8:69:CD:7F:33:E1",
                reason: "first sighting of this device",
                range: "Sep 01 → now",
                isCurrent: true
            ),
        ],
        identityCaption: "identity key: universal MAC · stable · no identity changes seen",
        // Four service types, one device, two spellings before cleaning — this is the
        // cascade doing its job, and every loser is kept because the losers are the
        // explanation.
        names: [
            NameCandidateModel(source: "You", candidate: nil, isWinner: false, absenceNote: "— not set"),
            NameCandidateModel(source: "Bonjour · companion-link", candidate: "Sala de entretenimiento", isWinner: true),
            NameCandidateModel(source: "Bonjour · airplay", candidate: "Sala de entretenimiento", isWinner: false),
            NameCandidateModel(source: "Bonjour · raop", candidate: "Sala de entretenimiento", isWinner: false),
            NameCandidateModel(source: "Bonjour · sleep-proxy", candidate: "Sala de entretenimiento", isWinner: false),
            NameCandidateModel(source: "UPnP", candidate: nil, isWinner: false),
            NameCandidateModel(source: "NetBIOS", candidate: nil, isWinner: false),
        ],
        ports: [
            PortModel(port: "7000/tcp", service: "airplay", detail: "AirPlay receiver"),
            PortModel(port: "5000/tcp", service: "airplay-alt", detail: nil),
            PortModel(port: "3689/tcp", service: "daap", detail: "iTunes sharing"),
        ],
        portsCaption: "last deep scan 22 min ago",
        events: [.salaNamed]
    )
}

// MARK: - Events
//
// The one part of this file that is not measured. There is no store yet, so there is no
// derived event log to read — these describe what actually changed between consecutive
// runs of the shipped scanner on this network (a laptop joined, a host aged out of the
// neighbour table, Bonjour resolved a name), written in the grammar the event deriver
// will produce. They are labelled here so nobody mistakes them for captured data.

public extension EventModel {
    /// A laptop that really did join between two runs.
    static let geovannaAppeared = EventModel(
        id: "e1", time: "19:24", kind: .appeared,
        subject: "MacBook Air de Geovanna",
        detail: "joined at 10.10.20.28 · named by Bonjour on arrival"
    )
    /// A host that really did age out of the neighbour table.
    static let quietDisappeared = EventModel(
        id: "e2", time: "19:02", kind: .disappeared,
        subject: "Unidentified device",
        detail: "(20:1C:3A…) last answered at 17:02 · aged out of the neighbour table"
    )
    /// Bonjour resolving a name the first run did not have.
    static let salaNamed = EventModel(
        id: "e3", time: "18:47", kind: .renamed,
        subject: "Sala de entretenimiento",
        detail: "· Bonjour name replaced the address it was listed under"
    )
    /// A port opening on the Apple TV.
    static let salaPortOpened = EventModel(
        id: "e4", time: "18:31", kind: .portOpened,
        subject: "Sala de entretenimiento",
        detail: "began listening on 7000/tcp (airplay — AirPlay receiver)"
    )
    /// An anonymous host arriving.
    static let anonymousAppeared = EventModel(
        id: "e5", time: "17:55", kind: .appeared,
        subject: "Unidentified device",
        detail: "joined at 10.10.20.15 · randomized MAC, no name yet"
    )
    /// A device changing address at DHCP renewal.
    static let macBookMoved = EventModel(
        id: "e6", time: "16:40", kind: .ipChanged,
        subject: "JC\u{2019}s MacBook Pro",
        detail: "moved 10.10.20.9 → 10.10.20.8 (DHCP renewal)"
    )
    /// Two records becoming one device across a MAC rotation.
    static let identityMerged = EventModel(
        id: "e7", time: "14:12", kind: .merged,
        subject: "JC\u{2019}s MacBook Pro",
        detail: "· two identities merged, same Bonjour host across a MAC rotation"
    )
    /// A port closing.
    static let portClosed = EventModel(
        id: "e8", time: "11:08", kind: .portClosed,
        subject: "Unidentified device",
        detail: "stopped listening on 5353/udp"
    )
}

public extension EventDayModel {
    /// Today's events.
    static let today = EventDayModel(
        title: "Today — Thursday, Sep 3",
        events: [.geovannaAppeared, .quietDisappeared, .salaNamed, .salaPortOpened, .anonymousAppeared]
    )
    /// Yesterday's.
    static let yesterday = EventDayModel(
        title: "Yesterday — Wednesday, Sep 2",
        events: [.macBookMoved, .identityMerged, .portClosed]
    )
    /// The whole visible window.
    static let sampleDays: [EventDayModel] = [.today, .yesterday]
}

public extension HistogramBucket {
    /// A 48-hour window with the rhythm of a home network: quiet overnight, busy when
    /// people come home.
    static let sampleWindow: [HistogramBucket] = {
        let counts = [0, 0, 1, 0, 0, 0, 0, 1, 2, 1, 0, 0,
                      0, 0, 0, 0, 1, 0, 0, 2, 3, 5, 2, 1,
                      0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2,
                      1, 0, 0, 1, 3, 4, 2, 1, 0, 0, 1, 0]
        let labels: [Int: String] = [2: "Wed 14:00", 14: "Wed 20:00", 26: "Thu 02:00",
                                     38: "Thu 08:00", 46: "Thu 14:00"]
        return counts.enumerated().map { HistogramBucket(hour: $0.offset, count: $0.element, label: labels[$0.offset]) }
    }()
}

// MARK: - Scan

public extension StageModel {
    /// Discovery, finished — the numbers are the shipped scanner's.
    static let discoveryDone = StageModel(
        stage: .discovery, state: .done, detail: "ARP + ping sweep · done in 0.4 s"
    )
    /// Naming, running. No fraction, because a Bonjour browse yields over time and
    /// never says how much is left.
    static let namingRunning = StageModel(
        stage: .naming, state: .running(nil), detail: "Bonjour + UPnP · NetBIOS queued"
    )
    /// The deep scan, not started.
    static let deepScanQueued = StageModel(
        stage: .deepScan, state: .queued, detail: "Ports on new devices · queued"
    )
    /// The strip as it looks mid-scan.
    static let sampleStages: [StageModel] = [.discoveryDone, .namingRunning, .deepScanQueued]
}

public extension DegradationModel {
    /// The one this whole product is shaped around, with the hedge that the artboards
    /// omit. We cannot query the Local Network grant; we infer it.
    static let mdnsDenied = DegradationModel(
        cause: "Bonjour unavailable",
        consequence: "the Local Network permission appears to be denied, so Bonjour names can\u{2019}t be read this scan.",
        actionTitle: "Open System Settings…"
    )
    /// The privileged engine being absent, which is the normal state.
    static let noPrivilegedEngine = DegradationModel(
        cause: "OS fingerprinting skipped",
        consequence: "it needs the privileged engine, which isn\u{2019}t installed. Devices will still be found and named.",
        actionTitle: "Review in Settings…"
    )
    /// Both.
    static let sampleDegradations: [DegradationModel] = [.mdnsDenied, .noPrivilegedEngine]
}

public extension ScanFindingModel {
    /// A host mid-resolution — the italic placeholder state.
    static let resolving = ScanFindingModel(
        id: "10.10.20.15", name: nil,
        detail: "found 4 s ago · NetBIOS query in flight",
        ip: "10.10.20.15", mac: "BE:C4:1B:56:9B:16",
        note: "randomized MAC — vendor lookup not possible"
    )
    /// One already named.
    static let named = ScanFindingModel(
        id: "10.10.20.2", name: "Sala de entretenimiento",
        detail: "named by Bonjour · 2 s ago",
        ip: "10.10.20.2", mac: "C8:69:CD:7F:33:E1",
        note: "matched to known device"
    )
    /// One found and not named.
    static let anonymous = ScanFindingModel(
        id: "10.10.20.1", name: "Unidentified device",
        detail: "no name advertised · 3 s ago",
        ip: "10.10.20.1", mac: "78:20:51:74:CB:28",
        note: "gateway"
    )
    /// The list as it looks mid-scan, newest first.
    static let sampleFindings: [ScanFindingModel] = [.resolving, .named, .anonymous]
}
