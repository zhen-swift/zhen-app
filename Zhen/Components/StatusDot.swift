import SwiftUI

/// The small round mark beside a device or an event: filled for a state that holds, a ring
/// for one that does not.
///
/// Filled versus hollow carries online against offline without colour. The other tones
/// differed by hue alone — a partial run's amber dot beside a complete run's green one,
/// with the same words — until phase 3: with Differentiate Without Colour on, each tone
/// draws its own symbol.
struct StatusDot: View {
  let tone: Tone
  /// What it says to VoiceOver, when the tone's own word is not what this dot means. The
  /// footer's accent dot means "Scanning", not "Merged" (phase 3, system audit).
  var label: LocalizedStringKey?
  @ScaledMetric(relativeTo: .body) private var size = IconSize.small
  @Environment(\.accessibilityDifferentiateWithoutColor) private var withoutColor

  init(_ tone: Tone, label: LocalizedStringKey? = nil) {
    self.tone = tone
    self.label = label
  }

  var body: some View {
    Group {
      if withoutColor, let symbol = tone.symbol {
        Image(systemName: symbol)
          .resizable()
          .scaledToFit()
          .foregroundStyle(tone.color)
      } else if tone.isFilled {
        Circle().fill(tone.color)
      } else {
        Circle().strokeBorder(tone.color, lineWidth: .borderWidth.hairline)
      }
    }
    .frame(width: size, height: size)
    .accessibilityElement()
    .accessibilityAddTraits(.isImage)
    .accessibilityLabel(label ?? tone.label)
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
