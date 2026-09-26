// RootView.swift — the window, and the only place stream lifetime is decided.

import ZhenCore
import SwiftUI

/// The whole window.
struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        // The same `ZhenWindow` the previews render. The split-view configuration
        // — the pinned column width, the style, the sidebar background — lives there, so
        // there is one window and it is the one that gets looked at.
        ZhenWindow {
            Sidebar(
                selection: $model.room,
                deviceCount: model.deviceCount,
                eventCount: model.eventCount,
                activity: model.isScanning
                    ? .scanning(target: model.targetDescription)
                    : model.activity,
                target: model.targetDescription
            )
        } detail: {
            detail
        }
        // ── Stream lifetime, and there is no other ──────────────────────────────
        //
        // Keyed on the scan identity, so a new scan cancels the previous task and a
        // disappearing view cancels the running one. The cancellation propagates through
        // the task group into `AsyncStream.onTermination`, which is where the sockets
        // close. Nothing calls `stopScan()` because nothing can: lifetime is structural.
        // History first, and separately. This one runs once when the window appears;
        // the scan task below is keyed on the scan identity and re-runs whenever a scan
        // is requested. Folding them together would mean either reloading history on
        // every scan or never loading it until one finished.
        .task {
            // Platform first, then history. Resolving the platform asks whether a
            // capture device can be had, and with the privileged helper installed that
            // question crosses an XPC connection — so it cannot happen in an `init`.
            await model.prepare()
            await model.loadHistory()
        }
        .task(id: model.scanID) {
            await model.runScan()
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.room {
        case .devices:
            if model.isScanning {
                LiveScanView(
                    target: model.targetDescription,
                    elapsed: model.elapsed,
                    stages: model.stages,
                    degradations: model.degradations,
                    state: model.liveState
                )
            } else if let selection = model.selection {
                DeviceDetailLoader(model: model, id: selection)
            } else {
                DeviceListView(
                    state: model.listState,
                    searchText: $model.searchText,
                    selection: $model.selection,
                    onScan: { model.requestScan() }
                )
            }
        case .activity:
            ActivityView(days: model.days, buckets: model.buckets, category: $model.category)
        case .settings:
            SettingsScreen(model: model)
        }
    }
}

/// Resolves a selected row into a full detail model.
///
/// A loader rather than a computed property because the store is an actor: reading it is
/// `async`, and a view body cannot await. The `.task(id:)` does the hop and the body
/// renders whatever has arrived — which on the first frame is the empty state, for about
/// one frame.
struct DeviceDetailLoader: View {
    let model: AppModel
    let id: DeviceRowModel.ID
    @State private var detail: DeviceDetailModel?

    var body: some View {
        Group {
            if let detail {
                DeviceDetailView(detail) { model.selection = nil }
            } else {
                Color.clear.background(Palette.surface)
            }
        }
        .task(id: id) {
            detail = await model.detail(for: id)
        }
    }
}

/// Settings, bound to real values.
struct SettingsScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsView(
            scanInterval: $model.settings.scanInterval,
            deepScanNewDevices: $model.settings.deepScanNewDevices,
            keepEventsFor: $model.settings.keepEventsFor,
            budget: $model.settings.budgetLabel,
            intervalOptions: AppSettings.intervalOptions,
            retentionOptions: AppSettings.retentionOptions,
            budgetOptions: AppSettings.budgetOptions,
            subnet: model.targetDescription,
            // Read from the system, never remembered. `SMAppService.status` can change
            // without this app — an administrator disabling the item, an upgrade asking
            // for re-approval, an older copy leaving a registration behind — and a
            // cached answer would disagree with the OS at exactly the moment somebody
            // is trying to work out what is running.
            helper: model.helperState,
            // The version comes from the same constant the bundle's plist is generated
            // from, because a version written twice is a version that disagrees with
            // itself — the command line printed 0.2.0 next to a 0.4.0 plist for two
            // releases on exactly this mistake.
            version: "Version \(InfoPlist.version) · \(model.historyDescription)",
            onInstallHelper: { model.installHelper() },
            onRemoveHelper: { model.removeHelper() },
            onShowInSystemSettings: { HelperInstaller.showInSystemSettings() }
        )
    }
}
