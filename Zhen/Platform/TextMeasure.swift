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

  static func widest(_ texts: some Sequence<String>, _ style: Style, monospaced: Bool = false) -> CGFloat {
    texts.reduce(0) { max($0, width($1, style, monospaced: monospaced)) }
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
