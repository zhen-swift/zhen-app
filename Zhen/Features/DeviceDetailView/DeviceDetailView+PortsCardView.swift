import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// Open ports: from history, which holds the last scan or port probe that checked them.
  /// While a probe of this device runs, the card shows that instead.
  struct PortsCardView: View {
    let item: DeviceItem
    @Environment(NetworkModel.self) private var model

    var body: some View {
      Card(.openPorts, caption: caption) {
        VStack(alignment: .leading, spacing: .spacing.medium) {
          if let session, session.state == .running {
            HStack(spacing: .spacing.small) {
              ProgressView().controlSize(.small)
              Text(.checkingCommonPortsOn(item.address))
                .font(.body)
                .foregroundStyle(.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("portScanProgress")
          } else if case .failed(let reason)? = session?.state {
            Text(reason)
              .font(.body)
              .foregroundStyle(.textSecondary)
              .accessibilityIdentifier("portScanFailure")
          }
          PortList(item: item, ports: ports, isScanning: session?.state == .running)
        }
        .padding(.spacing.large)
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("portsCard")
    }

    private var session: PortScan? { model.portScans[item.id] }

    /// The session's ports once it has some, history's otherwise.
    private var ports: [PortObservation] {
      if let session, !session.ports.isEmpty { return session.ports }
      return item.device.ports
    }

    /// When these ports were checked. History does not stamp ports, so the time is known
    /// only when the latest run checked them and saw this device; otherwise it says so
    /// rather than pass off the last-seen time as a scan time, which it used to.
    private var caption: String? {
      if let session, session.state == .finished {
        return String(localized: .checked(session.at.formatted(.relative(presentation: .numeric))))
      }
      guard !item.device.ports.isEmpty else { return nil }
      if let run = model.latestRun, run.checkedPorts, item.isOnline, let finished = run.finishedAt {
        let date = Date(timeIntervalSince1970: finished.timeIntervalSince1970)
        return String(localized: .checked(date.formatted(.relative(presentation: .numeric))))
      }
      return String(localized: .fromEarlierScanThatCheckedPorts)
    }
  }

  /// What the card says about the ports themselves: none checked yet, none open, or the
  /// open ones with what answered on each.
  struct PortList: View {
    let item: DeviceItem
    let ports: [PortObservation]
    let isScanning: Bool
    @Environment(NetworkModel.self) private var model

    var body: some View {
      if ports.isEmpty {
        if !isScanning {
          HStack {
            Text(.noPortScanYet).font(.body).foregroundStyle(.textSecondary)
            Spacer()
            Button(String(localized: .scanPorts)) { model.scanPorts(item.id) }
              .disabled(item.device.ipv4Addresses.isEmpty || model.isBusy)
              .accessibilityIdentifier("cardScanPortsButton")
          }
        }
      } else if open.isEmpty {
        Text(String(localized: .nonePortsCheckedWasOpen(ports.count)))
          .font(.body)
          .foregroundStyle(.textSecondary)
          .accessibilityIdentifier("noOpenPorts")
      } else {
        Grid(alignment: .leading, horizontalSpacing: .spacing.xxLarge, verticalSpacing: .spacing.small) {
          ForEach(open, id: \.self) { port in
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
      }
    }

    private var open: [PortObservation] { ports.filter { $0.state == .open } }

    private func product(_ port: PortObservation) -> String? {
      guard let service = port.service else { return nil }
      let parts = [service.product, service.version, service.tlsSubject].compactMap(\.self)
      return parts.isEmpty ? service.banner : parts.joined(separator: " ")
    }
  }
}
