// DeviceModels.swift — the flat value types the components render.
//
// Every component in this module takes a value type and renders it. None of them fetch,
// none of them own a task, and none of them know a store exists — which is what makes
// them previewable, and previews are how this work gets checked against the artboards.
//
// These are deliberately NOT `ZhenCore.Device`. This module does not depend on
// core at all, and it should not: a design system that imports the scanner cannot be
// rendered without one. When document 03 wires the app up, it maps core's types onto
// these at the boundary, and that mapping is the only place the two vocabularies meet.
//
// They are also flat by intent. `subtitle` is a String, not a model the row has to
// assemble — deciding what an unidentified device's second line SAYS is a product
// decision, and a row is the wrong place to make it.

import Foundation

/// How well we know what a device is.
///
/// **Bound to `identification`, never to identity-key stability.** They are different
/// questions and conflating them is the mistake this type exists to prevent:
///
/// - `identification` asks *how well do we know what this thing is* — do we have a name,
///   a model, a vendor, and how many independent sources agree.
/// - Identity stability asks *how likely is this record to fragment* — which is a
///   question about the join key, and it appears in exactly one place in the whole app:
///   the device detail's identity card.
///
/// So a MacBook with a rotating private MAC that advertises a clean Bonjour name reads
/// **Identified**, and a router whose hardware MAC never changes but which we could only
/// name from a model string reads **Partial**. That is not a bug in the artboards; it is
/// the only reading that means anything to a person looking at a list of their own
/// devices.
public enum Identification: Int, Sendable, Hashable, CaseIterable, Comparable {
    /// One weak signal. An address and a randomised MAC, and nothing else.
    case minimal = 1
    /// Something, but not enough to say what it is.
    case partial = 2
    /// A name, and usually a model, agreed by at least one trustworthy source.
    case identified = 3

    /// The word shown beside the bars. Never colour alone.
    public var label: String {
        switch self {
        case .minimal: "Minimal"
        case .partial: "Partial"
        case .identified: "Identified"
        }
    }

    /// Orders by strength, so a list can sort on it.
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Whether a device answered in the most recent run.
public enum Presence: Sendable, Hashable {
    /// Replied to the most recent scan.
    case online
    /// Did not reply. Not an error — a sleeping laptop is offline and perfectly healthy.
    case offline
    /// Currently being probed.
    case scanning
}

/// One row in the device table.
/// What a row's address means at the moment it is drawn.
///
/// A device that stopped answering keeps its row and its last known address, because
/// "seen fourteen hours ago" is information and dropping the row would silently shrink
/// the network. But an address it no longer holds must not be drawn with the same
/// weight as one that is live, or the list shows the same address twice and looks wrong
/// when it is right.
public enum AddressState: Sendable, Hashable {
    /// The device answered in the most recent run and this is where it answered.
    case current
    /// The device did not answer. This is where it last did, and nothing else in the
    /// list claims the address.
    case lastKnown
    /// The device did not answer, and a device that DID is at this address now.
    ///
    /// The only thing this asserts is that the address moved, which the app has watched
    /// happen. It says nothing about whether the two records are the same machine —
    /// they may be one phone rotating a private address or two unrelated hosts, and
    /// nothing observed so far can tell them apart.
    case reassigned
}

public struct DeviceRowModel: Identifiable, Sendable, Hashable {
    /// Stable identity for the list. The address is not it — addresses move.
    public let id: String
    /// What to show as the name, already decided.
    ///
    /// For a device nothing named, this is "Unidentified device" — a real answer rather
    /// than an empty cell. The row does not decide that; the caller does.
    public let name: String
    /// The second line: model · vendor when known, otherwise what *is* known.
    ///
    /// This is the line that makes an unidentified device legible instead of blank —
    /// "Randomized MAC · no vendor · responds to ping" — and it is the reason the row is
    /// 52pt tall.
    public let subtitle: String
    /// Whether it answered.
    public let presence: Presence
    /// How well we know what it is.
    public let identification: Identification
    /// The address, rendered monospaced.
    public let ip: String
    /// What that address means right now.
    ///
    /// The row draws the IP at full strength only when it is `.current`. Two devices
    /// holding one address at different times is ordinary on a DHCP network and the
    /// ledger is right to keep both records — but the list showed the same bold
    /// monospace address twice with nothing beside it to say which one holds it, and a
    /// person reading that concludes the scanner is broken.
    public let addressState: AddressState
    /// The hardware address, or nil when the neighbour table had no entry.
    public let mac: String?
    /// Whether that MAC is locally administered, and therefore rotates.
    public let isPrivateMAC: Bool
    /// Whether this is the default gateway. Shown as a chip beside the name.
    public let isGateway: Bool
    /// Relative last-seen — "now", "2 h ago".
    public let lastSeen: String

    /// Creates a row model. Each field is documented on the property it sets.
    public init(
        id: String,
        name: String,
        subtitle: String,
        presence: Presence,
        identification: Identification,
        ip: String,
        addressState: AddressState = .current,
        mac: String?,
        isPrivateMAC: Bool,
        isGateway: Bool = false,
        lastSeen: String
    ) {
        self.id = id
        self.name = name
        self.addressState = addressState
        self.subtitle = subtitle
        self.presence = presence
        self.identification = identification
        self.ip = ip
        self.mac = mac
        self.isPrivateMAC = isPrivateMAC
        self.isGateway = isGateway
        self.lastSeen = lastSeen
    }

    /// Whether the row draws as present.
    public var isOnline: Bool { presence != .offline }

