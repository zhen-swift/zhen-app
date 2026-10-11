import SwiftUI

extension DeviceDetailView {
  /// One source and what it offered.
  struct SourceRowView: View {
    let source: String
    let value: String?
    let isWinner: Bool

    var body: some View {
      HStack(spacing: .spacing.medium) {
        Text(source)
          .font(.subheadline)
          .foregroundStyle(.textSecondary)
          .frame(minWidth: .dimension.eventKindLabel, alignment: .leading)
        Text(value ?? String(localized: "— not advertised"))
          .font(.body)
          .foregroundStyle(value == nil ? .textSecondary : .textPrimary)
        if isWinner { Chip("Winner", style: .accent) }
        Spacer()
      }
      .padding(.horizontal, .spacing.large)
      .padding(.vertical, .spacing.medium)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("knownBy-\(source)")
    }
  }
}
