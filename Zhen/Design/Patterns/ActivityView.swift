// ActivityView.swift — the event log, its histogram, and its filters.

import SwiftUI

/// The activity room.
///
/// **Selecting a chip filters BOTH the list and the histogram.** If the histogram keeps
/// showing all events while the list is filtered, the two stop agreeing and the screen
/// loses its meaning — a person reading a tall bar over an empty list has been told
/// something false.
public struct ActivityView: View {
    private let days: [EventDayModel]
    private let buckets: [HistogramBucket]
    @Binding private var category: EventCategory
    private let windowTitle: String

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - days: events grouped by day, newest first.
    ///   - buckets: the unfiltered hourly buckets. Filtering is applied here so the two
    ///     halves cannot disagree.
    ///   - category: the selected filter chip.
    ///   - windowTitle: "Last 48 hours".
    public init(
        days: [EventDayModel],
        buckets: [HistogramBucket],
        category: Binding<EventCategory> = .constant(.all),
        windowTitle: String = "Last 48 hours"
    ) {
        self.days = days
        self.buckets = buckets
        self._category = category
        self.windowTitle = windowTitle
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.separator)
            content
        }
        .background(Palette.surface)
    }

    private var header: some View {
        ScreenHeader("Activity", subtitle: "\(windowTitle) · \(totalEvents) events") {
            HStack(spacing: Metrics.unit * 2) {
                ForEach(EventCategory.allCases) { option in
                    FilterChip(option.label, isSelected: category == option) {
                        category = option
                    }
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if allEvents.isEmpty {
            // Scrolls, with nothing to scroll. See `ScreenScroll`: an empty room that
            // is not a scroll view loses the window's top and bottom bars, and the whole
            // app appears to jump when you move into it.
            ScreenScroll { EmptyStateView.nothingHasChanged }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if filteredDays.isEmpty {
                        EmptyStateView.noEventsOfKind(category.label)
                    } else {
                        ForEach(filteredDays) { day in
                            SectionLabel(day.title)
                                .padding(.horizontal, Metrics.contentInset)
                                .padding(.top, Metrics.unit * 5)
                                .padding(.bottom, Metrics.unit * 2)
                            ForEach(day.events) { EventRow($0) }
                        }
                    }
                }
                // One resolver over the whole day-grouped list, so a time or kind
                // column is the same width on Tuesday as it is on Monday. Per day
                // would let two groups disagree down the same screen.
                .resolvesColumns()
            }
            // Pinned for the same reason as the live scan's stage strip: the histogram
            // describes the whole window the list below it is filtered to, and the two
            // are required to agree. A rhythm strip that scrolls out of view while the
            // list it summarises stays put is a summary of something you can no longer
            // see.
            //
            // Fewer than two hours of history hides it rather than drawing three lonely
            // bars; the list then stands alone with no empty band above it.
            .safeAreaInset(edge: .top, spacing: 0) {
                if buckets.count >= 2 {
                    VStack(spacing: 0) {
                        TimelineHistogram(filteredBuckets)
                            .padding(.horizontal, Metrics.contentInset)
                            .padding(.vertical, Metrics.unit * 3)
                        Divider().overlay(Palette.separator)
                    }
                    .background(Palette.surface)
                }
            }
        }
    }

    private var allEvents: [EventModel] { days.flatMap(\.events) }
    private var totalEvents: Int { allEvents.count }

    private var filteredDays: [EventDayModel] {
        days.compactMap { day in
            let events = day.events.filter { category.matches($0.kind) }
            return events.isEmpty ? nil : EventDayModel(title: day.title, events: events)
        }
    }

    /// The histogram, filtered by the same chip as the list.
    ///
    /// The fixture buckets carry only counts, so filtering scales them by the proportion
    /// of matching events. With a real store this becomes a re-bucket of the filtered
    /// set; the contract that matters — the two halves always agree — is the same.
    private var filteredBuckets: [HistogramBucket] {
        guard category != .all else { return buckets }
        let matching = allEvents.filter { category.matches($0.kind) }.count
        let proportion = totalEvents > 0 ? Double(matching) / Double(totalEvents) : 0
        return buckets.map {
            HistogramBucket(hour: $0.hour,
                            count: Int((Double($0.count) * proportion).rounded()),
                            label: $0.label)
        }
    }
}

/// A filter chip. Larger and interactive, unlike the static ``Chip``.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let select: () -> Void

    init(_ title: String, isSelected: Bool, select: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.select = select
    }

    var body: some View {
        Button(action: select) {
            Text(title)
                .font(isSelected ? .filterChipSelected : .filterChip)
                .foregroundStyle(isSelected ? Palette.onAccent : Palette.textSecondary)
                .padding(.horizontal, Metrics.unit * 3)
                .padding(.vertical, Metrics.unit + 2)
                .background(
                    Capsule().fill(isSelected ? Palette.accent : Palette.surfaceField)
                )
        }
        .buttonStyle(.plain)
        .zhenFocusRing(.capsule)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Activity — dark") {
    ActivityView(days: EventDayModel.sampleDays, buckets: HistogramBucket.sampleWindow)
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("Activity — light") {
    ActivityView(days: EventDayModel.sampleDays, buckets: HistogramBucket.sampleWindow)
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Activity — filtered to ports") {
    ActivityView(days: EventDayModel.sampleDays, buckets: HistogramBucket.sampleWindow,
                 category: .constant(.ports))
        .frame(width: 1182, height: 620)
        .preferredColorScheme(.dark)
}

#Preview("Activity — no events") {
    ActivityView(days: [], buckets: [])
        .frame(width: 1182, height: 520)
        .preferredColorScheme(.dark)
}
