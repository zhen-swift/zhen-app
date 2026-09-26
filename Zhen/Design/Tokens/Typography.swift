// Typography.swift — the type scale, measured from the artboards.
//
// The artboards are 2× Retina exports, so every pixel measurement in A1 is halved here
// to give points.
//
// Two rules encoded rather than left to the caller:
//
// **Monospace is a correctness decision, not a style one.** An IP address in a
// proportional font makes `10.10.20.2` and `10.10.20.112` impossible to scan down a
// column, and a MAC address becomes a smear. Anything a person compares vertically —
// addresses, ports, timestamps — is `.mono`. Anything they read as language is not.
//
// **Never hard-code `.uppercased()`.** The small labels use `.textCase(.uppercase)` at
// the call site so the underlying string stays intact for VoiceOver and localisation.
// VoiceOver reading "N-A-M-E" is a real bug, not a cosmetic one.

import SwiftUI

public extension Font {
    /// "Devices", "Activity", "Settings". 22 semibold.
    static let screenTitle = Font.system(size: 22, weight: .semibold)
    /// "6 devices · 5 online · 2 unidentified". 13 regular, secondary colour.
    static let screenSubtitle = Font.system(size: 13)
    /// "SCANNING", "HISTORY". 11 semibold, uppercased and tracked at the call site.
    static let sectionLabel = Font.system(size: 11, weight: .semibold)
    /// "NAME", "IP ADDRESS". Same metrics as `sectionLabel`, different colour role, and
    /// kept separate so the two can diverge without a search-and-replace.
    static let columnHeader = Font.system(size: 11, weight: .semibold)
    /// Device names. 15 medium.
    static let rowTitle = Font.system(size: 15, weight: .medium)
    /// "MacBook Pro 14″ · Apple". 12 regular, secondary colour.
    static let rowSubtitle = Font.system(size: 12)
    /// IPs, MACs, ports, times — everything compared down a column.
    static let mono = Font.system(size: 13, design: .monospaced)
    /// GATEWAY, WINNER, private. 10 semibold, uppercased at the call site.
    static let badge = Font.system(size: 10, weight: .semibold)

    // ── Sizes A1's table does not name, but the artboards plainly use ────────────
    //
    // A1's type scale lists eight roles and none of them is the 13pt body text that
    // carries every button label, every settings row and the degradation copy. Rather
    // than let a bare `.system(size: 13)` spread across seventeen call sites — which is
    // exactly how a token system stops being one — the roles are named here. See
    // <doc:Corrections>.

    /// Button labels, settings row titles and values, detail body text. 13 regular.
    ///
    /// Shares its metrics with ``screenSubtitle`` and is deliberately a separate token:
    /// they are different roles and either could move without the other.
    static let control = Font.system(size: 13)
    /// A control's emphasised form — the primary button, a degradation's cause, the
    /// helper's state line. 13 semibold.
    static let controlEmphasis = Font.system(size: 13, weight: .semibold)
    /// Sidebar room titles. 14 regular — a step above the table, because the sidebar is
    /// navigation rather than data.
    static let sidebarRow = Font.system(size: 14)
    /// An unselected filter chip. 12 regular.
    static let filterChip = Font.system(size: 12)
    /// A selected filter chip. 12 semibold, so selection is weight as well as fill.
    static let filterChipSelected = Font.system(size: 12, weight: .semibold)
}

/// Tracking values for the letter-spaced labels, so a view never writes a bare number.
public enum Tracking {
    /// `sectionLabel` and `columnHeader`.
    public static let label: CGFloat = 0.6
    /// `badge`.
    public static let badge: CGFloat = 0.5
}
