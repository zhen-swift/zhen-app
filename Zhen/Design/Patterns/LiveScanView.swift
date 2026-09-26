// LiveScanView.swift — what replaces the device list while a scan runs.

import SwiftUI

/// How a live scan is going.
public enum LiveScanState: Sendable, Hashable {
    /// Armed, nothing has answered yet.
    case starting
    /// Running, with what has been found so far.
    case running(findings: [ScanFindingModel])
    /// The user pressed Stop.
    ///
    /// **Nothing is discarded because someone pressed stop.** The partial results stay
    /// on screen with a Scan Again button.
    case stopped(findings: [ScanFindingModel], elapsed: String)
}

/// The live scan screen: stage strip, degradations, and hosts as they answer.
public struct LiveScanView: View {
    private let target: String
    private let elapsed: String
    private let stages: [StageModel]
    private let degradations: [DegradationModel]
    private let state: LiveScanState
    private let onStop: () -> Void

    /// Creates the screen.
    public init(
        target: String,
        elapsed: String,
        stages: [StageModel],
        degradations: [DegradationModel],
        state: LiveScanState,
        onStop: @escaping () -> Void = {}
    ) {
        self.target = target
        self.elapsed = elapsed
        self.stages = stages
        self.degradations = degradations
        self.state = state
        self.onStop = onStop
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Palette.separator)
            ScrollView {
                foundCard
                    .padding(Metrics.contentInset)
            }
            // ── Pinned, not scrolled ────────────────────────────────────────────
            //
            // The stage strip and the degradations describe the WHOLE SCREEN, and the
            // list beneath them grows as hosts answer. Inside the scroll view they slid
            // away exactly when there was enough content to scroll — which is exactly
            // when a person most wants to know which stage is running and what has
            // already gone wrong. `safeAreaInset` keeps them fixed without nesting
            // scroll views inside each other.
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: Metrics.unit * 4) {
                    HStack(spacing: Metrics.unit * 3) {
                        ForEach(stages) { StageCard($0) }
                    }
                    DegradationBanner(degradations)
                }
                .padding(.horizontal, Metrics.contentInset)
                .padding(.top, Metrics.contentInset)
                .padding(.bottom, Metrics.unit * 3)
                .background(Palette.surface)
            }
        }
        .background(Palette.surface)
    }

    private var header: some View {
        ScreenHeader(
            isStopped ? "Scan stopped" : "Scanning \(target)", subtitle: subtitle
        ) {
            if isStopped {
                PrimaryButton("Scan Again")
            } else {
                SecondaryButton("Stop Scan", action: onStop)
            }
        }
    }

    private var subtitle: String {
        let done = stages.filter(\.state.isDone).count
        switch state {
        case .starting:
            return "Stage 1 of \(stages.count) · \(elapsed) elapsed · listening…"
        case .running(let findings):
            return "Stage \(min(done + 1, stages.count)) of \(stages.count) · \(elapsed) elapsed · "
                + "\(findings.count) devices so far"
        case .stopped(let findings, let elapsed):
            return "Stopped after \(elapsed) · \(findings.count) devices found"
        }
    }

    private var isStopped: Bool { if case .stopped = state { true } else { false } }

    private var findings: [ScanFindingModel] {
        switch state {
        case .starting: []
        case .running(let f): f
        case .stopped(let f, _): f
        }
    }

    @ViewBuilder private var foundCard: some View {
        Card(title: "Found so far", caption: "newest first") {
            if findings.isEmpty {
                Text("Listening…")
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Metrics.cardPadding)
            } else {
                CardRows(findings) { FindingRow($0) }
                    // The found-so-far list is a table and sizes like one.
                    .resolvesColumns()
            }
        }
    }
}

/// One host arriving mid-scan.
struct FindingRow: View {
    let finding: ScanFindingModel

    init(_ finding: ScanFindingModel) { self.finding = finding }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 3) {
            StatusDot(.online).alignmentGuide(.firstTextBaseline) { $0[.bottom] }

            VStack(alignment: .leading, spacing: Metrics.unit / 2) {
                // The italic placeholder is worth the effort. It is the difference
                // between a scanner that looks like it is thinking and one that looks
                // stuck — and it says WHICH source is still in flight, so the wait is
                // explained rather than merely endured.
                if let name = finding.name {
                    Text(name)
                        .font(.rowTitle)
                        .foregroundStyle(Palette.textPrimary)
                } else {
                    Text("Resolving name…")
                        .font(.rowTitle)
                        .italic()
                        .foregroundStyle(Palette.textSecondary)
                }
                Text(finding.detail)
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(finding.ip)
                .font(.mono)
                .foregroundStyle(Palette.textPrimary)
                .measuredColumn(.findingIP)
            Text(finding.mac ?? "—")
                .font(.mono)
                .foregroundStyle(Palette.textSecondary)
                .measuredColumn(.findingMAC)
            Text(finding.note)
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
                .measuredColumn(.findingNote)
        }
        .padding(Metrics.cardPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(finding.name ?? "Resolving name"), \(finding.detail), at \(finding.ip)"
        )
    }
}

#Preview("Live scan — dark") {
    LiveScanView(target: "10.10.20.0/24", elapsed: "0:03",
                 stages: StageModel.sampleStages,
                 degradations: DegradationModel.sampleDegradations,
                 state: .running(findings: ScanFindingModel.sampleFindings))
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.dark)
}

#Preview("Live scan — light") {
    LiveScanView(target: "10.10.20.0/24", elapsed: "0:03",
                 stages: StageModel.sampleStages,
                 degradations: DegradationModel.sampleDegradations,
                 state: .running(findings: ScanFindingModel.sampleFindings))
        .frame(width: 1182, height: 760)
        .preferredColorScheme(.light)
}

#Preview("Live scan — starting") {
    LiveScanView(target: "10.10.20.0/24", elapsed: "0:00",
                 stages: [StageModel(stage: .discovery, state: .running(nil), detail: "ARP + ping sweep"),
                          .init(stage: .naming, state: .queued, detail: "Bonjour + UPnP + NetBIOS · queued"),
                          .deepScanQueued],
                 degradations: [],
                 state: .starting)
        .frame(width: 1182, height: 620)
        .preferredColorScheme(.dark)
}

#Preview("Live scan — stopped") {
    LiveScanView(target: "10.10.20.0/24", elapsed: "0:03",
                 stages: StageModel.sampleStages, degradations: [],
                 state: .stopped(findings: ScanFindingModel.sampleFindings, elapsed: "0:03"))
        .frame(width: 1182, height: 620)
        .preferredColorScheme(.dark)
}
