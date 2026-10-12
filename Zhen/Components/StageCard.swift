import SwiftUI

/// One stage of a scan: queued, running, done, or not part of this scan.
///
/// The running card carries the accent border, so the eye lands on the stage that is
/// *now* rather than reading four equal cards.
struct StageCard: View {
  enum State: Equatable {
    case queued
    case running(Double?)
    case done
    case skipped
  }

  let title: LocalizedStringKey
  let detail: String
  let state: State

  var body: some View {
    VStack(alignment: .leading, spacing: .spacing.small) {
      HStack(spacing: .spacing.small) {
        StageSymbolView(state: state)
        Text(title)
          .font(.headline)
          .foregroundStyle(isQuiet ? .textSecondary : .textPrimary)
      }
      Text(detail)
        .font(.subheadline)
        .foregroundStyle(.textSecondary)
        .lineLimit(1)
      ProgressTrackView(state: state)
    }
    .padding(.spacing.medium)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.surfaceRaised, in: .rect(cornerRadius: .cornerRadius.large))
    .overlay {
      RoundedRectangle(cornerRadius: .cornerRadius.large)
        .strokeBorder(isRunning ? .accent : .cardBorder, lineWidth: isRunning ? .borderWidth.focus : .borderWidth.hairline)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isStaticText)
    .accessibilityValue(stateDescription)
  }

  private var isRunning: Bool {
    if case .running = state { return true }
    return false
  }

  private var isQuiet: Bool { state == .queued || state == .skipped }

  private var stateDescription: String {
    switch state {
    case .queued: String(localized: "Queued")
    case .running: String(localized: "Running")
    case .done: String(localized: "Done")
    case .skipped: String(localized: "Not part of this scan")
    }
  }
}

extension StageCard {
  /// A circle, a spinner, or a check.
  struct StageSymbolView: View {
    let state: State

    var body: some View {
      switch state {
      case .queued, .skipped:
        Image(systemName: "circle").foregroundStyle(.textTertiary)
      case .running:
        ProgressView().controlSize(.small)
      case .done:
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.statusOnline)
      }
    }
  }

  /// The thin track along the bottom.
  struct ProgressTrackView: View {
    let state: State

    var body: some View {
      switch state {
      case .queued, .skipped:
        ProgressView(value: 0).tint(.accent)
      case .running(let fraction?):
        ProgressView(value: fraction).tint(.accent)
      case .running(nil):
        ProgressView().progressViewStyle(.linear).tint(.accent)
      case .done:
        ProgressView(value: 1).tint(.statusOnline)
      }
    }
  }
}

#Preview("Stage cards — dark") {
  HStack(spacing: .spacing.medium) {
    StageCard(title: "Discovery", detail: "13 hosts answered", state: .done)
    StageCard(title: "Naming", detail: "Asking Bonjour, UPnP, NetBIOS", state: .running(0.4))
    StageCard(title: "Deep scan", detail: "Not requested", state: .skipped)
  }
  .padding(.spacing.xLarge)
  .background(.surface)
  .preferredColorScheme(.dark)
}