    /// The whole row as one sentence, for VoiceOver.
    ///
    /// One element, not five. A row read as a column dump — "JC's MacBook Pro. Online.
    /// Identified. 10.10.20.8." with a swipe between each — is technically complete and
    /// unusable. This reads like a person talking.
    public var accessibilityDescription: String {
        var parts = [name]
        parts.append(presence == .offline ? "offline" : "online")
        parts.append(identification.label.lowercased())
        switch addressState {
        case .current: parts.append("at \(ip)")
        case .lastKnown: parts.append("last known address \(ip)")
        case .reassigned:
            parts.append("last known address \(ip), which another device now holds")
        }
        if isGateway { parts.append("gateway") }
        if let mac {
            parts.append(isPrivateMAC ? "private hardware address \(mac)" : "hardware address \(mac)")
        } else {
            parts.append("no hardware address")
        }
        parts.append("last seen \(lastSeen)")
        return parts.joined(separator: ", ")
    }
}

/// One label/value pair in a ``KeyValueGrid``.
public struct KeyValuePair: Identifiable, Sendable, Hashable {
    /// Stable identity for the grid.
    public var id: String { label }
    /// The label, uppercased at render time rather than in the string.
    public let label: String
    /// The value, or nil when it was not observed.
    ///
    /// Nil renders as an em dash. An empty cell looks like a bug; a dash looks like an
    /// answer.
    public let value: String?
    /// Whether to render the value monospaced — true for anything compared vertically.
    public let isAddress: Bool

    /// Creates a pair. Each field is documented on the property it sets.
    public init(_ label: String, _ value: String?, isAddress: Bool = false) {
        self.label = label
        self.value = value
        self.isAddress = isAddress
    }
}

/// One row of the identity-history card: a hardware address and why it merged.
public struct IdentityRecordModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public var id: String { mac }
    /// The address.
    public let mac: String
    /// Why this record joined the device — "merged — same mDNS host".
    public let reason: String
    /// The window it was seen in.
    public let range: String
    /// Whether this is the address in use now.
    public let isCurrent: Bool

    /// Creates a record. Each field is documented on the property it sets.
    public init(mac: String, reason: String, range: String, isCurrent: Bool) {
        self.mac = mac
        self.reason = reason
        self.range = range
        self.isCurrent = isCurrent
    }
}

/// One entry in the "Known by" card: a source, its candidate, and whether it won.
public struct NameCandidateModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public var id: String { source }
    /// The source's name as a person would say it — "Bonjour", "UPnP", "You".
    public let source: String
    /// What it offered, or nil when it offered nothing.
    ///
    /// A source that offered nothing is SHOWN, reading "— not advertised". The absence
    /// is information: it is how a person sees that we asked and got no answer, rather
    /// than that we never asked.
    public let candidate: String?
    /// Whether this one won the cascade.
    public let isWinner: Bool
    /// What to show when this source offered nothing.
    ///
    /// Carried per source because the reason differs and the difference is not cosmetic.
    /// A protocol that was asked and stayed quiet is "— not advertised". A user override
    /// is "— not set": nobody asked the network anything, the field is simply empty and
    /// the person reading it is the one who could fill it.
    public let absenceNote: String

    /// Creates a candidate. Each field is documented on the property it sets.
    public init(
        source: String,
        candidate: String?,
        isWinner: Bool,
        absenceNote: String = "— not advertised"
    ) {
        self.source = source
        self.candidate = candidate
        self.isWinner = isWinner
        self.absenceNote = absenceNote
    }
}

/// One row of the open-ports card.
public struct PortModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public var id: String { port }
    /// "22/tcp", monospaced.
    public let port: String
    /// The service name.
    public let service: String
    /// Product and version, or nil when the banner said nothing.
    public let detail: String?

    /// Creates a port row. Each field is documented on the property it sets.
    public init(port: String, service: String, detail: String?) {
        self.port = port
        self.service = service
        self.detail = detail
    }
}

/// Everything the device detail screen renders.
public struct DeviceDetailModel: Identifiable, Sendable, Hashable {
    /// Stable identity, matching the row it came from.
    public let id: String
    /// The name, or "Unidentified device".
    public let name: String
    /// The kind symbol for the header tile.
    public let symbol: String
    /// Whether it answered.
    public let presence: Presence
    /// The header's explanatory line.
    public let summary: String
    /// Address, current MAC, first seen — the trailing header block.
    public let headerFacts: [KeyValuePair]
    /// Whether the current MAC rotates.
    public let isPrivateMAC: Bool
    /// One row per hardware address this device has been seen under.
    public let identityHistory: [IdentityRecordModel]
    /// The caption on the identity card.
    ///
    /// **This is the only place in the app where identity-key stability appears.** A
    /// person who opened this card is asking exactly that question; nobody scanning the
    /// device list is.
    public let identityCaption: String
    /// Every name source and its candidate, winners and losers together.
    public let names: [NameCandidateModel]
    /// Open ports, empty when no deep scan has run.
    public let ports: [PortModel]
    /// When the ports were last checked, or nil if never.
    public let portsCaption: String?
    /// The last few events for this device.
    public let events: [EventModel]

    /// Creates a detail model. Each field is documented on the property it sets.
    public init(
        id: String,
        name: String,
        symbol: String,
        presence: Presence,
        summary: String,
        headerFacts: [KeyValuePair],
        isPrivateMAC: Bool,
        identityHistory: [IdentityRecordModel],
        identityCaption: String,
        names: [NameCandidateModel],
        ports: [PortModel],
        portsCaption: String?,
        events: [EventModel]
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.presence = presence
        self.summary = summary
        self.headerFacts = headerFacts
        self.isPrivateMAC = isPrivateMAC
        self.identityHistory = identityHistory
        self.identityCaption = identityCaption
        self.names = names
        self.ports = ports
        self.portsCaption = portsCaption
        self.events = events
    }
}
