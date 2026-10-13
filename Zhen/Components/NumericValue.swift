import SwiftUI

/// A number that changes in place — a count, a round trip, a byte total — set so it ticks
/// rather than jitters: fixed-width digits, and the system's numeric transition.
struct NumericValue: ViewModifier {
  func body(content: Content) -> some View {
    content
      .monospacedDigit()
      .contentTransition(.numericText())
  }
}

extension View {
  /// For text whose digits change: `Text(count, format: .number).numericValue()`.
  func numericValue() -> some View {
    modifier(NumericValue())
  }
}

#Preview("Numeric value") {
  NumericValuePreview().preferredColorScheme(.dark)
}

/// Click the count to watch it tick.
private struct NumericValuePreview: View {
  @State private var count = 6

  var body: some View {
    Button {
      withAnimation(.spring) { count += 1 }
    } label: {
      Text(count, format: .number).numericValue().font(.title3)
    }
    .buttonStyle(.press)
    .foregroundStyle(.textPrimary)
    .padding(.spacing.xLarge)
    .background(.surface)
  }
}
