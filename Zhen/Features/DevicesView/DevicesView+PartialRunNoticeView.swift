import SwiftUI
import ZhenCore

extension DevicesView {
  /// The partial-run state the artboards never drew: one line under the header that says
  /// the last scan is less than complete, opening onto the same rows the live scan showed.
  ///
  /// Pinned, not scrolled: it describes the whole list.
  struct PartialRunNoticeView: View {
    @Environment(NetworkModel.self) private var model
    @State private var isExpanded = false

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.small) {
        HStack(spacing: .spacing.small) {
          StatusDot(.warning)
          Text(title)
            .font(.subheadline)
            .foregroundStyle(.textPrimary)
            .accessibilityIdentifier("partialRunTitle")
          Spacer()
          if !model.lastDegradations.isEmpty {
            Button(isExpanded ? "Hide Details" : "Show Details") {
              withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() }
            }
            .buttonStyle(.link)
            .accessibilityIdentifier("partialRunDisclosure")
          }
        }
        if isExpanded {
          DegradationBanner(degradations: model.lastDegradations) {
            model.startScan()
          }
        }
      }
      .padding(.horizontal, .spacing.xLarge)
      .padding(.vertical, .spacing.small)
      // Opaque: on the translucent bar the title measured under 4.5:1 wherever the rows
      // beneath it showed through (phase 3, system audit).
      .background(.surfaceRaised)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("partialRunNotice")
    }

    private var title: String {
      let problems = model.lastDegradations.count
      switch model.latestRun?.outcome {
      case .deadlineExpired?:
        return String(localized: "Last scan ran out of time — results are partial")
      case .cancelled?:
        return String(localized: "Last scan was stopped — results are partial")
      default:
        // Plural from the catalogue.
        return String(localized: "Last scan completed with partial results — \(problems) sources unavailable")
      }
    }
  }
}
