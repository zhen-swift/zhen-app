import SwiftUI

/// The small capitals over a group: the sidebar's app name, a day in Activity, a field in a
/// card ("CONNECTION", "SSID").
///
/// Measured on the artboards at about 11 pt with a wide track, in the tertiary grey.
struct SectionLabel: ViewModifier {
  /// Letter spacing, in points at the default size. The one number the type roles need.
  private static let tracking = 0.8

  func body(content: Content) -> some View {
    content
      .font(.subheadline.weight(.semibold))
      .textCase(.uppercase)
      .tracking(Self.tracking)
      .foregroundStyle(.textTertiary)
  }
}

extension View {
  /// Small tracked capitals over a group.
  func sectionLabel() -> some View {
    modifier(SectionLabel())
  }
}

#Preview("Section label — dark") {
  SectionLabelPreview().preferredColorScheme(.dark)
}

#Preview("Section label — light") {
  SectionLabelPreview().preferredColorScheme(.light)
}

#Preview("Section label — increased contrast") {
  SectionLabelPreview()
    .preferredColorScheme(.dark)
    .environment(\._colorSchemeContrast, .increased)
}

private struct SectionLabelPreview: View {
  var body: some View {
    VStack(alignment: .leading, spacing: .spacing.xSmall) {
      Text(.zhen).sectionLabel()
      Text(verbatim: "Today — Sunday, Aug 31").sectionLabel()
    }
    .padding(.spacing.xLarge)
    .background(.surfaceRaised)
  }
}
