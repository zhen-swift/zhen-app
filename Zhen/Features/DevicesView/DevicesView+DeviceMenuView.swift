import SwiftUI
import ZhenCore

extension DevicesView {
  /// The right-click menu. It mirrors the menu bar's Device menu, item for item.
  struct DeviceMenuView: View {
    let ids: Set<DeviceItem.ID>
    let onOpen: (DeviceItem.ID) -> Void
    let onRename: (DeviceItem.ID) -> Void
    @Environment(NetworkModel.self) private var model

    var body: some View {
      let single = ids.count == 1 ? ids.first.flatMap(model.device) : nil
      Button("Open", systemImage: "arrow.right.circle") {
        if let single { onOpen(single.id) }
      }
      .disabled(single == nil)
      Button("Rename…", systemImage: "pencil") {
        if let single { onRename(single.id) }
      }
      .disabled(single == nil)
      Button("Scan Ports", systemImage: "network") {
        if let address = single?.device.ipv4Addresses.first {
          model.startScan(deepScan: true, network: .init(base: address, prefix: 32))
        }
      }
      .disabled(single?.device.ipv4Addresses.isEmpty ?? true || model.scan.isRunning)
      Divider()
      Button("Copy Address", systemImage: "doc.on.doc") {
        copy(ids.compactMap { model.device($0)?.address })
      }
      Button("Copy MAC Address", systemImage: "doc.on.doc") {
        copy(ids.compactMap { model.device($0)?.mac })
      }
    }

    private func copy(_ lines: [String]) {
      Pasteboard.copy(lines.sorted().joined(separator: "\n"))
    }
  }
}
