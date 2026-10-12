import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// The last few changes, the same rows as Activity, and the way there.
  struct RecentEventsCardView: View {
    let events: [DerivedEvent]
    let onShowAll: () -> Void

    var body: some View {
      Card("Recent events") {
        VStack(alignment: .leading, spacing: .zero) {
          if events.isEmpty {
            Text("Nothing has changed for this device yet.")
              .font(.body)
              .foregroundStyle(.textSecondary)
              .padding(.spacing.large)
          } else {
            ForEach(events) { event in
              EventRow(event: event, showsDate: !Calendar.current.isDateInToday(event.date))
                .padding(.horizontal, .spacing.large)
            }
          }
          Divider()
          Button("Show in Activity", action: onShowAll)
            .buttonStyle(.link)
            .padding(.spacing.large)
            .accessibilityIdentifier("showInActivityButton")
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("recentEventsCard")
    }
  }
}
