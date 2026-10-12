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
        Picker(String(localized: .scanAutomatically), selection: $interval) {
          Text(.off).tag(0)
          Text(.every5Minutes).tag(5)
          Text(.every15Minutes).tag(15)
          Text(.everyHour).tag(60)
        }
        // A grouped Form draws the label as its own element; without this the control
        // itself is nameless to accessibility — the audit found all four (stage F).
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: .scanAutomatically))
        .accessibilityIdentifier("scanIntervalPicker")
        SubnetRowView(subnet: $subnet)
        Picker(String(localized: .scanUp), selection: $budgetSeconds) {
          ForEach(Preferences.budgets, id: \.self) { seconds in
            Text(Duration.seconds(seconds).formatted(.units(allowed: [.seconds, .minutes], width: .wide))).tag(seconds)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: .scanUp))
        .accessibilityIdentifier("scanBudgetPicker")
        // Was "Deep-scan new devices". Core's port stage is one switch per run and probes
        // every host that answered; zhen-core 0.6.0 cannot limit it to new ones, so the
        // label now says what the switch does (ledger, phase 3 stage 1).
        Toggle(isOn: $deepScan) {
          Text(.checkPortsEveryScan)
          Text(.alsoCheckCommonPortsEveryDevice)
        }
        .accessibilityLabel(String(localized: .checkPortsEveryScan))
        .accessibilityIdentifier("deepScanToggle")
      } header: {
        Text(.scanning).sectionLabel()
      }

      Section {
        Picker(String(localized: .keepEvents), selection: $retentionDays) {
          Text(.n7Days).tag(7)
          Text(.n30Days).tag(30)
          Text(.n90Days).tag(90)
          Text(.forever).tag(0)
        }
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: .keepEvents))
        .accessibilityIdentifier("retentionPicker")
        LabeledContent(String(localized: .deviceIdentityHistory)) {
          Text(.keptForeverWhatMakesMergesPossible)
            .foregroundStyle(.textSecondary)
        }
        LabeledContent(String(localized: .historyFile)) {
          HStack(spacing: .spacing.small) {
            Text(historySize)
              .foregroundStyle(.textSecondary)
              .monospacedDigit()
              .accessibilityIdentifier("historySize")
            if let url = model.historyURL {
              Button(String(localized: .showFinder)) { Finder.reveal(url) }
                .accessibilityIdentifier("revealHistoryButton")
            }
            Button(String(localized: .export)) { exporting = model.exportDocument() }
              .help(String(localized: .saveDevicesEventsJson))
              .accessibilityIdentifier("exportHistoryButton")
          }
        }
      } header: {
        Text(.history).sectionLabel()
      }

      Section {
        HelperPanelView()
      } header: {
        Text(.privilegedEngine).sectionLabel()
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
    .task(id: retentionDays) { await model.applyRetention(days: retentionDays) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(String(localized: .settings))
    .accessibilityIdentifier("settings")
  }
}

extension SettingsView {
  /// "Zhen 1.0 (1)".
  static var versionLine: String {
    let info = Bundle.main.infoDictionary ?? [:]
    let version = info["CFBundleShortVersionString"] as? String ?? "?"
    let build = info["CFBundleVersion"] as? String ?? "?"
    return String(localized: .versionLine(version, build))
  }

  /// "2.1 MB", or what is true when there is no file.
  var historySize: String {
    guard model.historyURL != nil else { return String(localized: .memoryThisLaunchUsesFixture) }
    guard let bytes = model.historyFileSize else { return String(localized: .notCreatedYetNoScanSo) }
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
