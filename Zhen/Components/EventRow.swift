import SwiftUI
import ZhenCore

/// One change: when, what kind, and the sentence — the device's name in the primary ink,
/// the rest quieter, because the name is what the eye hunts for.
struct EventRow: View {
  let event: DerivedEvent
  /// Whether the time carries its date. Activity groups rows under day headers and leaves
  /// it off; a short list with no headers, like the detail's, needs it for anything older
  /// than today.
  var showsDate = false

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: .spacing.medium) {
      Text(event.date, format: showsDate ? .dateTime.month(.abbreviated).day().hour().minute() : .dateTime.hour().minute())
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
      Text(Self.sentence(event))
        .font(.body)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: .zero)
    }
    .padding(.vertical, .spacing.xSmall)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isStaticText)
  }
}

extension EventRow {
  /// The subject in the primary ink, the detail quieter: two strings core wrote, side by
  /// side. Styled runs, not a format string — there is nothing here to translate.
  static func sentence(_ event: DerivedEvent) -> AttributedString {
    var subject = AttributedString(event.subject)
    subject.foregroundColor = .textPrimary
    var detail = AttributedString(" " + event.detail)
    detail.foregroundColor = .textSecondary
    return subject + detail
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
