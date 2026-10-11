import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Open ports from the last deep scan that reached this device.
  struct PortsCardView: View {
    let item: DeviceItem
    @Environment(NetworkModel.self) private var model

    var body: some View {
      Card("Open ports", caption: caption) {
        if item.device.ports.isEmpty {
          HStack {
            Text("No port scan yet").font(.body).foregroundStyle(.textSecondary)
            Spacer()
            Button("Scan Ports") {
              if let address = item.device.ipv4Addresses.first {
                model.startScan(deepScan: true, network: IPv4Network(base: address, prefix: 32))
              }
            }
            .disabled(item.device.ipv4Addresses.isEmpty || model.scan.isRunning)
            .accessibilityIdentifier("cardScanPortsButton")
          }
          .padding(.spacing.large)
        } else if item.device.openPorts.isEmpty {
          Text(String(localized: "None of the \(item.device.ports.count) ports checked was open."))
            .font(.body)
            .foregroundStyle(.textSecondary)
            .padding(.spacing.large)
        } else {
          Grid(alignment: .leading, horizontalSpacing: .spacing.xxLarge, verticalSpacing: .spacing.small) {
            ForEach(item.device.openPorts, id: \.self) { port in
              GridRow {
                Text(verbatim: "\(String(port.port))/\(port.proto.rawValue)")
                  .font(.callout.monospaced())
                  .foregroundStyle(.textPrimary)
                Text(port.service?.name ?? "—")
                  .font(.body)
                  .foregroundStyle(.textPrimary)
                Text(product(port) ?? "—")
                  .font(.subheadline)
                  .foregroundStyle(.textSecondary)
              }
            }
          }
          .padding(.spacing.large)
        }
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("portsCard")
    }

    private var caption: String? {
      guard !item.device.ports.isEmpty else { return nil }
      return String(localized: "last deep scan \(item.lastSeen.formatted(.relative(presentation: .numeric)))")
    }

    private func product(_ port: PortObservation) -> String? {
      guard let service = port.service else { return nil }
      let parts = [service.product, service.version, service.tlsSubject].compactMap(\.self)
      return parts.isEmpty ? service.banner : parts.joined(separator: " ")
    }
  }
}
