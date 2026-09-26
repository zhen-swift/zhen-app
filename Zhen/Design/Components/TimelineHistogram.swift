// TimelineHistogram.swift — the hourly rhythm strip above the activity list.

import SwiftUI

/// Hourly buckets over the visible window.
///
/// **No axis, deliberately.** The bars are a rhythm, not a measurement — they show when
/// the network is busy, not how busy. An axis invites reading a precision that is not
/// there, and the count is available on hover for anyone who genuinely wants it.
public struct TimelineHistogram: View {
    private let buckets: [HistogramBucket]

    /// Creates a histogram.
    public init(_ buckets: [HistogramBucket]) { self.buckets = buckets }

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.unit * 2) {
            HStack(alignment: .bottom, spacing: Metrics.unit - 1) {
                ForEach(buckets) { bucket in
                    RoundedRectangle(cornerRadius: Metrics.Histogram.barRadius)
                        .fill(Palette.accent.opacity(bucket.count == peak && peak > 0 ? 1 : 0.6))
                        // A GLYPH, and the one whose height IS the data: a bar's height
                        // is the bucket's count scaled to the track. There is no content
                        // inside it to size to.
                        .frame(height: height(bucket))
                        .frame(maxWidth: .infinity)
                        .help(bucket.count == 1 ? "1 event" : "\(bucket.count) events")
                }
            }
            // The track the bars are drawn in. A GLYPH for the same reason: it is the
            // canvas the data is plotted on, and a histogram that grew with the window
            // would change what the bars mean rather than how they look.
            .frame(height: Metrics.Histogram.height, alignment: .bottom)

            HStack(spacing: Metrics.unit - 1) {
                ForEach(buckets) { bucket in
                    Group {
                        if let label = bucket.label {
                            Text(label)
                                .font(.columnHeader)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize()
                        } else {
                            // A HAIRLINE spacer holding the row's baseline where a
                            // bucket has no label, so the labelled and unlabelled slots
                            // do not sit at different heights. One point because that is
                            // what a hairline is.
                            Color.clear.frame(height: 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        // One element with a summary. Forty-eight bars is forty-eight swipes, and none
        // of them mean anything individually.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Event timeline")
        .accessibilityValue("\(total) events over \(buckets.count) hours, busiest hour \(peak)")
    }

    private var peak: Int { buckets.map(\.count).max() ?? 0 }
    private var total: Int { buckets.reduce(0) { $0 + $1.count } }

    /// A floor of 2pt so an empty hour is a visible gap in the rhythm rather than a
    /// hole in the strip.
    private func height(_ bucket: HistogramBucket) -> CGFloat {
        guard peak > 0 else { return Metrics.Histogram.minimumBarHeight }
        return max(Metrics.Histogram.minimumBarHeight,
                   CGFloat(bucket.count) / CGFloat(peak) * Metrics.Histogram.height)
    }
}

#Preview("TimelineHistogram — dark") {
    TimelineHistogram(HistogramBucket.sampleWindow)
        .padding()
        .frame(width: 1000)
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("TimelineHistogram — light") {
    TimelineHistogram(HistogramBucket.sampleWindow)
        .padding()
        .frame(width: 1000)
        .background(Palette.surface)
        .preferredColorScheme(.light)
}
