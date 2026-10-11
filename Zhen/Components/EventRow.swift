import SwiftUI
import ZhenCore

/// One change: when, what kind, and the sentence — the device's name in the primary ink,
/// the rest quieter, because the name is what the eye hunts for.
struct EventRow: View {
  let event: DerivedEvent

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: .spacing.medium) {
      Text(event.date, format: .dateTime.hour().minute())
        .font(.callout.monospaced())
        .foregroundStyle(.textSecondary)
      StatusDot(event.kind.tone)
        .accessibilityHidden(true)
      Text(event.kind.label)
        .font(.caption.bold())
        .textCase(.uppercase)
        .foregroundStyle(event.kind.textColor)
        .lineLimit(1)
        .frame(width: .dimension.eventKindLabel, alignment: .leading)
      Text("\(Text(event.subject).foregroundStyle(.textPrimary)) \(Text(event.detail).foregroundStyle(.textSecondary))")
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: .zero)
    }
    .padding(.vertical, .spacing.xSmall)
    .accessibilityElement(children: .combine)
  }
}

#Preview("Event rows — dark") {
  VStack(alignment: .leading) {
    ForEach(PreviewContainer.events.prefix(5)) { EventRow(event: $0) }
  }
  .padding(.spacing.xLarge)
  .background(.surface)
  .preferredColorScheme(.dark)
}
