// SettingsView.swift — three sections, Omada removed entirely.
//
// The helper panel is the one place in this app where the writing matters more than the
// layout, so A3 specifies the copy rather than leaving it to the implementer. It is
// reproduced verbatim below.

import SwiftUI

/// Whether the privileged helper is installed.
public enum HelperState: Sendable, Hashable {
    /// Not installed, and installable. The normal state, and everything still works.
    case notInstalled
    /// Installed, with the service name the OS knows it by.
    case installed(name: String)
    /// Registered with launchd and waiting for the person to allow it.
    ///
    /// `SMAppService.Status.requiresApproval`, and it used to be folded into
    /// `unavailable` — whose headline reads "Not installed." That was the app
    /// misreporting its own state, and it contradicted the very next sentence, which
    /// told the reader to go and approve the thing it had just said was not there.
    /// Somebody who reads the headline does not read on.
    ///
    /// It is a state of its own because the ACTIONS differ: there is nothing to
    /// install, the useful button opens Login Items, and Remove has to be there
    /// because a registration exists to remove.
    case awaitingApproval(name: String)
    /// Not installed and not installable from here, with the reason said plainly.
    ///
    /// A build that ships the panel with a live "Install Helper…" button it cannot honour
    /// is worse than one that says so: the button is a promise, and a promise that fails
    /// silently costs more trust than an honest absence. The section still renders,
    /// because a person deserves to know the capability exists and what it would add.
    case unavailable(reason: String)
}

/// Preferences.
public struct SettingsView: View {
    @Binding private var scanInterval: String
    @Binding private var deepScanNewDevices: Bool
    @Binding private var keepEventsFor: String
    @Binding private var budget: String
    private let intervalOptions: [String]
    private let retentionOptions: [String]
    private let budgetOptions: [String]
    private let subnet: String
    private let helper: HelperState
    private let version: String
    /// Registers the helper. The design module knows nothing about `SMAppService`; it
    /// renders a button and calls back, which is what keeps this target free of the
    /// scanner and the system frameworks it drags in.
    private let onInstallHelper: () -> Void
    /// Unregisters it. Present whenever the helper is installed, always.
    private let onRemoveHelper: () -> Void
    /// Opens Login Items, so a claim this screen makes can be checked against the OS
    /// that actually holds the registration rather than believed.
    private let onShowInSystemSettings: () -> Void

