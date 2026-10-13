import SwiftUI
import ZhenCore

/// One device, everything known about it: the header, then four cards in one column —
/// identity history, the names it is known by, its open ports, and what has happened to it.
///
/// "Known by" lists every source that offered a name and which one won. That card is the
/// product's argument for itself.
struct DeviceDetailView: View {
  let id: DeviceItem.ID
  let onRename: (DeviceItem.ID) -> Void
  let onShowActivity: (String) -> Void
  @Environment(NetworkModel.self) var model

  var body: some View {
    Group {
      if let item = model.device(id) {
        ScrollView {
          VStack(alignment: .leading, spacing: .spacing.large) {
            HeaderView(item: item)
            IdentityCardView(item: item)
            KnownByCardView(item: item)
            PortsCardView(item: item)
            RecentEventsCardView(events: Array(events(for: item).prefix(5))) {
              onShowActivity(item.activitySearchTerm)
            }
          }
          .padding(.spacing.xLarge)
        }
        .navigationTitle(item.name ?? String(localized: .unidentifiedDevice))
        .navigationSubtitle(item.address)
        .toolbar {
          ToolbarItemGroup(placement: .primaryAction) {
            Button(String(localized: .renameEllipsis), systemImage: "pencil") { onRename(item.id) }
              .help(String(localized: .giveThisDeviceNameYourOwn))
              .accessibilityIdentifier("renameButton")
            Button(String(localized: .scanPorts), systemImage: "network") { scanPorts(item) }
              .help(String(localized: .checkThisDevicesCommonPorts))
              .disabled(item.device.ipv4Addresses.isEmpty || model.isBusy)
              .accessibilityIdentifier("scanPortsButton")
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deviceDetail")
      } else {
        ContentUnavailableView(
          String(localized: .deviceNotFound), systemImage: "questionmark.circle",
          description: Text(.historyNoLongerHasThisDevice)
        )
      }
    }
  }
}

#Preview("Detail — identified, dark") {
  NavigationStack {
    DeviceDetailView(id: PreviewContainer.namedDeviceID, onRename: { _ in }, onShowActivity: { _ in })
  }
  .environment(PreviewContainer.model(.home))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
  .preferredColorScheme(.dark)
}

#Preview("Detail — unidentified, light") {
  NavigationStack {
    DeviceDetailView(id: PreviewContainer.anonymousDeviceID, onRename: { _ in }, onShowActivity: { _ in })
  }
  .environment(PreviewContainer.model(.home))
  .frame(width: .windowSize.defaultWidth, height: .windowSize.defaultHeight)
  .preferredColorScheme(.light)
}
