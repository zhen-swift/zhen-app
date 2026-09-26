// LayoutClass.swift — which shape a view should take, and where that decision lives.
//
// ── Why this is derived and not read from the environment ──────────────────────
//
// The plan for this work says `horizontalSizeClass` is unavailable on macOS. It is not.
// It is declared in `SwiftUICore`, which `SwiftUI` re-exports:
//
//     @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
//     public var horizontalSizeClass: UserInterfaceSizeClass? { get set }
//
// It compiles, and a view reading it gets a value. The value is `regular`, at 320pt, at
// 700pt and at 1400pt — measured, in an `NSHostingView`, at each of those widths. It is
// constant.
//
// So wrapping it would produce a layout switch soldered to one position. Deriving from
// the container's width is what the plan wanted, and its own argument for deriving is
// the better one anyway: a narrow detail pane inside a wide window needs the compact
// layout, and a window-level size class would call that pane regular.
//
// The one-line swap stays available. The reason to take it is not "if the platform ever
// vends it" — it does — but "if the value ever varies".
//
// ── Why views ask for a class and never for a width ────────────────────────────
//
// A view that reads a width makes a layout decision at a number somebody chose once, at
// one font size, in one language. That is the defect this entire body of work exists to
// remove; reintroducing it one `GeometryReader` at a time would be the same mistake with
// better manners. A view asks which shape it is in. Exactly one place decides.

import SwiftUI

/// Which of two shapes a view should take.
public enum LayoutClass: Sendable, Hashable, CaseIterable {
    /// Room for the full form: every column, labels beside their values.
    case regular
    /// Narrow. Columns fold, labels sit above their values, secondary detail is
    /// dropped rather than truncated.
    case compact
}

private struct LayoutClassKey: EnvironmentKey {
    /// `regular` when nothing has decided.
    ///
    /// The safe default: it is the layout every screen already draws, so a view that
    /// nothing has measured yet looks exactly as it did before this type existed.
    static let defaultValue: LayoutClass = .regular
}

extension EnvironmentValues {
    /// The shape the enclosing container asked for.
    public var zhenLayoutClass: LayoutClass {
        get { self[LayoutClassKey.self] }
        set { self[LayoutClassKey.self] = newValue }
    }
}

extension View {
    /// Measures this container and publishes a layout class to everything inside it.
    ///
    /// Put on a pane, not on a leaf. The point is that the pane decides once and its
    /// contents ask; a leaf that measures itself is back to reading widths.
    ///
    /// - Parameter threshold: the width below which the contents are compact. Defaults
    ///   to 640, which is the width at which the device table stops being able to show
    ///   its columns; a caller with a different fold says so.
    public func zhenLayoutClass(compactBelow threshold: CGFloat? = nil) -> some View {
        modifier(DerivedLayoutClass(threshold: threshold))
    }
}

private struct DerivedLayoutClass: ViewModifier {
    let threshold: CGFloat?
    @State private var layoutClass: LayoutClass = .regular

    /// The width below which a pane is compact, when the caller does not say.
    ///
    /// A plain constant, and not `@ScaledMetric`. That wrapper was here first, on the
    /// theory that the fold should happen when the content stops fitting rather than at
    /// a number. It does not work: measured on macOS 26, a view holding
    /// `@ScaledMetric(relativeTo: .body) var x = 100` reports 100.0 at both `.large`
    /// and `.accessibility3`, because the platform does not consume `dynamicTypeSize`.
    /// A wrapper that cannot vary is a constant wearing a costume.
    private static let defaultFold: CGFloat = 640

    func body(content: Content) -> some View {
        let fold = threshold ?? Self.defaultFold
        return content
            .environment(\.zhenLayoutClass, layoutClass)
            .background(
                GeometryReader { proxy in
                    // A colour rather than an empty view: `Color` fills the container,
                    // which is what makes the proxy report the CONTAINER's width rather
                    // than the intrinsic width of nothing. `Color.clear` and not the
                    // palette's, because this one is never seen — it is a measuring
                    // device, and drawing it from a token would imply it had a visual
                    // job it does not have.
                    Color.clear
                        .onAppear { update(proxy.size.width, fold: fold) }
                        .onChange(of: proxy.size.width) { _, width in
                            update(width, fold: fold)
                        }
                }
            )
    }

    private func update(_ width: CGFloat, fold: CGFloat) {
        // Zero is what a container reports before it has been laid out. Deciding on it
        // would flash every pane through compact on the way to its real size.
        guard width > 0 else { return }
        let derived: LayoutClass = width < fold ? .compact : .regular
        if derived != layoutClass { layoutClass = derived }
    }
}
