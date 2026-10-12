import SwiftUI
import ZhenCore

extension SettingsView {
  /// The network to scan: the interface's own by default, or one typed here.
  struct SubnetRowView: View {
    @Binding var subnet: String
    @Environment(NetworkModel.self) private var model

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.xSmall) {
        LabeledContent("Subnet") {
          Text(automatic).font(.callout.monospaced()).foregroundStyle(.textSecondary)
        }
        TextField("Override", text: $subnet, prompt: Text("e.g. 192.168.1.0/24"))
          .font(.callout.monospaced())
          .accessibilityLabel("Subnet override")
          .accessibilityIdentifier("subnetOverrideField")
        if !subnet.isEmpty, Preferences.network(subnet) == nil {
          Text("Not a network Zhen can scan. Use CIDR form, /16 or narrower. Until then, scans use the automatic network.")
            .font(.subheadline)
            .foregroundStyle(.statusWarningText)
            .accessibilityIdentifier("subnetOverrideError")
        }
      }
    }

    private var automatic: String {
      guard let interface = model.interface else { return String(localized: "auto") }
      return String(localized: "\(interface.network.description) — auto, from \(interface.name)")
    }
  }
}
