import SwiftUI

/// The small round mark beside a device or an event: filled for a state that holds, a ring
/// for one that does not.
///
/// Filled versus hollow carries the meaning as much as the colour does, so the dot still
/// reads for someone who cannot tell the hues apart.
struct StatusDot: View {
  let tone: Tone
  @ScaledMetric(relativeTo: .body) private var size = IconSize.small

  init(_ tone: Tone) {
    self.tone = tone
  }

  var body: some View {
    Group {
      if tone.isFilled {
        Circle().fill(tone.color)
      } else {
        Circle().strokeBorder(tone.color, lineWidth: .borderWidth.hairline)
      }
    }
    .frame(width: size, height: size)
    .accessibilityElement()
    .accessibilityLabel(tone.label)
  }
}

#Preview("Status dots — dark") {
  StatusDotPreview().preferredColorScheme(.dark)
}

#Preview("Status dots — light") {
  StatusDotPreview().preferredColorScheme(.light)
}

#Preview("Status dots — increased contrast") {
  StatusDotPreview()
    .preferredColorScheme(.dark)
    .environment(\._colorSchemeContrast, .increased)
}

private struct StatusDotPreview: View {
  var body: some View {
    VStack(alignment: .leading, spacing: .spacing.small) {
      ForEach(StatusDot.Tone.allCases, id: \.self) { tone in
        Label {
          Text(tone.label).foregroundStyle(.textSecondary)
        } icon: {
          StatusDot(tone)
        }
      }
    }
    .padding(.spacing.xLarge)
    .background(.surface)
  }
}
