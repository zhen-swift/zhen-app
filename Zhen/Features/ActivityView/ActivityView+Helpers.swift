import SwiftUI
import ZhenCore

extension ActivityView {
  /// One day's events, newest first.
  struct Day {
    let start: Date
    let title: String
    let events: [DerivedEvent]
  }

  /// The window's events, through the filter and the search.
  var filtered: [DerivedEvent] {
    Self.filtered(model.eventsInWindow, by: filter, search: search)
  }

  /// The one filter both the list and the histogram are drawn from.
  static func filtered(_ events: [DerivedEvent], by filter: ActivityFilter, search: String) -> [DerivedEvent] {
    let term = search.trimmingCharacters(in: .whitespaces)
    return events.filter { event in
      filter.includes(event.kind)
        && (term.isEmpty || event.subject.localizedStandardContains(term) || event.detail.localizedStandardContains(term))
    }
  }

  var showsHistogram: Bool {
    Self.showsHistogram(oldest: model.eventsInWindow.map(\.date).min(), now: .now)
  }

  /// Fewer than two hours of history draws three lonely bars; the list stands alone.
  static func showsHistogram(oldest: Date?, now: Date) -> Bool {
    guard let oldest else { return false }
    return now.timeIntervalSince(oldest) >= 2 * 3_600
  }

  var noMatchTitle: String {
    filter == .all
      ? String(localized: "No events match “\(search)”")
      : String(localized: "No \(filter.noun) events in this window")
  }

  func days(_ events: [DerivedEvent], calendar: Calendar = .current) -> [Day] {
    let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
    return grouped.keys.sorted(by: >).map { start in
      Day(
        start: start,
        title: Self.title(for: start, calendar: calendar),
        events: (grouped[start] ?? []).sorted { $0.at > $1.at }
      )
    }
  }

  /// "Today — Sunday, Aug 31".
  static func title(for day: Date, calendar: Calendar) -> String {
    let date = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    if calendar.isDateInToday(day) { return String(localized: "Today — \(date)") }
    if calendar.isDateInYesterday(day) { return String(localized: "Yesterday — \(date)") }
    return date
  }
}
