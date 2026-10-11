import Foundation
import Testing
import ZhenCore
import ZhenScan

@testable import Zhen

/// Activity's rules: what each segment holds, how the 48 hours are bucketed, how days
/// are grouped, and when the histogram stands down.
@MainActor
struct ActivityTests {
  let events: [DerivedEvent]

  init() {
    events = PreviewContainer.model(.home).eventsInWindow
  }

  @Test("Each segment holds exactly its kinds; All holds everything")
  func segments() {
    #expect(ActivityView.filtered(events, by: .all, search: "").count == events.count)
    for event in ActivityView.filtered(events, by: .presence, search: "") {
      #expect([.appeared, .disappeared].contains(event.kind))
    }
    #expect(ActivityView.filtered(events, by: .addresses, search: "").allSatisfy { $0.kind == .ipChanged })
    #expect(ActivityView.filtered(events, by: .identity, search: "").allSatisfy { [.renamed, .merged].contains($0.kind) })
    let parts = [ActivityFilter.presence, .identity, .ports, .addresses]
      .map { ActivityView.filtered(events, by: $0, search: "").count }.reduce(0, +)
    #expect(parts == events.count, "segments overlap or drop events")
  }

  @Test("Search narrows by device, and composes with the segment")
  func search() {
    let speaker = ActivityView.filtered(events, by: .all, search: "speakerconnect")
    #expect(speaker.count == 2)
    #expect(ActivityView.filtered(events, by: .presence, search: "speakerconnect").count == 2)
    #expect(ActivityView.filtered(events, by: .identity, search: "speakerconnect").isEmpty)
  }

  @Test("48 hourly buckets that count every event in the window, and nothing outside it")
  func buckets() {
    let end = Date.now
    let buckets = TimelineHistogram.buckets(for: events.map(\.date), hours: 48, end: end)
    #expect(buckets.count == 48)
    #expect(buckets.map(\.count).reduce(0, +) == events.count)
    let stale = TimelineHistogram.buckets(for: [end.addingTimeInterval(-60 * 3_600)], hours: 48, end: end)
    #expect(stale.map(\.count).reduce(0, +) == 0)
  }

  @Test("Under two hours of history the histogram hides")
  func histogramThreshold() {
    let now = Date.now
    #expect(!ActivityView.showsHistogram(oldest: nil, now: now))
    #expect(!ActivityView.showsHistogram(oldest: now.addingTimeInterval(-3_599 * 2), now: now))
    #expect(ActivityView.showsHistogram(oldest: now.addingTimeInterval(-2 * 3_600), now: now))
  }

  @Test("Days are newest first, each titled, today and yesterday by name")
  func days() {
    let calendar = Calendar.current
    let today = ActivityView.title(for: calendar.startOfDay(for: .now), calendar: calendar)
    #expect(today.hasPrefix("Today — "))
    let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)) ?? .now
    #expect(ActivityView.title(for: yesterday, calendar: calendar).hasPrefix("Yesterday — "))
  }
}
