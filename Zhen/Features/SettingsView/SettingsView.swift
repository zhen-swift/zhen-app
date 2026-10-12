import SwiftUI
import UniformTypeIdentifiers
import ZhenCore

/// The Settings scene (⌘,): scanning, history, and the privileged engine. Standard macOS
/// settings grammar on purpose — nobody should have to learn this screen.
struct SettingsView: View {
  @Environment(NetworkModel.self) private var model
  @AppStorage(Preferences.Key.scanInterval) private var interval = 0
  @AppStorage(Preferences.Key.subnetOverride) private var subnet = ""
  @AppStorage(Preferences.Key.deepScan) private var deepScan = false
  @AppStorage(Preferences.Key.retentionDays) private var retentionDays = 0
  @AppStorage(Preferences.Key.budgetSeconds) private var budgetSeconds = Preferences.defaultBudgetSeconds
  @State private var exporting: HistoryDocument?

  var body: some View {
    Form {
      Section {
        Picker("Scan automatically", selection: $interval) {
          Text("Off").tag(0)
          Text("Every 5 minutes").tag(5)
          Text("Every 15 minutes").tag(15)
          Text("Every hour").tag(60)
        }
        // A grouped Form draws the label as its own element; without this the control
        // itself is nameless to accessibility — the audit found all four (stage F).
        .accessibilityLabel("Scan automatically")
        .accessibilityIdentifier("scanIntervalPicker")
        SubnetRowView(subnet: $subnet)
        Picker("Scan for up to", selection: $budgetSeconds) {
          ForEach(Preferences.budgets, id: \.self) { seconds in
            Text(Duration.seconds(seconds).formatted(.units(allowed: [.seconds, .minutes], width: .wide))).tag(seconds)
          }
        }
        .accessibilityLabel("Scan for up to")
        .accessibilityIdentifier("scanBudgetPicker")
        // Was "Deep-scan new devices". Core's port stage is one switch per run and probes
        // every host that answered; zhen-core 0.6.0 cannot limit it to new ones, so the
        // label now says what the switch does (ledger, phase 3 stage 1).
        Toggle(isOn: $deepScan) {
          Text("Check ports on every scan")
          Text("Also check common ports on every device that answers. Slower, and more visible on the network.")
        }
        .accessibilityLabel("Check ports on every scan")
        .accessibilityIdentifier("deepScanToggle")
      } header: {
        Text("Scanning").sectionLabel()
      }

      Section {
        Picker("Keep events for", selection: $retentionDays) {
          Text("7 days").tag(7)
          Text("30 days").tag(30)
          Text("90 days").tag(90)
          Text("Forever").tag(0)
        }
        .accessibilityLabel("Keep events for")
        .accessibilityIdentifier("retentionPicker")
        LabeledContent("Device identity history") {
          Text("Kept forever — it’s what makes merges possible")
            .foregroundStyle(.textSecondary)
        }
        LabeledContent("History file") {
          HStack(spacing: .spacing.small) {
            Text(historySize)
              .foregroundStyle(.textSecondary)
              .monospacedDigit()
              .accessibilityIdentifier("historySize")
            if let url = model.historyURL {
              Button("Show in Finder") { Finder.reveal(url) }
                .accessibilityIdentifier("revealHistoryButton")
            }
            Button("Export…") { exporting = model.exportDocument() }
              .help("Save devices and events as JSON")
              .accessibilityIdentifier("exportHistoryButton")
          }
        }
      } header: {
        Text("History").sectionLabel()
      }

      Section {
        HelperPanelView()
      } header: {
        Text("Privileged engine").sectionLabel()
      }
    }
    .formStyle(.grouped)
    // Pinned, per A3: the title and version describe the whole scene.
    .safeAreaInset(edge: .top, spacing: .zero) {
      Text(Self.versionLine)
        .font(.subheadline)
        .foregroundStyle(.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, .spacing.xLarge)
        .padding(.top, .spacing.medium)
        .accessibilityIdentifier("settingsVersion")
    }
    .fileExporter(
      isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }),
      document: exporting, contentType: .json, defaultFilename: NetworkModel.exportFilename
    ) { _ in exporting = nil }
    .frame(width: .windowSize.settingsWidth, height: .windowSize.settingsHeight)
    .defaultAppStorage(model.defaults)
    .task(id: retentionDays) { await model.applyRetention(days: retentionDays) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("settings")
  }
}

extension SettingsView {
  /// "Zhen 1.0 (1)".
  static var versionLine: String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? "?"
    let build = info["CFBundleVersion"] as? String ?? "?"
    return String(localized: "Zhen \(version) (\(build))")
  }

  /// "2.1 MB", or what is true when there is no file.
  var historySize: String {
    guard model.historyURL != nil else { return String(localized: "In memory — this launch uses a fixture") }
    guard let bytes = model.historyFileSize else { return String(localized: "Not created yet — no scan so far") }
    return Int64(bytes).formatted(.byteCount(style: .file))
  }
}

#Preview("Settings — dark") {
  SettingsView()
    .environment(PreviewContainer.model(.home))
    .preferredColorScheme(.dark)
}

#Preview("Settings — light") {
  SettingsView()
    .environment(PreviewContainer.model(.home))
    .preferredColorScheme(.light)
}
