import SwiftUI

/// The menu bar item's menu: where the last scan stands, the scan itself, and the way back
/// to the window. Present only with "Keep watching from the menu bar" on.
struct MenuBarContentView: View {
  @Environment(NetworkModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Text(model.footerTitle(at: .now))
    Text(model.devicesSummary)
    Divider()
    if model.isBusy {
      Button(String(localized: .stopScan)) { model.stopScanning() }
    } else {
      Button(String(localized: .scanNow)) { model.startScan() }
        .keyboardShortcut("r")
    }
    Divider()
    Button(String(localized: .openZhen)) {
      openWindow(id: "main")
      NSApp.activate()
    }
    .keyboardShortcut("o")
    SettingsLink { Text(.settingsEllipsis) }
      .keyboardShortcut(",")
    Divider()
    Button(String(localized: .quitZhen)) { NSApp.terminate(nil) }
      .keyboardShortcut("q")
  }
}

/// The menu bar item itself, which also hosts the scan tasks while the mode is on: unlike
/// the window, it lives as long as the app.
struct MenuBarLabelView: View {
  @Environment(NetworkModel.self) private var model
  /// Read here too, not assumed from being on screen: a hidden menu bar item's view may
  /// still exist, and a second active host would run every scan twice.
  @AppStorage(Preferences.Key.keepInMenuBar) private var keepInMenuBar = false

  var body: some View {
    Image(systemName: model.isBusy ? "dot.radiowaves.left.and.right" : "square.grid.2x2")
      .accessibilityLabel(String(localized: .zhen))
      .scanHost(model, isActive: keepInMenuBar)
  }
}
