import AppKit

/// The general pasteboard. SwiftUI's `.copyable` covers a selection; a context-menu
/// "Copy Address" over rows that are not the selection needs this.
enum Pasteboard {
  static func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
