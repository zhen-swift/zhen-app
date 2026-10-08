// Bundle identifiers stay com.jctec.zhen / com.jctec.zhen.helper, against AGENTS.md's
// dev.jc.<app>: they are baked into the helper's code-signing requirement and the installed
// launchd plist. Recorded as a deviation in the architecture document when phase 3 makes it.

import SwiftUI

@main
struct ZhenApp: App {
  var body: some Scene {
    WindowGroup {
      // Phase 1 builds the design system and no screen; phase 2 replaces this.
      ContentUnavailableView(
        "Zhen is being rebuilt",
        systemImage: "hammer",
        description: Text("The design system comes first.")
      )
    }
  }
}
