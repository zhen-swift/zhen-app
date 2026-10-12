import SwiftUI

/// The menu bar. Every action in the app is here; the frequent ones have shortcuts. Each
/// reaches the front window through `@FocusedValue`, never through a global.
struct ZhenCommands: Commands {
  /// Scanning is the app's, not a window's: there is one window and one model, and a scan
  /// asked for in the instant before the window publishes its focused value must still
  /// start. Measured: ⌘R right after launch found Scan Now disabled.
  let model: NetworkModel
  @FocusedValue(\.windowActions) private var window

  var body: some Commands {
    CommandGroup(before: .sidebar) {
      ForEach(Room.allCases) { room in
        Button(room.title) { window?.showRoom(room) }
          .keyboardShortcut(room.shortcut, modifiers: .command)
          .disabled(window == nil)
      }
      Divider()
    }

    CommandGroup(replacing: .importExport) {
      Button("Export History…") { window?.exportHistory() }
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .disabled(window == nil)
    }

    CommandGroup(after: .pasteboard) {
      Divider()
      Button("Find…") { window?.focusSearch() }
        .keyboardShortcut("f", modifiers: .command)
        .disabled(window == nil)
    }

    CommandMenu("Scan") {
      // Enabled state from the window when it has published (its focused value is re-sent
      // whenever the window redraws), from the model only before then. A `Commands` body
      // is not re-evaluated by @Observable alone: Stop Scan stayed disabled from launch.
      Button("Scan Now") { model.startScan() }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(window?.isScanning ?? model.isBusy)
      Button("Stop Scan") { model.stopScanning() }
        .keyboardShortcut(".", modifiers: .command)
        .disabled(!(window?.isScanning ?? model.isBusy))
    }

    CommandMenu("Device") {
      Button("Open") { window?.openSelection() }
        .keyboardShortcut("o", modifiers: .command)
        .disabled(window?.room != .devices || window?.selectionCount != 1)
      Button("Back to Devices") { window?.goBack() }
        .keyboardShortcut("[", modifiers: .command)
        .disabled(window?.canGoBack != true)
      Divider()
      Button("Rename…") { window?.renameSelection() }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(window?.room != .devices || (window?.selectionCount != 1 && window?.canGoBack != true))
      Button("Scan Ports") { window?.scanSelectionPorts() }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(window?.room != .devices || window?.isScanning == true || (window?.selectionCount != 1 && window?.canGoBack != true))
      Button("Show in Activity") { window?.showSelectionInActivity() }
        .keyboardShortcut("a", modifiers: [.command, .shift])
        .disabled(window?.room != .devices || (window?.selectionCount != 1 && window?.canGoBack != true))
      Divider()
      Button("Copy Address") { window?.copyAddresses() }
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .disabled(window?.room != .devices || (window?.selectionCount == 0 && window?.canGoBack != true))
      Button("Copy MAC Address") { window?.copyMACAddresses() }
        .keyboardShortcut("c", modifiers: [.command, .option, .shift])
        .disabled(window?.room != .devices || (window?.selectionCount == 0 && window?.canGoBack != true))
    }

    CommandGroup(after: .sidebar) {
      Picker("Activity Filter", selection: Binding(
        get: { window?.activityFilter ?? .all },
        set: { window?.setActivityFilter($0) }
      )) {
        ForEach(ActivityFilter.allCases.enumerated(), id: \.element) { index, filter in
          Text(filter.title)
            .tag(filter)
            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command, .option])
        }
      }
      .disabled(window?.room != .activity)
    }
  }
}
