import SwiftUI
import ZhenCore

/// A scan as it happens. Replaces the Devices table while it runs and hands back on its
/// own when it finishes; stays, with what it found, when someone stops it.
///
/// The header, the stages and the degradations are pinned; only "found so far" scrolls —
/// the stage strip sliding away as the list grows is exactly when someone most wants it.
struct LiveScanView: View {
  @Environment(NetworkModel.self) var model

  var body: some View {
    let scan = model.scan
    List {
      Section {
        if scan.found.isEmpty {
          Text(scan.isRunning ? "Listening…" : "Nothing answered before the scan stopped.")
            .font(.body)
            .foregroundStyle(.textSecondary)
            .accessibilityIdentifier("liveScanListening")
        } else {
          ForEach(scan.found) { host in
            FoundHostRowView(host: host, namingPending: scan.isNamingPending, known: model.knownDevice(for: host.facts))
          }
        }
      } header: {
        Text("Found so far · newest first").sectionLabel()
          .accessibilityAddTraits(.isHeader)
      }
    }
    .listStyle(.inset)
    .animation(.spring(duration: 0.3), value: scan.found.count)
    .accessibilityLabel("Found so far")
    .accessibilityIdentifier("liveScanList")
    .safeAreaInset(edge: .top, spacing: .zero) {
      VStack(alignment: .leading, spacing: .spacing.large) {
        HeaderView()
        HStack(spacing: .spacing.medium) {
          ForEach(ScanSession.stages, id: \.self) { stage in
            StageCard(
              title: Self.title(of: stage),
              detail: detail(of: stage),
              state: Self.cardState(scan.stageStates[stage] ?? .queued)
            )
            .accessibilityIdentifier("stageCard-\(stage.rawValue)")
          }
        }
        if !scan.degradations.isEmpty {
          DegradationBanner(degradations: scan.degradations) { model.startScan() }
        }
      }
      .padding(.spacing.xLarge)
      .background(.background)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("liveScan")
  }
}

#Preview("Live scan — running, dark") {
  LiveScanView()
    .environment(PreviewContainer.scanning(.partial))
    .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
    .preferredColorScheme(.dark)
}
