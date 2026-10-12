import SwiftUI
import ZhenCore

extension RootView {
  /// What the menu bar can ask this window to do.
  var actions: WindowActions {
    WindowActions(
      room: room,
      isScanning: model.isBusy,
      selectionCount: selection.count,
      canGoBack: !path.isEmpty,
      showRoom: { room = $0 },
      activityFilter: activityFilter,
      setActivityFilter: { activityFilter = $0 },
      openSelection: openSelection,
      scanSelectionPorts: scanSelectionPorts,
      renameSelection: { if let id = singleSelection { rename(id) } },
      goBack: { if !path.isEmpty { path.removeLast() } },
      focusSearch: {
        path = []
        searchFocused = true
      },
      copyAddresses: { copy { $0.address } },
      copyMACAddresses: { copy { $0.mac } },
      showSelectionInActivity: {
        if let id = singleSelection, let item = model.device(id) { showActivity(for: item.name ?? item.address) }
      },
      exportHistory: { exporting = model.exportDocument() }
    )
  }

  var minimumWidth: CGFloat {
    let table = DevicesView.ColumnWidths(rows: model.devices, now: .now).minimumTable
    // The floating sidebar occupies its ideal plus an 8 pt inset: the splitter reports 228
    // for an ideal of 220.
    return max(WindowSize.minimumWidth, WindowSize.sidebarIdeal + Spacing.small + BorderWidth.hairline + table)
  }

  var singleSelection: DeviceItem.ID? {
    if case .device(let id)? = path.last { return id }
    return selection.count == 1 ? selection.first : nil
  }

  func openSelection() {
    guard room == .devices, path.isEmpty, let id = singleSelection else { return }
    path.append(.device(id))
  }

  /// The open device, or the selected ones: what a Copy command acts on.
  var targets: [DeviceItem] {
    if case .device(let id)? = path.last { return model.device(id).map { [$0] } ?? [] }
    return selection.compactMap(model.device)
  }

  func copy(_ value: (DeviceItem) -> String?) {
    let lines = targets.compactMap(value).sorted()
    if !lines.isEmpty { Pasteboard.copy(lines.joined(separator: "\n")) }
  }

  /// A port scan of one device, shown on its detail.
  func scanSelectionPorts() {
    guard let id = singleSelection else { return }
    // Opened, so the progress and the result are on screen: the scan no longer takes
    // over the window, and from the table it would otherwise run out of sight.
    if path.isEmpty { path.append(.device(id)) }
    model.scanPorts(id)
  }

  func rename(_ id: DeviceItem.ID) {
    renaming = RenameRequest(id: id)
  }

  /// Shows Activity searched for one device.
  ///
  /// The segment goes back to All: arriving from a device with Presence left selected
  /// showed only part of that device's history, with nothing on screen saying why.
  func showActivity(for name: String) {
    room = .activity
    activityFilter = .all
    Task { @MainActor in search = name }
  }

  /// A launch that does not restore starts in Devices with nothing selected or filtered.
  func startFresh() {
    guard !model.environment.restoresState, !restored else { return }
    room = .devices
    activityFilter = .all
    storedSelection = ""
    storedPath = ""
  }

  /// Puts back what the last session had open, once the devices it names are loaded.
  func restore() {
    guard !restored else { return }
    restored = true
    guard model.environment.restoresState else { return }
    let known = Set(model.devices.map(\.id))
    selection = Set(Self.decodeSelection(storedSelection)).intersection(known)
    path = Self.decodePath(storedPath).filter {
      if case .device(let id) = $0 { return known.contains(id) }
      return true
    }
  }

  // Scene storage holds strings; these are the two shapes it holds.

  static func encode(_ selection: Set<DeviceItem.ID>) -> String {
    selection.sorted().joined(separator: "\n")
  }

  static func decodeSelection(_ text: String) -> [DeviceItem.ID] {
    text.split(separator: "\n").map(String.init)
  }

  static func encode(_ path: [Route]) -> String {
    (try? JSONEncoder().encode(path)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
  }

  static func decodePath(_ text: String) -> [Route] {
    (try? JSONDecoder().decode([Route].self, from: Data(text.utf8))) ?? []
  }
}
