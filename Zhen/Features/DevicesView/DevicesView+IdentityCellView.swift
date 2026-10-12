import SwiftUI
import ZhenCore

extension DevicesView {
  /// How well we know what the device is: bars and a word, never bars alone.
  ///
  /// Bound to `identification`, never to identity-key stability (A2): the gateway with a
  /// rock-solid MAC but only a model string reads Partial; a MacBook with a rotating MAC
  /// and a clean Bonjour name reads Identified.
  struct IdentityCellView: View {
    let identification: Identification

    var body: some View {
      HStack(spacing: .spacing.small) {
        SignalMeter(identification)
        Text(Self.word(for: identification))
          .font(.subheadline)
          .foregroundStyle(identification == .identified ? .textPrimary : .textSecondary)
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isStaticText)
    }

    static func word(for identification: Identification) -> String {
      switch identification {
      case .identified: String(localized: .identified)
      case .partial: String(localized: .partial)
      case .minimal: String(localized: .minimal)
      }
    }
  }
}
