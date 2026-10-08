import SwiftUI
import Testing

@testable import Zhen

struct TokenTests {
  @Test("The call sites the rules describe compile and read the token")
  func callSites() {
    let padding: CGFloat = .spacing.medium
    let optional: CGFloat? = .spacing.small
    #expect(padding == Spacing.medium)
    #expect(optional == Spacing.small)
    #expect(CGFloat.cornerRadius.large == CornerRadius.large)
    #expect(CGFloat.borderWidth.hairline == BorderWidth.hairline)
    #expect(CGFloat.iconSize.small == IconSize.small)
  }

  @Test("Every spacing step sits on the 2 pt half-grid and the scale only grows")
  func spacingIsAScale() {
    let steps = [
      Spacing.xxSmall, Spacing.xSmall, Spacing.small, Spacing.medium, Spacing.large,
      Spacing.xLarge, Spacing.xxLarge,
    ]
    #expect(steps == steps.sorted())
    #expect(Set(steps).count == steps.count)
    #expect(steps.allSatisfy { $0.truncatingRemainder(dividingBy: 2) == 0 })
  }

  @Test("Radii grow from chip to tile")
  func radiiAreAScale() {
    let steps = [CornerRadius.small, CornerRadius.medium, CornerRadius.large, CornerRadius.xLarge]
    #expect(steps == steps.sorted())
    #expect(Set(steps).count == steps.count)
  }
}
