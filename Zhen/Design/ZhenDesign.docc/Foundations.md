# Foundations

Colour, type, metrics, symbols and motion — the values every component is built from.

## Overview

Everything here was measured from the six artboards in `Docs/Design/`, at a 1182pt window
width, from 2× Retina exports. Pixel measurements are halved to give points.

The one rule that matters more than any single value: **semantic names only**. Nobody
outside `Tokens/` writes a colour, a font size or a dimension. A3's definition of done
makes that checkable — grep for `Color(red:` and `.system(size:` outside `Tokens/` and
both must return nothing.

## Colour

Values live in an asset catalog with **Any** and **Dark** appearances, so light and dark
are a data change rather than a branch in view code. Add a high-contrast appearance later
and no Swift changes at all.

| Token | Dark | Light |
|---|---|---|
| ``Palette/surface`` | `#1A1A1F` | `#FFFFFF` |
| ``Palette/surfaceRaised`` | `#212127` | `#EEEDF3` |
| ``Palette/surfaceField`` | `#2C2C32` | `#F0F0F0` |
| ``Palette/separator`` | `#2A2A2F` | `#E3E3E8` |
| ``Palette/selection`` | `#373548` | `#DBD8ED` |
| ``Palette/accent`` | `#A495E8` | `#6A58C9` |
| ``Palette/onAccent`` | `#1A1A1F` | `#FFFFFF` |
| ``Palette/textPrimary`` | `#EBEBF0` | `#1D1D1F` |
| ``Palette/textSecondary`` | `#939396` | `#6B6B6E` |
| ``Palette/textTertiary`` | `#939399` | `#6A6A6E` |
| ``Palette/offlineRing`` | `#49494F` | `#C4C4C9` |

The accent changes between themes and that is correct: the same purple on white is too
pale to read, and the darker one on `#1A1A1F` disappears.

Four of these differ from what the artboards sample, and two differ again from the
first correction. See <doc:Corrections>.

**There are three text backgrounds, not one.** `surface`, `surfaceRaised` and
`surfaceField` all carry text — cards and the sidebar sit on the raised surface, chips
and the search field on the field surface — so a colour derived against one of them is
only correct in a third of the app. That is the mistake this table has now made twice,
and `ContrastTests` is what stops it happening a third time.

### Status colours

``Palette/Status`` splits into marks and text, because one value cannot do both jobs on a
light background. The vivid green that reads perfectly as an 8pt dot is 1.96:1 as a word.

| Role | Dark | Light |
|---|---|---|
| ``Palette/Status/online`` (dots, tracks) | `#4CD268` | `#4CD268` |
| ``Palette/Status/onlineText`` (labels) | `#4CD268` | `#217538` |
| ``Palette/Status/warning`` | `#D9A856` | `#D9A856` |
| ``Palette/Status/warningText`` | `#D9A856` | `#8A6114` |
| ``Palette/Status/info`` | `#6DB3D4` | `#6DB3D4` |
| ``Palette/Status/infoText`` | `#6DB3D4` | `#256F90` |

## Type

| Role | Size / weight | Used for |
|---|---|---|
| `Font.screenTitle` | 22 semibold | "Devices", "Activity", "Settings" |
| `Font.screenSubtitle` | 13 regular | "10 devices · 9 online · 7 unidentified" |
| `Font.sectionLabel` | 11 semibold, uppercase | "SCANNING", "HISTORY" |
| `Font.columnHeader` | 11 semibold, uppercase | "NAME", "IP ADDRESS" |
| `Font.rowTitle` | 15 medium | device names |
| `Font.rowSubtitle` | 12 regular | "Randomized MAC · no vendor" |
| `Font.mono` | 13 monospaced | IPs, MACs, ports, times |
| `Font.badge` | 10 semibold, uppercase | GATEWAY, WINNER, private |
| `Font.control` | 13 regular | buttons, settings rows, detail body |
| `Font.controlEmphasis` | 13 semibold | primary button, degradation cause |
| `Font.sidebarRow` | 14 regular | sidebar room titles |
| `Font.filterChip` | 12 regular | unselected filter chip |

The last four are not in A1's table; see <doc:Corrections>.

**Monospace is a correctness decision, not a style one.** An IP address in a proportional
font makes `10.10.20.2` and `10.10.20.112` impossible to scan down a column, and a MAC
becomes a smear. Anything compared vertically is `Font.mono`.

Two rules that save time: use `.monospacedDigit()` on any changing number that is not
full monospace, or the layout jitters as digits change width; and never hard-code
`.uppercased()` — use `.textCase(.uppercase)` so the value stays intact for VoiceOver.

## Metrics

Every spacing value is a multiple of ``Metrics/unit`` (4). If a layout needs 13, it needs
12 or 16 — the in-between value is how a design starts looking hand-placed.

`Metrics.tableRowHeight` was 52 and a minimum rather than a frame. *Removed in stage 3 of the responsive work: the row is padding plus content, which is what the minimum was approximating.* The row is tall
because it carries two lines, and the second one is the entire product for an
unidentified device. At an accessibility type size the row must grow rather than clip.

## Symbols

Everything iconographic is SF Symbols — see ``Symbols``. No bundled PNGs and no custom
vectors: symbols scale, adapt their weight to adjacent text, respond to accessibility
settings, and match every other Mac app the user has open.

The one exception is ``ConfidenceMeter``, drawn rather than named, because the number of
filled bars is data.

## Motion

Deliberately restrained — see ``Motion``. This app shows a network changing on its own,
and every animation not caused by the user competes with one that is. The most important
entry is the one that does not exist: values that update in place are swapped, not
tweened, because a number that animates twice a second reads as noise.

Always route through ``Motion/honouring(_:reduceMotion:)`` rather than reaching for an
`Animation` directly.
