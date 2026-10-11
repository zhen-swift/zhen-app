import SwiftUI

/// The raised container the detail screen and the scan screen are built from.
///
/// A caption teaches what the card holds without a tooltip or a manual: "Known by ·
/// competing names by source — highest-trust source wins".
struct Card<Content: View>: View {
  let title: LocalizedStringKey?
  let caption: String?
  let content: Content

  init(_ title: LocalizedStringKey? = nil, caption: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.caption = caption
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: .zero) {
      if let title {
        HStack(alignment: .firstTextBaseline, spacing: .spacing.small) {
          Text(title)
            .font(.headline)
            .foregroundStyle(.textPrimary)
          if let caption {
            Text(caption)
              .font(.subheadline)
              .foregroundStyle(.textSecondary)
          }
          Spacer(minLength: .zero)
        }
        .padding(.spacing.large)
        Divider()
      }
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.surfaceRaised, in: .rect(cornerRadius: .cornerRadius.large))
    .overlay {
      RoundedRectangle(cornerRadius: .cornerRadius.large)
        .strokeBorder(.cardBorder, lineWidth: .borderWidth.hairline)
    }
  }
}

#Preview("Card — dark") {
  Card("Known by", caption: "competing names by source — highest-trust source wins") {
    Text("Bonjour · Sala de estar principal").padding(.spacing.large)
  }
  .padding(.spacing.xLarge)
  .background(.surface)
  .preferredColorScheme(.dark)
}

#Preview("Card — light") {
  Card("Open ports", caption: "last deep scan 22 min ago") {
    Text("443 · https").padding(.spacing.large)
  }
  .padding(.spacing.xLarge)
  .background(.surface)
  .preferredColorScheme(.light)
}
