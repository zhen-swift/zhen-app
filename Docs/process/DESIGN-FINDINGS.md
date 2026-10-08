# Design findings, from the old app's tests

Extracted in rebuild step P0.2, 2026-10-07. **Source commit: `fdb7eaf`** — the last commit
with the old app. Every file named below is readable as `git show fdb7eaf:<path>`. Line
numbers are from that commit.

These are measured findings, not code to port. Phase 1 uses them as **cases to satisfy**,
not answers to copy.

---

## 1. Contrast

**Source:** `ZhenTests/Design/ContrastTests.swift` (313 lines) and the token values it reads,
`Zhen/Design/Tokens/Palette.swift`.

The test holds no ratio literals. `printTable()` (lines 288–312) computes them at runtime
from the palette. The old project cannot build in this repository (it referenced `../zhen`
by path), so the table below was **recomputed** by
[`evidence/contrast-table.py`](evidence/contrast-table.py), which:

- parses every `token(…)` declaration in `Palette.swift` at `fdb7eaf`;
- resolves a tier exactly as `PaletteColor.resolved(scheme:contrast:)` does (Palette.swift
  lines 230–246, including the `Float` round trip through `Color.Resolved`);
- applies the test's own `luminance` (lines 67–72) and `ratio` (lines 75–83).

    python3 -I Docs/process/evidence/contrast-table.py . fdb7eaf

**Checked two ways.** It matches A1's independently published table to two decimals
(`Docs/process/A1-design-system-foundations.md`, the table under "Measured — and these
numbers come from a test": 14.59 / 13.48 / 11.68, 5.66 / 5.23 / 4.53, …, onAccent 6.64 and
5.45). **And it can fail:** passing an AA floor of 4.6 instead of 4.5 reports three pairs
below floor (textSecondary on field, dark, 4.53; textTertiary on field, dark, 4.54;
textSecondary on raised, light, 4.56).

### Floors (ContrastTests.swift)

| Floor | Value | Line | Applies to |
|---|---|---|---|
| `floorAA` | 4.5 | 89 | every text token, standard contrast. All text counts as body text: the largest type was 22 pt regular, below the 24 pt "large" threshold (lines 87–88) |
| `floorAAA` | 7.0 | 94 | every text token, Increase Contrast |
| `floorNonText` | 3.0 | 98 | separator and offline ring, **Increase Contrast only**, deliberately not at standard (lines 183–187) |

### Backgrounds: three, not one

`surface`, `surfaceRaised`, `surfaceField` (lines 109–113). **This is the lesson.** The first
correction was derived against `surface` alone and failed on the other two (lines 12–15,
104–108). Chips, filter chips and the search field sit on `surfaceField`.

### Token values (Palette.swift)

| Token | Line | Dark | Light | Dark, increased | Light, increased |
|---|---|---|---|---|---|
| `surface` | 72 | `1A1A1F` | `FFFFFF` | = | = |
| `surfaceRaised` | 74 | `212127` | `EEEDF3` | = | = |
| `surfaceField` | 76 | `2C2C32` | `F0F0F0` | = | = |
| `separator` | 83 | `2A2A2F` | `E3E3E8` | `75757A` | `88888D` |
| `selection` | 88 | `373548` | `DBD8ED` | = | = |
| `accent` | 95 | `A495E8` | `6A58C9` | `BDAEFF` | `4E3CAD` |
| `onAccent` | 104 | `1A1A1F` | `FFFFFF` | = | = |
| `textPrimary` | 109 | `EBEBF0` | `1D1D1F` | = | = |
| `textSecondary` | 130 | `939396` | `6B6B6E` | `B8B8BB` | `4F4F52` |
| `textTertiary` | 148 | `939399` | `6A6A6E` | `B8B8BE` | `4F4F53` |
| `offlineRing` | 157 | `49494F` | `C4C4C9` | `75757B` | `88888D` |
| `Status.online` | 179 | `4CD268` | `4CD268` | = | = |
| `Status.warning` | 181 | `D9A856` | `D9A856` | = | = |
| `Status.info` | 183 | `6DB3D4` | `6DB3D4` | = | = |
| `Status.onlineText` | 186 | `4CD268` | `217538` | `4CD268` | `085C1F` |
| `Status.warningText` | 191 | `D9A856` | `8A6114` | `E2B15F` | `6F4600` |
| `Status.infoText` | 196 | `6DB3D4` | `256F90` | `7CC2E3` | `0B5576` |

`=` means no increased variant declared: `token()` falls back to the standard value
(Palette.swift, the `?? dark` / `?? light` in `token(…)`).

### The table

Ratios, foreground on background. **0 of the 100 asserted pairs are below floor**: 7 text
tokens (3 text, accent, 3 status) × 3 surfaces × 2 themes = 42 at AA (lines 135–146) and 42
at AAA (148–162); 2 non-text × 3 surfaces × 2 themes = 12 at increased (181–199); onAccent
on accent, 2 themes × 2 tiers = 4 (164–179).

