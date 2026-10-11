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
        ContentUnavailableView(
          "Nothing has changed", systemImage: "waveform.path.ecg",
          description: Text("Events appear here when devices join, leave, or change.")
        )
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
        .accessibilityIdentifier("activityList")
        .overlay {
          if events.isEmpty {
            ContentUnavailableView(
              noMatchTitle, systemImage: "line.3.horizontal.decrease.circle",
              description: Text("Try another filter, or clear the search.")
            )
            .accessibilityIdentifier("activityNoMatch")
          }
        }
        .safeAreaInset(edge: .top, spacing: .zero) {
          HeaderView(filter: $filter, events: events, showsHistogram: showsHistogram)
        }
      }
    }
    .navigationTitle("Activity")
    .navigationSubtitle(String(localized: "Last 48 hours · \(model.eventsInWindow.count) events"))
    .searchable(text: $search, placement: .toolbar, prompt: "Filter by device")
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
