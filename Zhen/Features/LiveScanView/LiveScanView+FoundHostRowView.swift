import SwiftUI
import ZhenCore

extension LiveScanView {
  /// A host as it answers. Until naming has had its turn, the name slot says so in italic —
  /// the difference between a scanner that looks like it is thinking and one that looks
  /// stuck.
  struct FoundHostRowView: View {
    let host: ScanSession.FoundHost
    let namingPending: Bool
    /// The device history already has for this host, if any.
    let known: DeviceItem?

    var body: some View {
      HStack(spacing: .spacing.medium) {
        StatusDot(.online)
        VStack(alignment: .leading, spacing: .spacing.xxSmall) {
          if let name = host.facts.displayName {
            Text(name).font(.body).foregroundStyle(.textPrimary)
          } else if namingPending {
            Text("Resolving name…").font(.body).italic().foregroundStyle(.textSecondary)
          } else {
            Text("Unidentified device").font(.body).foregroundStyle(.textPrimary)
          }
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(detail(at: context.date))
              .font(.subheadline)
              .foregroundStyle(.textSecondary)
              .monospacedDigit()
          }
        }
        Spacer()
        Text(host.facts.ip.description)
          .font(.callout.monospaced())
          .foregroundStyle(.textPrimary)
      }
      .padding(.vertical, .spacing.xSmall)
      .transition(.move(edge: .top).combined(with: .opacity))
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("foundHost-\(host.facts.ip)")
    }

    private func detail(at now: Date) -> String {
      let seconds = Int(max(0, now.timeIntervalSince(host.foundAt)))
      let found = String(localized: "found \(seconds) s ago")
      if host.facts.displayName == nil, namingPending {
        return found + " · " + String(localized: "name query in flight")
      }
      var parts = [found]
      if let mac = host.facts.mac { parts.append(mac.description) }
      if let vendor = host.facts.vendor { parts.append(vendor) }
      if let known {
        parts.append(known.name.map { String(localized: "matched to \($0)") } ?? String(localized: "matched to a known device"))
      }
      return parts.joined(separator: " · ")
    }
  }
}
