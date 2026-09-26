// Controls.swift — the button and the search field.

import SwiftUI

/// The accent-filled action button: "Scan Now", "Install Helper…".
///
/// The label colour comes from the `onAccent` token rather than from a literal white,
/// because the correct answer differs by theme — white on the light accent, the dark
/// surface on the light-on-dark accent — and both directions pass contrast comfortably.
public struct PrimaryButton: View {
    private let title: String
    private let action: () -> Void

    /// Creates a button.
    public init(_ title: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.controlEmphasis)
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, Metrics.unit * 3)
                .padding(.vertical, Metrics.unit + 2)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.fieldRadius).fill(Palette.accent)
                )
        }
        .buttonStyle(.plain)
        .zhenFocusRing()
    }
}

/// A quieter button for secondary actions — "Rename…", "Rescan Device".
public struct SecondaryButton: View {
    private let title: String
    private let action: () -> Void

    /// Creates a button.
    public init(_ title: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.control)
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Metrics.unit * 3)
                .padding(.vertical, Metrics.unit + 2)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.fieldRadius).fill(Palette.surfaceField)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.fieldRadius)
                        .strokeBorder(Palette.separator, lineWidth: Metrics.hairline)
                )
        }
        .buttonStyle(.plain)
        .zhenFocusRing()
    }
}

/// A borderless text link, used for a degradation's remedy.
public struct LinkButton: View {
    private let title: String
    private let action: () -> Void

    /// Creates a link.
    public init(_ title: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rowSubtitle)
                .foregroundStyle(Palette.accent)
        }
        .buttonStyle(.plain)
        .zhenFocusRing(.rounded(Metrics.chipRadius))
    }
}

/// The inline search field from the Devices toolbar row.
///
/// Prefer `.searchable` where the platform will place it for you; this exists for the
/// one place the artboards put a field inline in a header row, where the system
/// modifier would put it somewhere else.
public struct SearchField: View {
    @Binding private var text: String
    private let placeholder: String
    // Not `zhenFocusRing`. That modifier makes its content focusable, and a `TextField`
    // already is — applying it here would put TWO stops in the Tab order for one field,
    // the wrapper and then the field inside it. The ring is drawn by hand around a
    // focus state bound to the field itself.
    @FocusState private var focused: Bool

    /// Creates a field.
    public init(text: Binding<String>, placeholder: String = "Search") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: Metrics.unit + 2) {
            Image(systemName: Symbols.search)
                .imageScale(.small)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.control)
                .foregroundStyle(Palette.textPrimary)
                .focused($focused)
        }
        .padding(.horizontal, Metrics.unit * 2)
        // Vertical padding rather than a height. 28pt was the artboard's measurement of
        // this field at one font size; padding gives the same 28 at that size and the
        // right answer at every other.
        .padding(.vertical, Metrics.unit + 2)
        .background(
            RoundedRectangle(cornerRadius: Metrics.fieldRadius).fill(Palette.surfaceField)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.fieldRadius + Metrics.focusRingGap)
                .strokeBorder(Palette.accent, lineWidth: Metrics.focusRingWidth)
                .padding(-(Metrics.focusRingGap + Metrics.focusRingWidth))
                .opacity(focused ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.1), value: focused)
        // Clicking the field's chrome focuses the field, as it does in every other Mac
        // search box. Without this only the text itself is a target and the magnifier
        // and the padding are dead.
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .accessibilityLabel(placeholder)
    }
}

#Preview("Controls — dark") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            PrimaryButton("Scan Now")
            SecondaryButton("Rescan Device")
            LinkButton("Open System Settings…")
        }
        SearchField(text: .constant("")).frame(width: 280)
        SearchField(text: .constant("sala")).frame(width: 280)
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Controls — light") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            PrimaryButton("Scan Now")
            SecondaryButton("Rescan Device")
            LinkButton("Open System Settings…")
        }
        SearchField(text: .constant("")).frame(width: 280)
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.light)
}
