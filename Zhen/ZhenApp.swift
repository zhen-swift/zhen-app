// Bundle identifiers stay com.jctec.zhen / com.jctec.zhen.helper, against AGENTS.md's
// dev.jc.<app>: they are baked into the helper's code-signing requirement and the installed
// launchd plist. Recorded as a deviation in the architecture document.

import SwiftUI

@main
struct ZhenApp: App {
  @State private var model = NetworkModel(environment: .current)

  var body: some Scene {
    // A single window, not a group: the scan runs from this window's task, and two windows
    // sharing one model would run it twice.
    WindowGroup(id: "main") {
      RootView()
        .environment(model)
        .defaultAppStorage(model.defaults)
        .launchAppearance(model.environment)
    }
    .defaultSize(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
    .windowResizability(.contentMinSize)
    .commands {
      ZhenCommands(model: model)
    }

    Settings {
      SettingsView()
        .environment(model)
        .launchAppearance(model.environment)
    }
  }
}
