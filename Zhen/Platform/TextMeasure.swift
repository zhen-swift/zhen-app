import AppKit
import SwiftUI

/// How wide text will be, before it is drawn.
///
/// The Devices table sizes every column but NAME to its widest cell, and SwiftUI has no way
/// to ask that of a string ahead of layout. AppKit does, so the question is asked here, in
/// the one `Platform/` file allowed to import it, with the fonts the text styles resolve to.
nonisolated enum TextMeasure {
  enum Style {
    case body, callout, subheadline, caption, headline
  }

  static func width(_ text: String, _ style: Style, monospaced: Bool = false) -> CGFloat {
    let size = NSFont.preferredFont(forTextStyle: style.textStyle).pointSize
    let font = monospaced
      ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
      : NSFont.systemFont(ofSize: size, weight: style.weight)
    return ceil((text as NSString).size(withAttributes: [.font: font]).width)
  }

  /// The widest of several strings.
  ///
  /// Measuring every one was 5.2 s for a /16's 65 534 rows, on the main thread, on every
  /// redraw of the table (`ScaleTests`). In a monospaced face every character is as wide as
  /// every other, so the longest string is the widest and is the only one measured. In a
  /// proportional face each distinct string is measured once — a column of addresses
  /// repeats little, a column of "Now" and "2 hr. ago" repeats almost everything.
  static func widest(_ texts: some Sequence<String>, _ style: Style, monospaced: Bool = false) -> CGFloat {
    if monospaced {
      guard let longest = texts.max(by: { $0.count < $1.count }) else { return 0 }
      return width(longest, style, monospaced: true)
    }
    return Set(texts).reduce(0) { max($0, width($1, style)) }
  }
}

private nonisolated extension TextMeasure.Style {
  var textStyle: NSFont.TextStyle {
    switch self {
    case .body: .body
    case .callout: .callout
    case .subheadline: .subheadline
    case .caption: .caption1
    case .headline: .headline
    }
  }

  var weight: NSFont.Weight {
    self == .headline ? .bold : .regular
  }
}
