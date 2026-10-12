import SwiftUI

/// A content control that gives under the pointer: a slight scale on press, on a spring.
///
/// Content controls only. Toolbar and menu buttons keep the platform's own behaviour.
struct PressButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.spring(duration: 0.25, bounce: 0.35), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == PressButtonStyle {
  /// `.buttonStyle(.press)`.
  static var press: PressButtonStyle { PressButtonStyle() }
}

#Preview("Press — dark") {
  PressButtonStylePreview().preferredColorScheme(.dark)
}

#Preview("Press — light") {
  PressButtonStylePreview().preferredColorScheme(.light)
}

#Preview("Press — increased contrast") {
  PressButtonStylePreview()
    .preferredColorScheme(.dark)
    .environment(\._colorSchemeContrast, .increased)
}

/// Hold the mouse down on the link to see the spring.
private struct PressButtonStylePreview: View {
  var body: some View {
    Button(String(localized: .openSystemSettings)) {}
      .buttonStyle(.press)
      .foregroundStyle(.accent)
      .padding(.spacing.xLarge)
      .background(.surface)
  }
}
