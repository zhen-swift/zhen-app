extension RootView {
  /// The device a rename sheet is open for.
  struct RenameRequest: Identifiable, Hashable {
    let id: DeviceItem.ID
  }
}