    /// Creates the screen.
    /// Creates the screen.
    ///
    /// The option lists are parameters rather than literals because a `Picker` whose
    /// selection is not among its options renders EMPTY — no error, no fallback, just a
    /// blank control. Hard-coding "90 days" here while the app's store keeps history for
    /// a session would have produced exactly that, and it would have looked like a
    /// layout bug rather than a mismatched list.
    public init(
        scanInterval: Binding<String> = .constant("Every 15 minutes"),
        deepScanNewDevices: Binding<Bool> = .constant(true),
        keepEventsFor: Binding<String> = .constant("90 days"),
        budget: Binding<String> = .constant("20 seconds"),
        intervalOptions: [String] = ["Off", "Every 5 minutes", "Every 15 minutes", "Every 60 minutes"],
        retentionOptions: [String] = ["7 days", "30 days", "90 days", "Forever"],
        budgetOptions: [String] = ["5 seconds", "10 seconds", "20 seconds", "60 seconds"],
        subnet: String = "10.10.20.0/24",
        helper: HelperState = .notInstalled,
        version: String = "Version 0.3.0 · database 0 MB",
        onInstallHelper: @escaping () -> Void = {},
        onRemoveHelper: @escaping () -> Void = {},
        onShowInSystemSettings: @escaping () -> Void = {}
    ) {
        self._scanInterval = scanInterval
        self._deepScanNewDevices = deepScanNewDevices
        self._keepEventsFor = keepEventsFor
        self._budget = budget
        self.intervalOptions = intervalOptions
        self.retentionOptions = retentionOptions
        self.budgetOptions = budgetOptions
        self.subnet = subnet
        self.helper = helper
        self.version = version
        self.onInstallHelper = onInstallHelper
        self.onRemoveHelper = onRemoveHelper
        self.onShowInSystemSettings = onShowInSystemSettings
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.separator)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section("Scanning") {
                        MenuRow("Scan automatically",
                                options: intervalOptions,
                                selection: $scanInterval)
                        Divider().overlay(Palette.separator)
                        // Not in A3's list for this section, and a scanner without it is
                        // worse: the budget is the trade between naming more devices and
                        // coming back sooner, and it is the one scanning preference that
                        // changes what the results contain.
                        MenuRow("Time limit per scan",
                                explanation: "Stages divide this between them; a scan that "
                                    + "runs out returns what it has",
                                options: budgetOptions,
                                selection: $budget)
                        Divider().overlay(Palette.separator)
                        StaticRow("Subnet", value: subnet, note: "auto, from the default route",
                                  isAddress: true)
                        Divider().overlay(Palette.separator)
                        ToggleRow("Deep-scan new devices",
                                  explanation: "Run a port scan the first time a device is seen",
                                  isOn: $deepScanNewDevices)
                    }
                    section("History") {
                        MenuRow("Keep events for",
                                options: retentionOptions,
                                selection: $keepEventsFor)
                        Divider().overlay(Palette.separator)
                        StaticRow("Device identity history", value: "Kept forever",
                                  note: "— it\u{2019}s what makes merges possible")
                    }
                    section("Privileged engine") { helperPanel }
                }
                .padding(Metrics.contentInset)
                // A MEASURE limit, not a box. Prose stops being readable past roughly 70
                // characters a line however wide the window is, so this is a typographic
                // constraint on line length. The plan names it as the other kind that stays.
                .frame(maxWidth: Metrics.Detail.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Palette.surface)
    }

    private var header: some View {
        ScreenHeader("Settings", subtitle: version)
    }

    private func section<Content: View>(
        _ title: String, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.unit * 2) {
            SectionLabel(title)
            Card { VStack(spacing: 0) { content() } }
        }
        // 24 above, 8 below — the standard macOS settings rhythm.
        .padding(.top, Metrics.unit * 6)
    }

    private var helperPanel: some View {
        VStack(alignment: .leading, spacing: Metrics.unit * 3) {
            HStack(alignment: .top, spacing: Metrics.unit * 4) {
                VStack(alignment: .leading, spacing: Metrics.unit * 2) {
                    Text("Use the privileged engine")
                        .font(.control)
                        .foregroundStyle(Palette.textPrimary)
                    // Verbatim from A3. Plain words, what it does, what it cannot do,
                    // and the reassurance that everything else works without it.
                    Text("OS fingerprinting and fast SYN port scans need raw network sockets, "
                         + "which macOS only grants to root. The engine is a small helper that "
                         + "runs only during scans and only sends results back to this app. "
                         + "Everything else works without it.")
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        // A MEASURE limit, not a box. Prose stops being readable past roughly 70
                        // characters a line however wide the window is, so this is a typographic
                        // constraint on line length. The plan names it as the other kind that stays.
                        .frame(maxWidth: Metrics.Detail.proseMaxWidth, alignment: .leading)
                    stateLine
                }
                Spacer(minLength: Metrics.unit * 4)
                actions
            }
        }
        .padding(Metrics.cardPadding)
    }

    @ViewBuilder private var stateLine: some View {
        switch helper {
        case .notInstalled:
            Text("Not installed.")
                .font(.controlEmphasis)
                .foregroundStyle(Palette.textSecondary)
        case .installed(let name):
            HStack(spacing: Metrics.unit * 2) {
                StatusDot(.online)
                Text("Installed · \(name)")
                    .font(.controlEmphasis)
                    .foregroundStyle(Palette.textPrimary)
            }
        case .awaitingApproval(let name):
            VStack(alignment: .leading, spacing: Metrics.unit) {
                HStack(spacing: Metrics.unit * 2) {
                    // Scanning rather than online: it is registered and not yet
                    // running, which is a third thing and should not read as either.
                    StatusDot(.scanning)
                    Text("Installed · waiting for your approval")
                        .font(.controlEmphasis)
                        .foregroundStyle(Palette.textPrimary)
                }
                Text("""
                    \(name) is registered and cannot run until you allow it in System \
                    Settings, under General then Login Items. Until then scans run \
                    without the layer-2 sweep, which is the ordinary unprivileged \
                    behaviour and finds every host that answers ICMP.
                    """)
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    // A MEASURE limit, not a box. Prose stops being readable past roughly 70
                    // characters a line however wide the window is, so this is a typographic
                    // constraint on line length. The plan names it as the other kind that stays.
                    .frame(maxWidth: Metrics.Detail.proseMaxWidth, alignment: .leading)
            }
        case .unavailable(let reason):
            VStack(alignment: .leading, spacing: Metrics.unit) {
                Text("Not installed.")
                    .font(.controlEmphasis)
                    .foregroundStyle(Palette.textSecondary)
                Text(reason)
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    // A MEASURE limit, not a box. Prose stops being readable past roughly 70
                    // characters a line however wide the window is, so this is a typographic
                    // constraint on line length. The plan names it as the other kind that stays.
                    .frame(maxWidth: Metrics.Detail.proseMaxWidth, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var actions: some View {
        switch helper {
        case .notInstalled:
            PrimaryButton("Install Helper…", action: onInstallHelper)
        case .awaitingApproval:
            VStack(alignment: .trailing, spacing: Metrics.unit * 2) {
                // The action, not a courtesy. The only thing standing between this
                // state and a working helper is a toggle in that pane.
                PrimaryButton("Open Login Items…", action: onShowInSystemSettings)
                SecondaryButton("Remove", action: onRemoveHelper)
            }
        case .unavailable:
            // No button at all. See `HelperState.unavailable`.
            EmptyView()
        case .installed:
            VStack(alignment: .trailing, spacing: Metrics.unit * 2) {
                // `SMAppService.openSystemSettingsLoginItems()`, so a person can verify
                // our claim in the OS rather than believing us.
                SecondaryButton("Show in System Settings…", action: onShowInSystemSettings)
                // Always present. An installer without an uninstaller beside it is how
                // software earns distrust.
                SecondaryButton("Remove", action: onRemoveHelper)
            }
        }
    }
}

// There is no Test Connection button anywhere on this screen. It belonged to the
// controller integration, which is gone; the scanning section's only verification is
// running a scan.

#Preview("Settings — dark") {
    SettingsView()
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("Settings — light") {
    SettingsView()
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Settings — helper unavailable") {
    SettingsView(helper: .unavailable(
        reason: "Installing the scan engine isn\u{2019}t available in this build. "
            + "Everything on every other screen works without it."
    ))
    .frame(width: 1182, height: 760)
    .preferredColorScheme(.dark)
}

#Preview("Settings — helper installed") {
    SettingsView(helper: .installed(name: "Zhen Scan Engine"))
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.dark)
}

// ── Narrow variants ────────────────────────────────────────────────────────────
//
// Added in stage 3. The previews were 59 canvases each showing one condition: a light
// and a dark copy of the same layout at the same width. A design system whose previews
// all agree cannot show a layout failing.
//
// Width, and not type size. `RESPONSIVE-plan.md` asks for both, and stage 1 measured
// Dynamic Type to be inert on macOS — `@ScaledMetric` and text styles both return the
// same value at `.large` and `.accessibility3`, so a type variant would be a second
// copy of the first. Width is what a Mac window actually varies.

#Preview("Settings — narrow") {
    SettingsView()
        .frame(width: 620, height: 640)
        .preferredColorScheme(.dark)
}
