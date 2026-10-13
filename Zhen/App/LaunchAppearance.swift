import SwiftUI

extension View {
  /// Pins the appearance a launch asked for (`-Appearance`, `-Contrast`), for screenshots
  /// and the four-appearance gate. Without those arguments it changes nothing.
  func launchAppearance(_ environment: AppEnvironment) -> some View {
    modifier(LaunchAppearance(environment: environment))
  }
}

private struct LaunchAppearance: ViewModifier {
  let environment: AppEnvironment

  func body(content: Content) -> some View {
    if environment.increasedContrast {
      content
        .preferredColorScheme(environment.colorScheme)
        .environment(\._colorSchemeContrast, .increased)
    } else {
      content.preferredColorScheme(environment.colorScheme)
    }
  }
}
