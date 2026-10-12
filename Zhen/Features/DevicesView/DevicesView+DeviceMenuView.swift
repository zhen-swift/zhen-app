import SwiftUI
import ZhenCore

extension DevicesView {
  /// The right-click menu. It mirrors the menu bar's Device menu, item for item.
  struct DeviceMenuView: View {
    let ids: Set<DeviceItem.ID>
    let onOpen: (DeviceItem.ID) -> Void
    let onRename: (DeviceItem.ID) -> Void
    let onShowActivity: (String) -> Void
    @Environment(NetworkModel.self) private var model

    var body: some View {
      let single = ids.count == 1 ? ids.first.flatMap(model.device) : nil
      Button(String(localized: .open), systemImage: "arrow.right.circle") {
        if let single { onOpen(single.id) }
      }
      .disabled(single == nil)
      Button(String(localized: .renameEllipsis), systemImage: "pencil") {
        if let single { onRename(single.id) }
      }
      .disabled(single == nil)
      Button(String(localized: .scanPorts), systemImage: "network") {
        // Opened first: the result shows on the device, not under the table.
        if let single {
          onOpen(single.id)
          model.scanPorts(single.id)
        }
      }
      .disabled(single?.device.ipv4Addresses.isEmpty ?? true || model.isBusy)
      Button(String(localized: .showActivity), systemImage: "waveform.path.ecg") {
        if let single { onShowActivity(single.name ?? single.address) }
      }
      .disabled(single == nil)
      Divider()
      Button(String(localized: .copyAddress), systemImage: "doc.on.doc") {
        copy(ids.compactMap { model.device($0)?.address })
      }
      Button(String(localized: .copyMacAddress), systemImage: "doc.on.doc") {
        copy(ids.compactMap { model.device($0)?.mac })
      }
    }

    private func copy(_ lines: [String]) {
      Pasteboard.copy(lines.sorted().joined(separator: "\n"))
    }
  }
}
