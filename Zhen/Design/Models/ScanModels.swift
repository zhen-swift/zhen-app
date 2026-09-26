// ScanModels.swift — the live scan and the settings screen, as the views see them.

import SwiftUI

/// One of the three stages a scan runs.
///
/// **Three, not four.** The artboards show a fourth — Omada — and that integration is
/// dropped from the project, so the stage goes with it.
public enum ScanStage: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// ARP and the ping sweep.
    case discovery
    /// Bonjour, UPnP and NetBIOS.
    case naming
    /// Ports and banners.
    case deepScan

    /// Stable identity for a `ForEach`.
    public var id: String { rawValue }

    /// The card's title.
    public var title: String {
        switch self {
        case .discovery: "Discovery"
        case .naming: "Naming"
        case .deepScan: "Deep scan"
        }
    }
}

/// How far a stage has got.
public enum StageState: Sendable, Hashable {
    /// Not started.
    case queued
    /// Running. Carries a fraction where one is known, and nil where the work cannot be
    /// counted — a Bonjour browse yields over time and never says how much is left.
    case running(Double?)
    /// Finished.
    case done

    /// Whether this stage has not started.
    public var isQueued: Bool { if case .queued = self { true } else { false } }
    /// Whether this stage is the one happening now.
    public var isRunning: Bool { if case .running = self { true } else { false } }
    /// Whether this stage has finished.
    public var isDone: Bool { if case .done = self { true } else { false } }
}

/// One stage card on the live scan screen.
public struct StageModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public var id: String { stage.rawValue }
    /// Which stage.
    public let stage: ScanStage
    /// How far it has got.
    public let state: StageState
    /// The line under the title — "ARP + ping sweep · done in 12 s".
    public let detail: String

    /// Creates a stage. Each field is documented on the property it sets.
    public init(stage: ScanStage, state: StageState, detail: String) {
        self.stage = stage
        self.state = state
        self.detail = detail
    }
}

/// One thing that did not work, expressed so a person can read it.
public struct DegradationModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public var id: String { cause }
    /// The short cause, rendered bold — "mDNS unavailable".
    public let cause: String
    /// The consequence in plain language, rendered secondary.
    ///
    /// **Say the consequence, not the error.** "Bonjour names can't be read this scan"
    /// is useful; "mDNS: EPERM" is not.
    ///
    /// **And hedge what was inferred.** The Local Network grant cannot be queried — it
    /// is deduced from finding nothing by ICMP while the neighbour table is populated —
    /// so the copy says "appears to be denied". The artboards say "was denied", which
    /// claims a certainty we do not have. A tool that quietly overstates one thing has
    /// its other claims doubted.
    public let consequence: String
    /// The trailing link's title, or nil when there is nothing useful to do.
    public let actionTitle: String?

    /// Creates a degradation. Each field is documented on the property it sets.
    public init(cause: String, consequence: String, actionTitle: String?) {
        self.cause = cause
        self.consequence = consequence
        self.actionTitle = actionTitle
    }
}

/// A host arriving during a live scan, before it has a settled identity.
public struct ScanFindingModel: Identifiable, Sendable, Hashable {
    /// Stable identity.
    public let id: String
    /// The name, or nil while it is still being resolved.
    ///
    /// Nil renders as an italic "Resolving name…" placeholder. That placeholder is the
    /// difference between a scanner that looks like it is thinking and one that looks
    /// stuck.
    public let name: String?
    /// What is in flight — "found 4 s ago · NetBIOS query in flight".
    public let detail: String
    /// The address.
    public let ip: String
    /// The hardware address, if the neighbour table has one.
    public let mac: String?
    /// The trailing note — "randomized MAC — vendor lookup not possible".
    public let note: String

    /// Creates a finding. Each field is documented on the property it sets.
    public init(id: String, name: String?, detail: String, ip: String, mac: String?, note: String) {
        self.id = id
        self.name = name
        self.detail = detail
        self.ip = ip
        self.mac = mac
        self.note = note
    }
}

/// The state of a whole scan, for the live screen and the sidebar footer.
public enum ScanActivity: Sendable, Hashable {
    /// No scan has ever run. The footer reads "Never scanned"; it is never empty.
    case never
    /// A scan is running.
    case scanning(target: String)
    /// A scan finished cleanly.
    case idle(relative: String)
    /// A scan finished, but something was unavailable.
    ///
    /// Degradations do not evaporate when the scan ends. A green dot over an incomplete
    /// scan is a lie of omission, so this state survives into the device list.
    case partial(relative: String, unavailableSources: Int)
}

/// A sidebar destination.
///
/// **Three rooms, not five.** The artboards show Devices, Activity, Events, Omada and
/// Settings. Omada is dropped from the project. Events and Activity are the same
/// dataset behind two doors — Activity's own header says "12 events" and the Events
/// badge says 12 — and only one of them was ever designed, so Events folds into
/// Activity and keeps the filter chips that are already there.
public enum Room: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// The device table. The default room.
    case devices
    /// The event log and its histogram.
    case activity
    /// Preferences.
    case settings

    /// Stable identity for a `ForEach`.
    public var id: String { rawValue }

    /// The sidebar row's title.
    public var title: String {
        switch self {
        case .devices: "Devices"
        case .activity: "Activity"
        case .settings: "Settings"
        }
    }

    /// The key that selects this room, with Command.
    ///
    /// **This is the room's only keyboard route.** `NavigationSplitView` keeps its
    /// sidebar out of the Tab loop on macOS — measured, not assumed: driving Tab
    /// through a hosted window visits every control in the detail pane and none in the
    /// sidebar, and `focusSection()` on both columns does not change it. Without a
    /// shortcut, changing rooms is a mouse-only action, which is WCAG 2.2 criterion
    /// 2.1.1 Keyboard at level A.
    ///
    /// Numbered in `allCases` order, which is the order they are drawn in, so the key
    /// matches the position a person sees.
    public var shortcut: KeyEquivalent {
        switch self {
        case .devices: "1"
        case .activity: "2"
        case .settings: "3"
        }
    }

    /// The sidebar row's symbol.
    public var symbol: String {
        switch self {
        case .devices: Symbols.devices
        case .activity: Symbols.activity
        case .settings: Symbols.settings
        }
    }
}
