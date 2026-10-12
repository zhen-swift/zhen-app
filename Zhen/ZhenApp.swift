// Bundle identifiers stay com.jctec.zhen / com.jctec.zhen.helper, against AGENTS.md's
// dev.jc.<app>: they are baked into the helper's code-signing requirement and the installed
// launchd plist. Recorded as a deviation in the architecture document.

import AppIntents
import SwiftUI

@main
struct ZhenApp: App {
  @State private var model: NetworkModel

  init() {
    let model = NetworkModel(environment: .current)
    _model = State(initialValue: model)
    // The one model, for App Intents too: a Shortcut's Scan Network is the toolbar's.
    AppDependencyManager.shared.add(dependency: model)
  }

  var body: some Scene {
    // A single window, not a group: the scan runs from this window's task, and two windows
    // sharing one model would run it twice. It was a `WindowGroup` from stage A until
    // phase 3 despite this comment — ⌘N opened a second window (ledger, phase 3 stage 3).
    Window(String(localized: .zhen), id: "main") {
      RootView()
        // Screenshot mode: a fixed size the window must take, toolbar included — the slot
        // is the whole window. `defaultSize` alone lost to the frame AppKit had saved from
        // the last launch (1093 × 532, measured).
        .frame(
          width: model.environment.windowSize?.width,
          height: model.environment.windowSize.map { $0.height - WindowSize.toolbarHeight }
        )
        .environment(model)
        .defaultAppStorage(model.defaults)
        .launchAppearance(model.environment)
    }
    .defaultSize(
      width: model.environment.windowSize?.width ?? .windowSize.defaultWidth,
      height: model.environment.windowSize?.height ?? .windowSize.defaultHeight
    )
    .windowResizability(model.environment.windowSize == nil ? .contentMinSize : .contentSize)
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
