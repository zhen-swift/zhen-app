import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// The last few changes, the same rows as Activity, and the way there.
  struct RecentEventsCardView: View {
    let events: [DerivedEvent]
    let onShowAll: () -> Void

    var body: some View {
      Card(.recentEvents) {
        VStack(alignment: .leading, spacing: .zero) {
          if events.isEmpty {
            Text(.nothingHasChangedThisDeviceYet)
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
          Button(String(localized: .showActivity), action: onShowAll)
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
