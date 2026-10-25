import SwiftUI
import ZhenCore

/// Everything that changed in the last 48 hours: a histogram of when, and the events by day.
///
/// The filter drives both. A histogram still counting everything while the list beneath it
/// is filtered would be two answers about the same data.
struct ActivityView: View {
  @Binding var search: String
  @Binding var filter: ActivityFilter
  @Environment(NetworkModel.self) var model

  var body: some View {
    let events = filtered
    Group {
      if model.eventsInWindow.isEmpty {
        ContentUnavailableView {
          Label(String(localized: .nothingHasChanged), systemImage: "waveform.path.ecg")
            .foregroundStyle(.textSecondary)
        } description: {
          Text(.eventsAppearHereWhenDevicesJoin)
            .foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activityEmpty")
      } else {
        List {
          ForEach(days(events), id: \.start) { day in
            Section {
              ForEach(day.events) { event in
                EventRow(event: event)
                  .accessibilityIdentifier("event-\(event.kind.rawValue)")
              }
            } header: {
              Text(day.title).sectionLabel()
            }
          }
        }
        .listStyle(.inset)
        .accessibilityLabel(String(localized: .eventsTitle))
        .accessibilityIdentifier("activityList")
        .overlay {
          if events.isEmpty {
            ContentUnavailableView {
              Label(noMatchTitle, systemImage: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.textSecondary)
            } description: {
              Text(.tryAnotherFilterClearSearch)
                .foregroundStyle(.textSecondary)
            }
            .accessibilityIdentifier("activityNoMatch")
          }
        }
        .safeAreaInset(edge: .top, spacing: .zero) {
          HeaderView(filter: $filter, events: events, showsHistogram: showsHistogram)
        }
      }
    }
    .navigationTitle(String(localized: .activity))
    .navigationSubtitle(String(localized: .last48HoursEvents(model.eventsInWindow.count)))
    .searchable(text: $search, placement: .toolbar, prompt: .filterDevice)
  }
}

#Preview("Activity — dark") {
  NavigationStack {
    ActivityView(search: .constant(""), filter: .constant(.all))
  }
  .environment(PreviewContainer.model(.home))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
  .preferredColorScheme(.dark)
}

#Preview("Activity — filter with no match") {
  NavigationStack {
    ActivityView(search: .constant(""), filter: .constant(.ports))
  }
  .environment(PreviewContainer.model(.home))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
}

#Preview("Activity — nothing has changed") {
  NavigationStack {
    ActivityView(search: .constant(""), filter: .constant(.all))
  }
  .environment(PreviewContainer.model(.empty))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
}
