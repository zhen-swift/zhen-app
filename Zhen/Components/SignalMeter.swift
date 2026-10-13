import SwiftUI
import ZhenCore

/// Rising bars, some lit: how sure the app is of a device's identity, or a Wi-Fi signal.
///
/// The artboards draw three bars for identity (Identified, Partial, Minimal) in the accent,
/// and four for a client's signal in green. Unlit bars are the catalogue's `signalWeak`.
struct SignalMeter: View {
  let lit: Int
  let bars: Int
  let tint: Color
  let label: LocalizedStringResource
  @ScaledMetric(relativeTo: .body) private var size = IconSize.medium

  init(lit: Int, of bars: Int = 3, tint: Color = .accent, label: LocalizedStringResource = .signal) {
    self.label = label
    self.lit = min(max(lit, 0), bars)
    self.bars = max(bars, 1)
    self.tint = tint
  }

  var body: some View {
    // Proportions, not sizes: a bar is two units wide with one between, and bar i rises to
    // (i + 1) / bars of the height, so the meter scales as one shape with Dynamic Type.
    let unit = size / CGFloat(bars * 3 - 1)
    HStack(alignment: .bottom, spacing: unit) {
      ForEach(0..<bars, id: \.self) { index in
        RoundedRectangle(cornerRadius: unit / 2)
          .fill(index < lit ? tint : Color.signalWeak)
          .frame(width: unit * 2, height: size * CGFloat(index + 1) / CGFloat(bars))
      }
    }
    .frame(width: size, height: size, alignment: .bottom)
    .accessibilityElement()
    .accessibilityAddTraits(.isImage)
    .accessibilityLabel(label)
    .accessibilityValue(String(localized: .of(lit, bars)))
  }
}

#Preview("Signal meters — dark") {
  SignalMeterPreview().preferredColorScheme(.dark)
}

#Preview("Signal meters — light") {
  SignalMeterPreview().preferredColorScheme(.light)
}

#Preview("Signal meters — increased contrast") {
  SignalMeterPreview()
    .preferredColorScheme(.dark)
    .environment(\._colorSchemeContrast, .increased)
}

private struct SignalMeterPreview: View {
  var body: some View {
    VStack(alignment: .leading, spacing: .spacing.small) {
      Label { Text(.identified) } icon: { SignalMeter(lit: 3) }
      Label { Text(.partial) } icon: { SignalMeter(lit: 2) }
      Label { Text(.minimal) } icon: { SignalMeter(lit: 1, tint: .textTertiary) }
      Label { Text(verbatim: "−52 dBm") } icon: { SignalMeter(lit: 3, of: 4, tint: .statusOnline) }
    }
    .foregroundStyle(.textSecondary)
    .padding(.spacing.xLarge)
    .background(.surface)
  }
}

extension SignalMeter {
  /// A2's ConfidenceMeter: identity as three bars. One meter, two readings — this is the
  /// same view, not a second one.
  init(_ identification: Identification) {
    self.init(
      lit: 3 - identification.rank, of: 3,
      tint: identification == .minimal ? .textTertiary : .accent,
      label: .identity
    )
  }
}
