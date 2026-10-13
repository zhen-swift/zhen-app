import SwiftUI

/// Lengths of particular pieces that are neither spacing nor icons.
///
/// Provisional until the designer's round 3: these are the artboards' values halved to
/// points, and round 3 changes them here, never at a call site.
nonisolated enum Dimension {
  /// The kind label in an event row, so the sentences align. A2's 140: measured, 120 was
  /// 9 pt short of "ADDRESS CHANGED" and pushed that row's sentence out of line.
  static let eventKindLabel: CGFloat = 140
  /// The 48-hour histogram above Activity's list.
  static let histogramHeight: CGFloat = 64
  /// The gap a SwiftUI `Table` puts between two cells, and before the first. Measured from
  /// the accessibility frames of the running table (cell x 410 → 688 with the first 261
  /// wide), not chosen: the table's minimum width is the sum of its columns and these.
  static let tableIntercell: CGFloat = 17
  /// The device tile in the detail header (A3: 44).
  static let deviceTile: CGFloat = 44
}

nonisolated extension CGFloat {
  /// `.frame(width: .dimension.deviceTile)`.
  static var dimension: Dimension.Type { Dimension.self }
}
