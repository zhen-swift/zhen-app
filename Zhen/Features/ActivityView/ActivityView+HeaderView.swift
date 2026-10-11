import SwiftUI
import ZhenCore

extension ActivityView {
  /// The filter and the histogram, pinned: they describe the whole list beneath them.
  struct HeaderView: View {
    @Binding var filter: ActivityFilter
    let events: [DerivedEvent]
    let showsHistogram: Bool

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.medium) {
        Picker("Show", selection: $filter) {
          ForEach(ActivityFilter.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityIdentifier("activityFilter")
        if showsHistogram {
          TimelineHistogram(buckets: TimelineHistogram.buckets(
            for: events.map(\.date), hours: 48, end: .now
          ))
          .frame(height: .dimension.histogramHeight)
          .accessibilityIdentifier("activityHistogram")
        }
      }
      .padding(.horizontal, .spacing.xLarge)
      .padding(.vertical, .spacing.medium)
      .background(.bar)
    }
  }
}
