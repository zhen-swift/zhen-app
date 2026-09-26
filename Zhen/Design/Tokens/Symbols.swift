// Symbols.swift — every icon in the app, and they are all SF Symbols.
//
// No bundled PNGs and no custom vector assets: symbols scale, adapt their weight to the
// text they sit beside, respond to accessibility settings, and match every other Mac app
// the user has open.
//
// The one exception is ``ConfidenceMeter``, which is drawn rather than named, because
// the number of filled bars is DATA and not decoration.
//
// Every symbol placed in a view either gets an accessibility label or is hidden. A dot
// next to the word "Online" is decorative; a dot that is the only indication of state
// needs a label. Getting that backwards produces either silence or a stutter.

/// SF Symbol names, by role.
public enum Symbols {
    // ── Navigation ───────────────────────────────────────────────────────────────
    /// The Devices room.
    public static let devices = "square.grid.2x2.fill"
    /// The Activity room.
    public static let activity = "waveform.path.ecg"
    /// The Settings room.
    public static let settings = "gearshape"

    // ── Actions ──────────────────────────────────────────────────────────────────
    /// Leading glyph in the search field.
    public static let search = "magnifyingglass"
    /// Rescan.
    public static let rescan = "arrow.clockwise"
    /// Back to the list.
    public static let back = "chevron.left"
    /// "Show in System Settings…".
    public static let reveal = "arrow.up.forward.app"
    /// A disclosure that expands the degradation rows.
    public static let disclosure = "chevron.right"

    // ── Device kinds ─────────────────────────────────────────────────────────────
    /// A laptop.
    public static let laptop = "laptopcomputer"
    /// A desktop.
    public static let desktop = "desktopcomputer"
    /// A television or set-top box.
    public static let tv = "appletv"
    /// A router or gateway.
    public static let router = "wifi.router"
    /// A phone.
    public static let phone = "iphone"
    /// A printer.
    public static let printer = "printer"
    /// Anything we could not identify — which on a real network is most of it.
    public static let unknown = "questionmark.circle"

    // ── Status ───────────────────────────────────────────────────────────────────
    /// A filled dot.
    public static let online = "circle.fill"
    /// A hollow dot.
    public static let offline = "circle"
    /// A finished stage.
    public static let done = "checkmark.circle.fill"
    /// A stage that has not started.
    public static let queued = "circle"
    /// A degradation.
    public static let warning = "exclamationmark.triangle.fill"

    // ── Event kinds ──────────────────────────────────────────────────────────────
    /// A device moved address.
    public static let ipChanged = "arrow.left.arrow.right"
    /// A device joined.
    public static let appeared = "plus.circle.fill"
    /// A device stopped answering.
    public static let disappeared = "minus.circle.fill"
    /// Two identities became one.
    public static let merged = "arrow.triangle.merge"
    /// A device's name changed.
    public static let renamed = "pencil"
    /// A port started answering.
    public static let portOpened = "lock.open.fill"
    /// A port stopped answering.
    public static let portClosed = "lock.fill"

    // ── Empty states ─────────────────────────────────────────────────────────────
    /// Nothing scanned yet.
    public static let noScan = "antenna.radiowaves.left.and.right"
    /// A search that matched nothing.
    public static let noMatches = "magnifyingglass"
    /// A quiet event log.
    public static let noEvents = "clock.arrow.circlepath"

    /// Every symbol above, so they can be checked as a set.
    ///
    /// **Every `static let` in this type must appear here.** A name that is not in this
    /// list is a name nothing verifies, and an SF Symbol that does not exist at the
    /// deployment target renders as nothing at all — a silently empty space where an
    /// icon should be, which no compiler and no preview flags. `SymbolTests` reads this
    /// file's source and fails if the two ever disagree, so forgetting is caught rather
    /// than merely discouraged.
    public static let all: [String] = [
        devices, activity, settings,
        search, rescan, back, reveal, disclosure,
        laptop, desktop, tv, router, phone, printer, unknown,
        online, offline, done, queued, warning,
        ipChanged, appeared, disappeared, merged, renamed, portOpened, portClosed,
        noScan, noMatches, noEvents,
    ]
}
