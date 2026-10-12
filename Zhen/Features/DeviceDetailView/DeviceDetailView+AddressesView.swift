import SwiftUI

extension DeviceDetailView {
  /// Where it is: the addresses a person compares, monospaced.
  struct AddressesView: View {
    let item: DeviceItem

    var body: some View {
      KeyValueGrid(pairs: [
        .init(label: .ipAddressLabel, value: item.address, isAddress: true, id: "ip"),
        .init(label: .mac, value: item.mac, isAddress: true, chip: item.isPrivateMAC ? .private : nil, id: "mac"),
        .init(label: .firstSeen, value: item.firstSeen.formatted(date: .abbreviated, time: .shortened), id: "firstSeen"),
      ])
    }
  }
}
