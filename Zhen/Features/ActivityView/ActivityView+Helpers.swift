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
    let term = search.trimmingCharacters(in: .whitespaces)
    return model.eventsInWindow.filter { event in
      filter.includes(event.kind)
        && (term.isEmpty || event.subject.localizedStandardContains(term) || event.detail.localizedStandardContains(term))
    }
  }

  /// Fewer than two hours of history draws three lonely bars; the list stands alone.
  var showsHistogram: Bool {
    guard let oldest = model.eventsInWindow.map(\.date).min() else { return false }
    return Date.now.timeIntervalSince(oldest) >= 2 * 3_600
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
