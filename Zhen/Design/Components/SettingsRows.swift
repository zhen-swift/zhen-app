// SettingsRows.swift — three shapes that cover the whole Settings screen.
//
// Toggle, menu, static. Grouped under section labels inside a single `Card` with
// hairlines between rows, which is exactly the standard macOS settings grammar — and
// that is the point. Nobody should have to learn this screen.

import SwiftUI

/// A section heading above a settings card.
public struct SectionLabel: View {
    private let text: String

    /// Creates a heading.
    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(.sectionLabel)
            .textCase(.uppercase)
            .tracking(Tracking.label)
            .foregroundStyle(Palette.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A row with a title, an optional explanation, and a trailing `Toggle`.
public struct ToggleRow: View {
    private let title: String
    private let explanation: String?
    @Binding private var isOn: Bool

    /// Creates a toggle row.
    public init(_ title: String, explanation: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.explanation = explanation
        self._isOn = isOn
    }

    public var body: some View {
        SettingsRowLayout(title: title, explanation: explanation) {
            // No focus ring, and no forced focusability. A `Toggle` becomes an
            // `NSSwitch`, which the platform puts in the Tab loop when Full Keyboard
            // Access is on and leaves out when it is off — and following that is the
            // decision recorded in `FocusRing.swift`.
            //
            // Stage 5 first forced it, because the traversal gate measured what the
            // setting costs: with it off, the whole Settings screen had exactly ONE
            // reachable control. That measurement stands and is worth keeping in mind;
            // what changed is the answer to it, which is now that the setting is the
            // platform's affordance rather than something an app works around.
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Palette.Status.online)
        }
        // The whole row is one control, so the toggle's label is the title rather than
        // an unlabelled switch the user meets after the text.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

/// A row with a title and a trailing menu.
public struct MenuRow<Value: Hashable & CustomStringConvertible>: View {
    private let title: String
    private let explanation: String?
    private let options: [Value]
    @Binding private var selection: Value

    /// Creates a menu row.
    public init(
        _ title: String,
        explanation: String? = nil,
        options: [Value],
        selection: Binding<Value>
    ) {
        self.title = title
        self.explanation = explanation
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        SettingsRowLayout(title: title, explanation: explanation) {
            Picker("", selection: $selection) {
                ForEach(options, id: \.self) { Text($0.description).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .accessibilityLabel(title)
    }
}

/// A row with a title and a read-only trailing value.
public struct StaticRow: View {
    private let title: String
    private let value: String
    private let note: String?
    private let isAddress: Bool

    /// Creates a static row.
    ///
    /// - Parameters:
    ///   - title: the label.
    ///   - value: the value.
    ///   - note: a trailing explanation — "auto, from en0", "it's what makes merges
    ///     possible". This is where a settings screen teaches instead of just listing.
    ///   - isAddress: renders the value monospaced.
    public init(_ title: String, value: String, note: String? = nil, isAddress: Bool = false) {
        self.title = title
        self.value = value
        self.note = note
        self.isAddress = isAddress
    }

    public var body: some View {
        SettingsRowLayout(title: title, explanation: nil) {
            HStack(spacing: Metrics.unit + 2) {
                Text(value)
                    .font(isAddress ? .mono : .control)
                    .foregroundStyle(Palette.textPrimary)
                if let note {
                    Text(note)
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)\(note.map { ", \($0)" } ?? "")")
    }
}

/// The shared skeleton: title and explanation leading, control trailing.
struct SettingsRowLayout<Trailing: View>: View {
    let title: String
    let explanation: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.unit * 4) {
            VStack(alignment: .leading, spacing: Metrics.unit) {
                Text(title)
                    .font(.control)
                    .foregroundStyle(Palette.textPrimary)
                if let explanation {
                    Text(explanation)
                        .font(.rowSubtitle)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Metrics.unit * 4)
            trailing()
        }
        .padding(Metrics.cardPadding)
    }
}

#Preview("Settings rows — dark") {
    VStack(alignment: .leading, spacing: 8) {
        SectionLabel("Scanning")
        Card {
            VStack(spacing: 0) {
                MenuRow("Scan automatically",
                        options: ["Off", "Every 5 minutes", "Every 15 minutes", "Every 60 minutes"],
                        selection: .constant("Every 15 minutes"))
                Divider().overlay(Palette.separator)
                StaticRow("Subnet", value: "10.10.20.0/24", note: "auto, from en0", isAddress: true)
                Divider().overlay(Palette.separator)
                ToggleRow("Deep-scan new devices",
                          explanation: "Run a port scan the first time a device is seen",
                          isOn: .constant(true))
            }
        }
    }
    .padding()
    .frame(width: 700)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Settings rows — light") {
    VStack(alignment: .leading, spacing: 8) {
        SectionLabel("History")
        Card {
            VStack(spacing: 0) {
                MenuRow("Keep events for",
                        options: ["30 days", "90 days", "Forever"],
                        selection: .constant("90 days"))
                Divider().overlay(Palette.separator)
                StaticRow("Device identity history", value: "Kept forever",
                          note: "— it\u{2019}s what makes merges possible")
            }
        }
    }
    .padding()
    .frame(width: 700)
    .background(Palette.surface)
    .preferredColorScheme(.light)
}
