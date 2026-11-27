import SwiftUI
import ZhenCore

extension RootView {
  /// Which network's history the window shows: the one this Mac is on, or another it has
  /// scanned before. Only there when there is another (calm by default).
  ///
  /// Another network is read only. Its devices are not here to answer, so a port scan is
  /// off, and Scan Now comes back to this network before it scans.
  struct NetworkPickerView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.xxSmall) {
        Picker(String(localized: .network), selection: selection) {
          ForEach(model.networks) { network in
            Text(verbatim: Self.title(of: network))
              .tag(network.id)
              .accessibilityIdentifier(network.accessibilityIdentifier)
          }
        }
        .pickerStyle(.menu)
        .disabled(model.isBusy)
        .accessibilityLabel(String(localized: .network))
        .accessibilityIdentifier("networkPicker")
        if !model.isViewingCurrentNetwork {
          Text(.networkReadOnly)
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("networkReadOnly")
        }
      }
      .padding(.horizontal, .spacing.medium)
      .padding(.bottom, .spacing.small)
    }

    private var selection: Binding<URL?> {
      Binding(
        get: { model.historyURL },
        set: { url in
          guard let network = model.networks.first(where: { $0.id == url }) else { return }
          Task { await model.show(network) }
        }
      )
    }

    /// "This network · 10.10.30.0/24", "192.168.1.0/24 · Fritz!Box · 3 days ago".
    static func title(of network: NetworkChoice) -> String {
      var parts: [String] = []
      if network.isCurrent { parts.append(String(localized: .thisNetwork)) }
      parts.append(network.identity.subnet.description)
      if let router = network.router { parts.append(router) }
      if !network.isCurrent, let lastScan = network.lastScan {
        parts.append(lastScan.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
      }
      return parts.joined(separator: " · ")
    }
  }
}
