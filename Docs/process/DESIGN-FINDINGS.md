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

---

## 4. The artboards, sampled (for P1.2)

**Source:** `Docs/Design/01`–`06-*.png` (no colour profile; `sips -g profile` → nil, so the
bytes are read uncorrected and treated as sRGB, as A1 did). Sampled 2026-10-07 by
[`evidence/sample-artboard.swift`](evidence/sample-artboard.swift) with the boxes in
[`evidence/artboard-boxes/`](evidence/artboard-boxes/), in source pixels. `fill` is the
most common colour in a box; `ink` is the pixel furthest from it, for text and glyphs.
Reproduce with:

    swift Docs/process/evidence/sample-artboard.swift Docs/Design/01-devices-dark.png \
      Docs/process/evidence/artboard-boxes/01-devices-dark.txt

**Light exists only for Devices** (`02`). Every other screen is drawn dark only, so the
light values for cards, chips, status text, the histogram and controls must be derived.
No artboard draws Increase Contrast.

### Surfaces and fills

| Role | Dark | Light | Where sampled | Old palette (dark / light) |
|---|---|---|---|---|
| window / content surface | `1A1A1F` | `FFFFFF` | 01/02 content | same |
| sidebar, cards (raised) | `212127` | `EEEDF3` | 01/02 sidebar; 03, 05, 06 cards | same |
| live-scan stage card | `1E1E23` | — | 05 | none |
| search field | `27272C` | `F4F4F4` | 01/02 | `2C2C32` / `F0F0F0` (`surfaceField`) |
| text field, chip | `2C2C32`, `2C2C31` | `F0F0F0` | 06 field; 01/02 `private` chip | `surfaceField` |
| popup button | `2E2E34` | — | 06 | none |
| sidebar selection | `373548` | `DBD8ED` | 01/02 | same |
| gateway chip | `302E3F` | `ECE9F8` | 01/02 | none |
| winner chip | `363446` | — | 03 | none |
| device icon tile | `2D2B3C` | — | 03 | none |
| progress track | `29292E` | — | 05 | none |
| toggle off | `404045` | — | 06 | none (a platform `Toggle` draws its own) |

### Lines and marks

| Role | Dark | Light | Where | Old palette |
|---|---|---|---|---|
| row / header separator | `2A2A2F` | `E8E8E8` | 01/02 | `2A2A2F` / `E3E3E8` |
| card border | `313136` | — | 03 | none |
| active stage card border | `4F496A` | — | 05 | none |
| offline ring | `49494F` | `CECED0` | 01/02 | `49494F` / `C4C4C9` |
| past identity dot | `49494E` | — | 03 | none |
| online dot / toggle on / progress done / signal | `4CD268` | `23A844` | 01–06 | `4CD268` both (old app made marks theme-invariant; **the light artboard does not**) |
| signal, weak bars | `3A3A3F` | `E0E0E0` | 01/02 | none |
| histogram, ordinary bar | `5F5884` | — | 04 | none |

### Accent and status

| Role | Dark | Light | Where |
|---|---|---|---|
| accent: button, links, signal, selected icon, merged, histogram peak | `A495E8` | `6A58C9` | 01–05 |
| label on accent | `17141F` | `FFFFFF` | 01/02 button, 04 filter (old palette: `1A1A1F`) |
| warning / port events | `D9A856` | — | 04, 05 |
| info / IP changed | `6DB3D4` | — | 04 |
| appeared | `4CD268` | — | 04 |
| disappeared | `65656C` | — | 04 (the faint grey, not a hue) |

### Text — and which reads

The artboards use **more text greys than A1 recorded**, and most of them fail. Ratios
against every surface each can land on (WCAG 2, same formula as section 1):

| Text | Dark | on surface / raised / stage / search / field | Light | on surface / raised / search / chip |
|---|---|---|---|---|
| primary | `EBEBF0` | 14.59 / 13.48 / 13.97 / 12.51 / 11.68 | `1D1D1F` | 16.83 / 14.46 / 15.30 / 14.77 |
| secondary (event prose, IP, filter chips, unidentified name) | `97979F` | 5.98 / 5.52 / 5.72 / 5.13 / 4.79 | `7B7B7F` | **4.22 / 3.62 / 3.83 / 3.70** |
| sidebar label | `9A9AA3` | 6.21 / 5.74 / 5.95 / 5.33 / 4.97 | `75757C` | 4.57 / **3.93 / 4.16 / 4.01** |
| chip text | `717178` | **3.58 / 3.31 / 3.43 / 3.07 / 2.86** | `A4A4A7` | **2.49 / 2.14 / 2.26 / 2.18** |
| section header | `6A6A71` | **3.23 / 2.98 / 3.09 / 2.77 / 2.59** | `A3A3A9` | **2.51 / 2.16 / 2.28 / 2.20** |
| offline row name | `68686F` | **3.14 / 2.90 / 3.00 / 2.69 / 2.51** | `B0B0B2` | **2.17 / 1.86 / 1.97 / 1.90** |
| tertiary (descriptor lines, column headers, MAC, times) | `65656C` | **3.00 / 2.77 / 2.87 / 2.57 / 2.40** | `ADADB0` | **2.24 / 1.92 / 2.04 / 1.96** |
| queued stage | `46464C` | **1.85 / 1.71 / 1.77 / 1.59 / 1.48** | — | — |
| accent | `A495E8` | 6.64 / 6.13 / 6.36 / 5.69 / 5.31 | `6A58C9` | 5.45 / 4.68 / 4.96 / 4.78 |
| label on accent | `17141F` on `A495E8`: 6.96 | | `FFFFFF` on `6A58C9`: 5.45 | |

Bold = below 4.5. **On dark, everything below `97979F` fails; on light, even the secondary
grey fails.** The old app collapsed this to two corrected tokens (`939396` / `939399`), so its
offline, chip, section and queued texts became as loud as secondary text. P1.2 has to
choose between keeping the artboards' four-step hierarchy, with each step lifted to clear
4.5 on every surface it touches (the steps then compress, as A1's "secondary and tertiary
converge" found), or carrying the hierarchy in type rather than colour. That is the
"could not reconcile" item for the phase report. `AGENTS.md`'s "legibility is
non-negotiable" rules out shipping the sampled values as they are.

### Two discrepancies between artboards

- **Field fill:** the search field in 01 is `27272C`, the text fields in 06 are `2C2C32`.
  Both are native controls in the rebuild (`.searchable`, `TextField` in a `Form`), which
  draw their own fill, so neither becomes a token unless a component needs it.
- **Light online green:** `23A844` in 02 versus `4CD268` everywhere dark. As a mark it
  clears the 3:1 non-text floor on the light surface (3.11) but not on the raised sidebar
  (2.67), where the footer dot sits.
