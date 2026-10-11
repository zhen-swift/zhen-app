import SwiftUI

extension DeviceDetailView {
  /// Where it is: the addresses a person compares, monospaced.
  struct AddressesView: View {
    let item: DeviceItem

    var body: some View {
      KeyValueGrid(pairs: [
        .init(label: "IP address", value: item.address, isAddress: true, id: "ip"),
        .init(label: "MAC", value: item.mac, isAddress: true, chip: item.isPrivateMAC ? "private" : nil, id: "mac"),
        .init(label: "First seen", value: item.firstSeen.formatted(date: .abbreviated, time: .shortened), id: "firstSeen"),
      ])
    }
  }
}
