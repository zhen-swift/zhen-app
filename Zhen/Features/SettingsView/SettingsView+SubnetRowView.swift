import SwiftUI
import ZhenCore

extension SettingsView {
  /// The network to scan: the interface's own by default, or one typed here.
  struct SubnetRowView: View {
    @Binding var subnet: String
    @Environment(NetworkModel.self) private var model

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.xSmall) {
        LabeledContent(String(localized: .subnet)) {
          Text(automatic).font(.callout.monospaced()).foregroundStyle(.textSecondary)
        }
        LabeledContent(String(localized: .override)) {
          // The monospaced face is for the address, not the label beside it.
          TextField(String(localized: .override), text: $subnet, prompt: Text(.subnetExample))
            .labelsHidden()
            .font(.callout.monospaced())
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(String(localized: .subnetOverride))
            .accessibilityIdentifier("subnetOverrideField")
        }
        if !subnet.isEmpty, Preferences.network(subnet) == nil {
          Text(.notNetworkZhenCanScanUse)
            .font(.subheadline)
            .foregroundStyle(.statusWarningText)
            .accessibilityIdentifier("subnetOverrideError")
        }
      }
    }

    private var automatic: String {
      guard let interface = model.interface else { return String(localized: .auto) }
      return String(localized: .autoFrom(interface.network.description, interface.name))
    }
  }
}