**Dark · standard** (floor 4.5; non-text not asserted)

| | surface | raised | field |
|---|---|---|---|
| textPrimary | 14.59 | 13.48 | 11.68 |
| textSecondary | 5.66 | 5.23 | **4.53** |
| textTertiary | 5.67 | 5.24 | **4.54** |
| accent | 6.64 | 6.13 | 5.31 |
| onlineText | 8.85 | 8.18 | 7.09 |
| warningText | 8.00 | 7.39 | 6.40 |
| infoText | 7.47 | 6.90 | 5.98 |
| separator | 1.21 | 1.12 | 1.03 |
| offlineRing | 1.94 | 1.79 | 1.55 |
| onAccent on accent | 6.64 | | |

**Light · standard** (floor 4.5)

| | surface | raised | field |
|---|---|---|---|
| textPrimary | 16.83 | 14.46 | 14.77 |
| textSecondary | 5.31 | **4.56** | 4.66 |
| textTertiary | 5.39 | 4.63 | 4.73 |
| accent | 5.45 | 4.68 | 4.78 |
| onlineText | 5.73 | 4.92 | 5.03 |
| warningText | 5.53 | 4.75 | 4.85 |
| infoText | 5.59 | 4.80 | 4.91 |
| separator | 1.28 | 1.10 | 1.12 |
| offlineRing | 1.74 | 1.49 | 1.52 |
| onAccent on accent | 5.45 | | |

**Dark · increased** (floor 7.0; non-text 3.0)

| | surface | raised | field |
|---|---|---|---|
| textPrimary | 14.59 | 13.48 | 11.68 |
| textSecondary | 8.76 | 8.09 | **7.01** |
| textTertiary | 8.78 | 8.11 | 7.03 |
| accent | 8.80 | 8.13 | 7.05 |
| onlineText | 8.85 | 8.18 | 7.09 |
| warningText | 8.82 | 8.15 | 7.06 |
| infoText | 8.82 | 8.15 | 7.06 |
| separator | 3.78 | 3.49 | **3.03** |
| offlineRing | 3.79 | 3.50 | **3.03** |
| onAccent on accent | 8.80 | | |

**Light · increased** (floor 7.0; non-text 3.0)

| | surface | raised | field |
|---|---|---|---|
| textPrimary | 16.83 | 14.46 | 14.77 |
| textSecondary | 8.16 | **7.01** | 7.16 |
| textTertiary | 8.15 | **7.01** | 7.15 |
| accent | 8.16 | **7.01** | 7.16 |
| onlineText | 8.20 | 7.05 | 7.20 |
| warningText | 8.23 | 7.07 | 7.22 |
| infoText | 8.15 | **7.01** | 7.16 |
| separator | 3.53 | **3.03** | 3.10 |
| offlineRing | 3.53 | **3.03** | 3.10 |
| onAccent on accent | 8.16 | | |

Bold: within 0.1 of the floor. **The old palette was tuned to the edge.** Any re-sampling
from the artboards in P1.2 moves these, and the binding cases are `surfaceField` on dark
and `surfaceRaised` on light.

### Known-failing cases, for the helper's negative tests

From A1's history (`Docs/process/A1-design-system-foundations.md`, "The tokens you must not
ship as measured"), recomputed with the same formula, not copied:

| Pair | Ratio | Floor | Why it matters |
|---|---|---|---|
| `65656C` on `1A1A1F` | 3.00 | 4.5 | the artboard's own dark secondary text |
| `ADADB0` on `FFFFFF` | 2.24 | 4.5 | the artboard's own light secondary text |

The "first correction" values that passed on `surface` and failed on the other two are not
recorded with their hex values anywhere in the tree at `fdb7eaf`; only the fact is
(ContrastTests lines 12–15).

### Invariants the test pinned, besides ratios

| Invariant | Lines |
|---|---|
| Every token resolves differently in dark and light (no single-theme measurement) | 201–211 |
| Seven tokens declare an increased variant and it differs: textSecondary, textTertiary, accent, separator, offlineRing, warningText, infoText | 213–236 |
| `onAccent` has no increased variant on purpose: the accent moves and carries the pair | 170–171 |
| Status **marks** are theme- and contrast-invariant; only the **text** variants shift. On dark at standard, mark = text | 252–274 |
| With no override, contrast follows `\.colorSchemeContrast`; the test process runs at standard | 238–250 |
| `\.colorSchemeContrast` is get-only, and `NSAppearance(.accessibilityHighContrastDarkAqua)` resolves to plain `.darkAqua`: **Increase Contrast cannot be tested by setting the system value.** The old app added an environment override for that | 29–41 |

For the rebuild this last point matters most. Colorsets with high-contrast variants are
resolved by the system, so P1.5's "rendered in increased contrast" needs a real route to the
increased appearance. The override does not carry over.

---

## 2. SF Symbols

**Source:** `ZhenTests/Design/SymbolTests.swift` (62 lines), names from
`Zhen/Design/Tokens/Symbols.swift`.

