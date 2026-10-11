import SwiftUI

extension RootView {
  /// The always-visible proof the app is alive: the last scan, and what it covered.
  ///
  /// Never empty. Before the first scan it says so; during one it says "Scanning…"; after a
  /// partial one the dot is amber, because a green dot over an incomplete scan is a lie of
  /// omission.
  struct SidebarFooterView: View {
    @Environment(NetworkModel.self) private var model

    var body: some View {
      VStack(alignment: .leading, spacing: .spacing.xxSmall) {
        Divider()
        HStack(spacing: .spacing.small) {
          StatusDot(model.footerTone)
          TimelineView(.everyMinute) { context in
            Text(model.footerTitle(at: context.date))
              .font(.subheadline)
              .foregroundStyle(.textPrimary)
              .accessibilityIdentifier("scanStatusTitle")
          }
        }
        .padding(.top, .spacing.small)
        Text(model.footerSubtitle)
          .font(.subheadline.monospaced())
          .foregroundStyle(.textSecondary)
          .lineLimit(1)
          .accessibilityIdentifier("scanStatusSubtitle")
      }
      .padding(.horizontal, .spacing.medium)
      .padding(.bottom, .spacing.medium)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("scanStatus")
    }
  }
}
