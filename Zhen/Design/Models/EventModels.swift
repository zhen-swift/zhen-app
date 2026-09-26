// EventModels.swift — the activity log, as the views see it.

import Foundation

/// What kind of change an event records.
///
/// The kind decides both the symbol and the colour, and the pair is chosen so no state
/// is colour-only: a person who cannot distinguish the green from the amber still has a
/// different glyph and a different word.
public enum EventKind: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// A device joined the network.
    case appeared
    /// A device stopped answering.
    case disappeared
    /// A device moved address.
    case ipChanged
    /// Two identity records became one device.
    case merged
    /// A device's winning name changed.
    case renamed
    /// A port started answering.
    case portOpened
    /// A port stopped answering.
    case portClosed

    /// Stable identity for a `ForEach`.
    public var id: String { rawValue }

    /// The uppercase label in the kind column.
    public var label: String {
        switch self {
        case .appeared: "Appeared"
        case .disappeared: "Disappeared"
        case .ipChanged: "IP changed"
        case .merged: "Merged"
        case .renamed: "Renamed"
        case .portOpened: "Port opened"
        case .portClosed: "Port closed"
        }
    }

    /// The SF Symbol for this kind.
    public var symbol: String {
        switch self {
        case .appeared: Symbols.appeared
        case .disappeared: Symbols.disappeared
        case .ipChanged: Symbols.ipChanged
        case .merged: Symbols.merged
        case .renamed: Symbols.renamed
        case .portOpened: Symbols.portOpened
        case .portClosed: Symbols.portClosed
        }
    }

    /// Which filter chip this kind falls under.
    public var category: EventCategory {
        switch self {
        case .appeared, .disappeared: .appearances
        case .merged, .renamed: .identity
        case .portOpened, .portClosed: .ports
        case .ipChanged: .network
        }
    }
}

/// The filter chips above the activity list.
public enum EventCategory: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// Everything.
    case all
    /// Devices joining and leaving.
    case appearances
    /// Merges and renames.
    case identity
    /// Ports opening and closing.
    case ports
    /// Address changes.
    case network

    /// Stable identity for a `ForEach`.
    public var id: String { rawValue }

    /// The chip's text.
    public var label: String {
        switch self {
        case .all: "All"
        case .appearances: "Appearances"
        case .identity: "Identity"
        case .ports: "Ports"
        case .network: "Network"
        }
    }

    /// Whether an event belongs under this chip.
    public func matches(_ kind: EventKind) -> Bool {
        self == .all || kind.category == self
    }
}

/// One row in the activity list.
public struct EventModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public let id: String
    /// Time of day, monospaced — "14:02" — or a date for older entries.
    public let time: String
    /// What changed.
    public let kind: EventKind
    /// The device name, rendered at full strength: it is what the eye hunts for.
    public let subject: String
    /// The rest of the sentence, rendered secondary.
    ///
    /// Mixing weights inside one description is what makes the list scannable. Split
    /// here rather than at render time so the split is a decision, not a string parse.
    public let detail: String

    /// Creates an event. Each field is documented on the property it sets.
    public init(id: String, time: String, kind: EventKind, subject: String, detail: String) {
        self.id = id
        self.time = time
        self.kind = kind
        self.subject = subject
        self.detail = detail
    }

    /// The whole row as one sentence, for VoiceOver.
    public var accessibilityDescription: String {
        "\(time), \(kind.label), \(subject) \(detail)"
    }
}

/// A day's worth of events, under a date header.
public struct EventDayModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public var id: String { title }
    /// "TODAY — SUNDAY, AUG 31", uppercased at render time.
    public let title: String
    /// The events, newest first.
    public let events: [EventModel]

    /// Creates a day group. Each field is documented on the property it sets.
    public init(title: String, events: [EventModel]) {
        self.title = title
        self.events = events
    }
}

/// One hourly bucket in the timeline histogram.
public struct HistogramBucket: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public var id: Int { hour }
    /// Hours from the start of the window.
    public let hour: Int
    /// How many events landed in it.
    public let count: Int
    /// The axis label, on the buckets that carry one.
    public let label: String?

    /// Creates a bucket. Each field is documented on the property it sets.
    public init(hour: Int, count: Int, label: String? = nil) {
        self.hour = hour
        self.count = count
        self.label = label
    }
}
