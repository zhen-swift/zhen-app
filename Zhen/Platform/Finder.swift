import AppKit

/// The Finder, for showing a file where it lives.
enum Finder {
  static func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}
