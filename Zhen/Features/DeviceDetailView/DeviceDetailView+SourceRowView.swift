import SwiftUI

extension DeviceDetailView {
  /// One source and one thing it offered. A source's second offer and after leave the
  /// source column blank, so the eye reads them as the same source.
  struct SourceRowView: View {
    let source: String
    let value: String?
    let isWinner: Bool
    var showsSource = true

    var body: some View {
      HStack(spacing: .spacing.medium) {
        Text(showsSource ? source : "")
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
          .frame(minWidth: .dimension.eventKindLabel, alignment: .leading)
        Text(value ?? String(localized: .notAdvertised))
          .font(.body)
          .foregroundStyle(value == nil ? .textSecondary : .textPrimary)
        if isWinner { Chip(.winner, style: .accent) }
        Spacer()
      }
      .padding(.horizontal, .spacing.large)
      .padding(.vertical, showsSource ? .spacing.medium : .spacing.xSmall)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isStaticText)
      .accessibilityIdentifier(showsSource ? "knownBy-\(source)" : "knownBy-\(source)-\(value ?? "")")
    }
  }
}