The test checked each name with `NSImage(systemSymbolName:accessibilityDescription:)`
(line 20). Its reason (lines 6–11): an unknown name in `Image(systemName:)` renders nothing,
with no crash and no warning.

**Re-measured 2026-10-07 on macOS 26.6.2** with the same call: **30 of 30 exist.** Control:
`zhen.not.a.symbol` → missing, so the check can fail.

| Role | Symbol | Symbols.swift line |
|---|---|---|
| devices | `square.grid.2x2.fill` | 18 |
| activity | `waveform.path.ecg` | 20 |
| settings | `gearshape` | 22 |
| search | `magnifyingglass` | 26 |
| rescan | `arrow.clockwise` | 28 |
| back | `chevron.left` | 30 |
| reveal ("Show in System Settings…") | `arrow.up.forward.app` | 32 |
| disclosure | `chevron.right` | 34 |
| laptop | `laptopcomputer` | 38 |
| desktop | `desktopcomputer` | 40 |
| tv | `appletv` | 42 |
| router | `wifi.router` | 44 |
| phone | `iphone` | 46 |
| printer | `printer` | 48 |
| unknown | `questionmark.circle` | 50 |
| online | `circle.fill` | 54 |
| offline | `circle` | 56 |
| done | `checkmark.circle.fill` | 58 |
| queued | `circle` | 60 |
| warning | `exclamationmark.triangle.fill` | 62 |
| ipChanged | `arrow.left.arrow.right` | 66 |
| appeared | `plus.circle.fill` | 68 |
| disappeared | `minus.circle.fill` | 70 |
| merged | `arrow.triangle.merge` | 72 |
| renamed | `pencil` | 74 |
| portOpened | `lock.open.fill` | 76 |
| portClosed | `lock.fill` | 78 |
| noScan | `antenna.radiowaves.left.and.right` | 82 |
| noMatches | `magnifyingglass` | 84 |
| noEvents | `clock.arrow.circlepath` | 86 |

Two glyphs are shared on purpose (SymbolTests lines 51–56): `circle` (offline, queued) and
`magnifyingglass` (search, noMatches).

**Missing from the old set:** no symbol for *Events*, the fourth sidebar item the rebuild
adds (the old app had three rooms). `noEvents` is an empty state, not a sidebar icon.

---

## 3. Keyboard

**Source:** `ZhenTests/Design/KeyboardTests.swift` (238 lines).

### Withdrawn, not a finding

The brief expected "tab-stop counts per screen and the traversal order". **At `fdb7eaf` the
file withdraws them** (lines 9–23). It once measured 12 stops in Devices, 5 in Activity and
5 in Settings, all wrapping, but that was a design that forced `.focusable()` on every
control. JC chose the platform convention instead: Tab visits text fields and lists unless
Full Keyboard Access is on. With it off (`AppleKeyboardUIMode` unset on this Mac, read
2026-10-07), there is nothing for Tab to traverse, and the counts cannot be repeated. They
are recorded here as history and **must not be used as targets**. No per-control traversal
order survives in the file.

### Measured, and still true

| Finding | Lines |
|---|---|
| The AppKit key-view loop is not where SwiftUI focus lives: walking for `canBecomeKeyView` finds exactly one view (the search field's bridged `AppKitTextField`); three plain buttons find zero, three default-styled buttons find zero | 27–30 |
| Focus does not move unless **at least two** controls are focusable. A probe against one control concludes, wrongly, that the app has no focus handling | 32–34 |
| A `ButtonStyle` cannot read focus: `@Environment(\.isFocused)` in a style's body stays false (three renders, zero differing pixels). A focus-aware look needs a modifier holding `@FocusState` | 36–39 |
| Space and Return cannot be driven from a `swift test` process: it cannot become active, so there is no key window and no ordinary key is routed. Tab was the exception | 41–46 |
| `NavigationSplitView` keeps the sidebar out of the Tab loop; `focusSection()` on both columns did not change it. **⌘-number shortcuts are the only keyboard route between rooms on a stock Mac** | 161–166; `Zhen/Design/Models/ScanModels.swift` 167–174 |
| Room shortcuts are numbered in drawn order: Devices ⌘1, Activity ⌘2, Settings ⌘3 | 172; ScanModels.swift 178–184 |
| Focus ring: width ≥ 2 pt ("a hairline halo on a dark surface is a thing you hunt for") and a gap > 0 (otherwise accent on an accent button). Old values 2 and 2 | 151–154; `Zhen/Design/Tokens/Metrics.swift` 69, 74 |
| Counting "any changed pixel" passed while the ring was suppressed, because the caret changes pixels too; count pixels of the ring's colour | 60–64 |

**Consequence for the rebuild.** The sidebar is now four items (Devices, Activity, Events,
Settings), so the shortcuts become ⌘1–⌘4 in drawn order. But `AGENTS.md` moves Settings to a
`Settings { }` scene opened with ⌘, — so whether Settings keeps a sidebar row *and* a ⌘4 is a
phase-2 decision (`REBUILD-questions.md` Q2).
