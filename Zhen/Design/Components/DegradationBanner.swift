// DegradationBanner.swift — the most important component in the app.
//
// Three rules, all of them about writing rather than layout:
//
//   1. **Say the consequence, not the error.** "Bonjour names can't be read this scan"
//      is useful. "mDNS: EPERM" is not.
//   2. **Hedge what was inferred.** The Local Network grant cannot be queried; denial is
//      deduced from finding nothing by ICMP while the neighbour table is populated. So
//      the copy says "appears to be denied". The artboards say "was denied", which
//      claims a certainty we do not have — and a tool that quietly overstates one thing
//      has its other claims doubted.
//   3. **Never a modal.** These arrive mid-scan and the scan is still useful. An alert
//      would interrupt the thing the user is watching to tell them it is going slightly
//      worse than planned.
//
// Amber, not red. Nothing here is broken.

import SwiftUI

/// The card listing everything that did not work, with what it costs.
public struct DegradationBanner: View {
    private let degradations: [DegradationModel]
    private let onAction: (DegradationModel) -> Void

    /// Creates a banner.
    ///
    /// - Parameters:
    ///   - degradations: what went wrong. An empty array renders nothing.
    ///   - onAction: invoked when a row's remedy link is pressed.
    public init(
        _ degradations: [DegradationModel],
        onAction: @escaping (DegradationModel) -> Void = { _ in }
    ) {
        self.degradations = degradations
        self.onAction = onAction
    }

    public var body: some View {
        if !degradations.isEmpty {
            Card {
                VStack(spacing: 0) {
                    header
                    Divider().overlay(Palette.separator)
                    CardRows(degradations) { row($0) }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 2) {
            Circle()
                .fill(Palette.Status.warning)
                // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
                // something — so it carries a size and scales with the type scale rather than
                // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
                // size that stay.
                .frame(width: Metrics.dotSize, height: Metrics.dotSize)
                .accessibilityHidden(true)
            Text("Running with partial results")
                .font(.rowTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("· results are still valid, just less complete")
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(Metrics.cardPadding)
    }

    private func causeText(_ degradation: DegradationModel) -> Text {
        Text(degradation.cause).font(.controlEmphasis).foregroundStyle(Palette.textPrimary)
    }

    private var dashText: Text {
        Text("—").font(.control).foregroundStyle(Palette.textSecondary)
    }

    private func consequenceText(_ degradation: DegradationModel) -> Text {
        Text(degradation.consequence).font(.control).foregroundStyle(Palette.textSecondary)
    }

    private func row(_ degradation: DegradationModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 3) {
            // Cause bold, consequence plain, in one text run so it wraps as a sentence
            // rather than as two columns that drift apart at a large type size.
            Text("\(causeText(degradation)) \(dashText) \(consequenceText(degradation))")
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Metrics.unit * 2)
            if let actionTitle = degradation.actionTitle {
                LinkButton(actionTitle) { onAction(degradation) }
            }
        }
        .padding(Metrics.cardPadding)
        .accessibilityElement(children: .contain)
    }
}

/// The one-line strip that carries a finished run's degradations into the device list.
///
/// **The artboards have no state for this and they need one.** Degradations do not
/// evaporate when the scan ends: a green dot over an incomplete scan is a lie of
/// omission. This sits under the Devices header and opens the same rows the live scan
/// showed.
public struct PartialRunStrip: View {
    private let unavailableSources: Int
    private let degradations: [DegradationModel]
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the strip.
    public init(unavailableSources: Int, degradations: [DegradationModel]) {
        self.unavailableSources = unavailableSources
        self.degradations = degradations
    }

    public var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(Motion.honouring(Motion.disclosure, reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Metrics.unit * 2) {
                    Circle()
                        .fill(Palette.Status.warning)
                        // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
                        // something — so it carries a size and scales with the type scale rather than
                        // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
                        // size that stay.
                        .frame(width: Metrics.dotSize, height: Metrics.dotSize)
                        .accessibilityHidden(true)
                    Text("Last scan completed with partial results — \(unavailableSources) "
                         + (unavailableSources == 1 ? "source" : "sources") + " unavailable")
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 0)
                    Image(systemName: Symbols.disclosure)
                        .imageScale(.small)
                        .foregroundStyle(Palette.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Metrics.contentInset)
                .padding(.vertical, Metrics.unit * 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .zhenFocusRing(.rounded(Metrics.chipRadius))
            .accessibilityLabel("Last scan completed with partial results, \(unavailableSources) sources unavailable")
            .accessibilityHint(isExpanded ? "Collapses the details" : "Expands the details")

            if isExpanded {
                DegradationBanner(degradations)
                    .padding(.horizontal, Metrics.contentInset)
                    .padding(.bottom, Metrics.unit * 3)
            }
        }
        .background(Palette.Status.warning.opacity(0.08))
    }
}

#Preview("DegradationBanner — dark") {
    DegradationBanner(DegradationModel.sampleDegradations)
        .padding()
        .frame(width: 900)
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("DegradationBanner — light") {
    DegradationBanner(DegradationModel.sampleDegradations)
        .padding()
        .frame(width: 900)
        .background(Palette.surface)
        .preferredColorScheme(.light)
}

#Preview("PartialRunStrip — dark") {
    PartialRunStrip(unavailableSources: 2, degradations: DegradationModel.sampleDegradations)
        .frame(width: 900)
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}
