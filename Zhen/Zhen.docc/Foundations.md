# Foundations

Colour, type, metrics, symbols and motion: every value a view may use, and nowhere else.

## Overview

A view never spells a colour, a font size or a distance. It names a token, and the token
carries the value and the reason for it. `Scripts/check-tokens.sh` fails CI on a literal in
a view.

### Colour

Twenty colour sets in `Assets.xcassets`, each with four variants: light, dark, and both
with Increase Contrast. Views use the generated symbols: `.foregroundStyle(.textPrimary)`,
`.background(.surfaceRaised)`.

| Role | Tokens |
|---|---|
| Surfaces | `surface`, `surfaceRaised`, `surfaceField` |
| Text | `textPrimary`, `textSecondary`, `textTertiary` |
| Accent | `accent` (text and marks), `accentFill` (chip fill), `onAccent`, `selectionFill` |
| Status marks | `statusOnline`, `statusWarning`, `statusInfo`, `offlineRing`, `signalWeak` |
| Status text | `statusOnlineText`, `statusWarningText`, `statusInfoText` |
| Lines | `divider`, `cardBorder` |
| System accent | `SystemAccent`: the global accent AppKit fills selections, switches and prominent buttons with when the Mac's accent is Multicolour |

Every text pair clears 4.5:1, and 7:1 under Increase Contrast; every line and mark clears
3:1 there. `PaletteContrastTests` resolves each pair from the compiled catalogue in all
four appearances; `Scripts/check-palette.py` checks the shipped `Assets.car`.

### Type

The system's text styles only — `.body`, `.subheadline`, `.callout`, `.caption`,
`.headline` — so Dynamic Type and the user's settings apply. Addresses and MACs are
`.monospaced()`; counts use `numericValue()` (monospaced digits). Section labels use
`sectionLabel()`: subheadline semibold, upper-cased, tracked 0.8, in `textTertiary`.

The type ramp is provisional until the designer's round 3.

### Metrics

| Token | Values (pt) | For |
|---|---|---|
| `Spacing` | 2, 4, 8, 12, 16, 20, 24 | gaps and padding on the 4 pt grid; card padding 16, content inset 20 |
| `CornerRadius` | 4, 6, 8, 10 | chip, field, card, tile |
| `BorderWidth` | 1, 2 | hairlines; the focus ring |
| `IconSize` | 6, 8, 12, 16, 40 | status dots to the detail's tile glyph |
| `Dimension` | event kind 140, histogram 64, tile 44, intercell 17 | the measured one-offs |
| `WindowSize` | minimum 860 × 480, default 1180 × 720, sidebar 180–220, NAME ≥ 200, Settings 560 × 640, toolbar 52 | window bounds; the minimum is computed from the table |

Use them as `.padding(.spacing.medium)` or `.frame(width: .dimension.deviceTile)`.

### Symbols

SF Symbols only. Rooms: `square.grid.2x2.fill` (Devices), `waveform.path.ecg` (Activity).
Scanning: `dot.radiowaves.left.and.right`. A device's tile is guessed from its model or
name — `laptopcomputer`, `desktopcomputer`, `appletv`, `iphone`, `ipad`, `printer`,
`wifi.router` — and is `questionmark.circle` when there is nothing to guess from.

### Motion

One curve: `.spring(duration: 0.3)`, for rows arriving in a live scan and the partial-run
disclosure. Nothing animates that the person did not cause or that does not show progress.

![Device detail, from the artboards.](03-device-detail.png)
