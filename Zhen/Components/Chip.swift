import SwiftUI

/// A short tag beside a name or an address: `private`, `GATEWAY`, `WINNER`.
struct Chip: View {
  let title: LocalizedStringResource
  let style: Style

  init(_ title: LocalizedStringResource, style: Style = .neutral) {
    self.title = title
    self.style = style
  }

  var body: some View {
    Text(title)
      .font(style.font)
      .textCase(style.textCase)
      .foregroundStyle(style.foreground)
      .padding(.horizontal, .spacing.small)
      .padding(.vertical, .spacing.xxSmall)
      .background(style.fill, in: .rect(cornerRadius: .cornerRadius.small))
  }
}

#Preview("Chips — dark") {
  ChipPreview().preferredColorScheme(.dark)
}

#Preview("Chips — light") {
  ChipPreview().preferredColorScheme(.light)
}

#Preview("Chips — increased contrast") {
  ChipPreview()
    .preferredColorScheme(.dark)
    .environment(\._colorSchemeContrast, .increased)
}

private struct ChipPreview: View {
  var body: some View {
    VStack(alignment: .leading, spacing: .spacing.medium) {
      HStack(spacing: .spacing.small) {
        Text(verbatim: "GW1000").foregroundStyle(.textPrimary)
        Chip(.gateway, style: .accent)
      }
      HStack(spacing: .spacing.small) {
        Text(verbatim: "2A:5C:00:00:00:01").font(.callout.monospaced()).foregroundStyle(.textTertiary)
        Chip(.private)
      }
    }
    .padding(.spacing.xLarge)
    .background(.surface)
  }
}
