import SwiftUI
import ZhenCore

extension DeviceDetailView {
  /// The tile, the name and state, what it is, and its addresses.
  struct HeaderView: View {
    let item: DeviceItem

    var body: some View {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: .spacing.xxLarge) {
          TitleView(item: item)
          Spacer(minLength: .spacing.large)
          AddressesView(item: item)
        }
        VStack(alignment: .leading, spacing: .spacing.large) {
          TitleView(item: item)
          AddressesView(item: item)
        }
      }
    }
  }
}
