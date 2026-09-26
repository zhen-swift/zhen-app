// StageCard.swift — the three-across strip on the live scan screen.

import SwiftUI

/// One stage of a scan, with its progress track.
///
/// The running card carries a 1pt accent border, and that border is the difference
/// between three cards and one card that is clearly *now*.
public struct StageCard: View {
    private let model: StageModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a stage card.
    public init(_ model: StageModel) { self.model = model }

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.unit + 2) {
            HStack(spacing: Metrics.unit * 2) {
                Image(systemName: symbol)
                    .imageScale(.medium)
                    .foregroundStyle(symbolColour)
                    .accessibilityHidden(true)
                Text(model.stage.title)
                    .font(.rowTitle)
                    .foregroundStyle(model.state.isQueued ? Palette.textSecondary : Palette.textPrimary)
                Spacer(minLength: 0)
            }
            Text(model.detail)
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            ProgressTrack(state: model.state)
        }
        .padding(Metrics.unit * 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardRadius).fill(Palette.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .strokeBorder(
                    model.state.isRunning ? Palette.accent : Palette.separator,
                    lineWidth: Metrics.hairline
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.stage.title), \(stateWord). \(model.detail)")
    }

    private var symbol: String {
        switch model.state {
        case .queued: Symbols.queued
        case .running: Symbols.rescan
        case .done: Symbols.done
        }
    }

    private var symbolColour: PaletteColor {
        switch model.state {
        case .queued: Palette.textSecondary
        case .running: Palette.accent
        case .done: Palette.Status.online
        }
    }

    private var stateWord: String {
        switch model.state {
        case .queued: "queued"
        case .running: "running"
        case .done: "done"
        }
    }
}

/// The 3pt bar pinned to the bottom of a stage card.
///
/// An indeterminate running state is a partially filled track rather than a sliding
/// barber pole. The stage it represents — a Bonjour browse — genuinely cannot say how
/// much is left, and a bar that animates as though it knows is a small lie about
/// progress.
public struct ProgressTrack: View {
    private let state: StageState

    /// Creates a track.
    public init(state: StageState) { self.state = state }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.separator)
                Capsule()
                    .fill(fillColour)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        // A GLYPH. It has no content to size to — it is a drawn mark, not a box around
        // something — so it carries a size and scales with the type scale rather than
        // with a container. `RESPONSIVE-plan.md` names this as one of the two kinds of
        // size that stay.
        .frame(height: Metrics.progressTrackHeight)
        .accessibilityHidden(true)
    }

    private var fraction: CGFloat {
        switch state {
        case .queued: 0
        case .running(let value): CGFloat(value ?? 0.45)
        case .done: 1
        }
    }

    private var fillColour: PaletteColor {
        switch state {
        case .queued: PaletteColor.clear
        case .running: Palette.accent
        case .done: Palette.Status.online
        }
    }
}

#Preview("StageCard — dark") {
    HStack(spacing: 12) {
        ForEach(StageModel.sampleStages) { StageCard($0) }
    }
    .padding()
    .frame(width: 900)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("StageCard — light") {
    HStack(spacing: 12) {
        ForEach(StageModel.sampleStages) { StageCard($0) }
    }
    .padding()
    .frame(width: 900)
    .background(Palette.surface)
    .preferredColorScheme(.light)
}
