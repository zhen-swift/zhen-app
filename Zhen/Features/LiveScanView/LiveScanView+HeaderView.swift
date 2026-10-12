import SwiftUI
import ZhenCore

extension LiveScanView {
  /// "Scanning 192.168.50.0/24", where it is, and the control that ends it.
  struct HeaderView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      let scan = model.scan
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: .spacing.xSmall) {
          Text(title)
            .font(.title2.bold())
            .foregroundStyle(.textPrimary)
            .accessibilityIdentifier("liveScanTitle")
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(subtitle(at: context.date))
              .font(.subheadline)
              .foregroundStyle(.textSecondary)
              .monospacedDigit()
              .accessibilityIdentifier("liveScanSubtitle")
          }
        }
        Spacer()
        switch scan.phase {
        case .running:
          Button("Stop Scan", systemImage: "stop.fill") { scan.stop() }
            .accessibilityIdentifier("liveStopScanButton")
        case .stopped:
          Button("Show Devices") { scan.dismiss() }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("showDevicesButton")
          PrimaryButton("Scan Again", systemImage: "arrow.clockwise", identifier: "scanAgainButton") {
            scan.dismiss()
            model.scanAgain()
          }
        case .idle:
          EmptyView()
        }
      }
    }

    private var title: String {
      let target = model.scan.request.network ?? model.interface?.network
      return target.map { String(localized: "Scanning \($0.description)") } ?? String(localized: "Scanning")
    }

    private func subtitle(at now: Date) -> String {
      let scan = model.scan
      let elapsed = scan.elapsed(at: scan.finishedAt ?? now)
      let clock = elapsed.formatted(.time(pattern: .minuteSecond))
      switch scan.phase {
      case .stopped(let after, let found):
        return String(localized: "Stopped after \(after.formatted(.time(pattern: .minuteSecond))) · \(found) devices found")
      default:
        let stages = ScanSession.stages.count { scan.stageStates[$0] != .skipped }
        return String(localized: "Stage \(scan.currentStageNumber) of \(stages) · \(clock) elapsed · \(scan.found.count) devices so far")
      }
    }
  }
}
