// Bundle identifiers stay com.jctec.zhen / com.jctec.zhen.helper, against AGENTS.md's
// dev.jc.<app>: they are baked into the helper's code-signing requirement and the installed
// launchd plist. Recorded as a deviation in the architecture document.

import SwiftUI

@main
struct ZhenApp: App {
  @State private var model = NetworkModel(environment: .current)

  var body: some Scene {
    // A single window, not a group: the scan runs from this window's task, and two windows
    // sharing one model would run it twice. It was a `WindowGroup` from stage A until
    // phase 3 despite this comment — ⌘N opened a second window (ledger, phase 3 stage 3).
    Window("Zhen", id: "main") {
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
      // Here, on the scene's content, not inside `SettingsView`: a view's own
      // `@AppStorage` reads the store its parent gives it. Set inside the body, it reached
      // only the children, and under fixtures Settings wrote the person's real
      // preferences — a UI test's subnet ended up in com.jctec.zhen (phase 3, stage 4).
      SettingsView()
        .defaultAppStorage(model.defaults)
        .environment(model)
        .launchAppearance(model.environment)
    }
  }
}
