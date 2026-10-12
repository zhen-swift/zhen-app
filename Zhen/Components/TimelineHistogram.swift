import Charts
import SwiftUI

/// The rhythm of change over the window: one bar per hour, the busiest at full strength.
///
/// No axis: the bars are a rhythm, not a measurement, and an axis invites reading a
/// precision that is not there. Hovering a bar says its count.
struct TimelineHistogram: View {
  struct Bucket: Identifiable, Equatable {
    let start: Date
    let count: Int
    var id: Date { start }
  }

  let buckets: [Bucket]
  @State private var hovered: Date?

  var body: some View {
    let busiest = buckets.map(\.count).max() ?? 0
    Chart(buckets) { bucket in
      BarMark(
        x: .value("Hour", bucket.start, unit: .hour),
        y: .value("Events", bucket.count)
      )
      .foregroundStyle(.accent.opacity(bucket.count == busiest && busiest > 0 ? 1 : 0.6))
      .clipShape(.rect(cornerRadius: .cornerRadius.small / 2))
      if let hovered, Calendar.current.isDate(hovered, equalTo: bucket.start, toGranularity: .hour) {
        RuleMark(x: .value("Hour", bucket.start, unit: .hour))
          .foregroundStyle(.clear)
          .annotation(position: .top) {
            Text("\(bucket.count) events")
              .font(.caption)
              .foregroundStyle(.textPrimary)
              .padding(.spacing.xSmall)
              .background(.regularMaterial, in: .rect(cornerRadius: .cornerRadius.small))
          }
      }
    }
    .chartYAxis(.hidden)
    .chartXAxis {
      AxisMarks(values: .stride(by: .hour, count: 6)) {
        AxisValueLabel(format: .dateTime.hour(), centered: false)
      }
    }
    .chartXSelection(value: $hovered)
    // One element, not Swift Charts' per-bar container: the bars are a rhythm (A2), and
    // what a person — or a test — needs from them is the total over the window. In the
    // label, because a generic element on macOS carries no accessibility value (measured).
    // The total is stated so it can be checked against the list it summarises: a
    // histogram counting what the list has filtered out is two answers about one dataset.
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isImage)
    .accessibilityLabel("Events per hour: \(buckets.reduce(0) { $0 + $1.count }) over \(buckets.count) hours")
  }

  /// Hourly buckets over `hours` ending at `end`, counting `dates`.
  static func buckets(for dates: [Date], hours: Int, end: Date, calendar: Calendar = .current) -> [Bucket] {
    let last = calendar.dateInterval(of: .hour, for: end)?.start ?? end
    let starts = (0..<hours).reversed().compactMap { calendar.date(byAdding: .hour, value: -$0, to: last) }
    var counts: [Date: Int] = [:]
    for date in dates {
      if let hour = calendar.dateInterval(of: .hour, for: date)?.start { counts[hour, default: 0] += 1 }
    }
    return starts.map { Bucket(start: $0, count: counts[$0] ?? 0) }
  }
}

#Preview("Histogram — dark") {
  TimelineHistogram(buckets: TimelineHistogram.buckets(
    for: PreviewContainer.events.map(\.date), hours: 48, end: .now
  ))
  .frame(height: .dimension.histogramHeight)
  .padding(.spacing.xLarge)
  .background(.surface)
  .preferredColorScheme(.dark)
}
