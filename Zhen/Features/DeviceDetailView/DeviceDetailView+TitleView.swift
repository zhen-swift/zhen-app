import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// The tile, the name, the state, and one line of what it is.
  struct TitleView: View {
    let item: DeviceItem

    var body: some View {
      HStack(alignment: .top, spacing: .spacing.medium) {
        Image(systemName: DeviceDetailView.symbol(for: item.device))
          .font(.title2)
          .foregroundStyle(.textSecondary)
          .frame(width: .dimension.deviceTile, height: .dimension.deviceTile)
          .background(.surfaceRaised, in: .rect(cornerRadius: .cornerRadius.xLarge))
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: .spacing.xSmall) {
          Text(item.name ?? String(localized: .unidentifiedDevice))
            .font(.title2.bold())
            .foregroundStyle(.textPrimary)
            .accessibilityIdentifier("detailName")
          HStack(spacing: .spacing.small) {
            StatusDot(item.isOnline ? .online : .offline)
            Text(status)
              .font(.subheadline)
              .foregroundStyle(item.isOnline ? .textPrimary : .textSecondary)
          }
          Text(summary)
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }

    private var status: String {
      item.isOnline
        ? String(localized: .online)
        : String(localized: .lastSeenAgo(item.lastSeen.formatted(.relative(presentation: .numeric))))
    }

    /// "AppleTV5,3 · Unix-like (TTL) · Identified — 2 independent sources".
    private var summary: String {
      var parts = [item.subtitle]
      switch item.device.osHint {
      case .unixLike?: parts.append(String(localized: .unixLikeTtl))
      case .windows?: parts.append(String(localized: .windowsTtl))
      case .networkDevice?: parts.append(String(localized: .networkDeviceTtl))
      case nil: break
      }
      if let family = item.device.osFingerprint?.family { parts.append(String(localized: .tcpFingerprint(family))) }
      let sources = item.device.identificationEvidence.independentSources
      let word = DevicesView.IdentityCellView.word(for: item.identification)
      parts.append(sources > 0 ? String(AttributedString(localized: .independentSourceInflectTrue(word, sources)).characters) : word)
      return parts.joined(separator: " · ")
    }
  }
}
