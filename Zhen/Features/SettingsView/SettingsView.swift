import SwiftUI
import ZhenCore

/// The Settings scene (⌘,): scanning, history, and the privileged engine. Standard macOS
/// settings grammar on purpose — nobody should have to learn this screen.
struct SettingsView: View {
  @Environment(NetworkModel.self) private var model
  @AppStorage(Preferences.Key.scanInterval) private var interval = 0
  @AppStorage(Preferences.Key.subnetOverride) private var subnet = ""
  @AppStorage(Preferences.Key.deepScan) private var deepScan = false
  @AppStorage(Preferences.Key.retentionDays) private var retentionDays = 0

  var body: some View {
    Form {
      Section {
        Picker("Scan automatically", selection: $interval) {
          Text("Off").tag(0)
          Text("Every 5 minutes").tag(5)
          Text("Every 15 minutes").tag(15)
          Text("Every hour").tag(60)
        }
        .accessibilityIdentifier("scanIntervalPicker")
        SubnetRowView(subnet: $subnet)
        Toggle(isOn: $deepScan) {
          Text("Deep-scan new devices")
          Text("Also check common ports on every device that answers. Slower, and more visible on the network.")
        }
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
        .accessibilityIdentifier("retentionPicker")
        LabeledContent("Device identity history") {
          Text("Kept forever — it’s what makes merges possible")
            .foregroundStyle(.textSecondary)
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
    .frame(width: .windowSize.settingsWidth, height: .windowSize.settingsHeight)
    .defaultAppStorage(model.defaults)
    .task(id: retentionDays) { await model.applyRetention(days: retentionDays) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("settings")
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
