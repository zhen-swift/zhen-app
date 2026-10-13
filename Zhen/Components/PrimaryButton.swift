import SwiftUI

/// The one prominent action on a screen: Scan Now, Scan Again, Install Helper….
///
/// A thin wrapper. `.borderedProminent` already is the accent fill and the contrast-correct
/// label; this exists so the call sites say what the control is for, and carry an
/// identifier and a symbol, not to restyle it.
struct PrimaryButton: View {
  let title: LocalizedStringResource
  let systemImage: String
  let identifier: String
  let action: () -> Void

  init(_ title: LocalizedStringResource, systemImage: String, identifier: String, action: @escaping () -> Void) {
    self.title = title
    self.systemImage = systemImage
    self.identifier = identifier
    self.action = action
  }

  var body: some View {
    Button(title, systemImage: systemImage, action: action)
      .buttonStyle(.borderedProminent)
      // A toolbar shows icons alone by default; the one primary action keeps its words.
      .labelStyle(.titleAndIcon)
      .accessibilityIdentifier(identifier)
  }
}

#Preview("Primary button") {
  PrimaryButton(.scanNow, systemImage: "dot.radiowaves.left.and.right", identifier: "preview") {}
    .padding(.spacing.xLarge)
    .background(.surface)
}
