# Accessibility

The floor, and how each part of it is checked.

## Overview

Non-negotiable and checkable. Every item below is either a measurement anyone can
reproduce or a rule with a named place in the code.

## Contrast

At least 4.5:1 for every text token, measured with the WCAG 2.1 relative-luminance
formula against the surface the text actually sits on.

Every pair below is measured by `ContrastTests` on every run, reading the tokens back
through the same dynamic provider the views use. The numbers are the test's own output.

| Token | on `surface` | on `surfaceRaised` | on `surfaceField` | Theme |
|---|---|---|---|---|
| ``Palette/textPrimary`` | 14.59 | 13.48 | 11.68 | dark |
| ``Palette/textSecondary`` | 5.66 | 5.23 | 4.53 | dark |
| ``Palette/textTertiary`` | 5.67 | 5.24 | 4.54 | dark |
| ``Palette/accent`` | 6.64 | 6.13 | 5.31 | dark |
| ``Palette/Status/onlineText`` | 8.85 | 8.18 | 7.09 | dark |
| ``Palette/Status/warningText`` | 8.00 | 7.39 | 6.40 | dark |
| ``Palette/Status/infoText`` | 7.47 | 6.90 | 5.98 | dark |
| ``Palette/textPrimary`` | 16.83 | 14.46 | 14.77 | light |
| ``Palette/textSecondary`` | 5.31 | 4.56 | 4.66 | light |
| ``Palette/textTertiary`` | 5.39 | 4.63 | 4.73 | light |
| ``Palette/accent`` | 5.45 | 4.68 | 4.78 | light |
| ``Palette/Status/onlineText`` | 5.73 | 4.92 | 5.03 | light |
| ``Palette/Status/warningText`` | 5.53 | 4.75 | 4.85 | light |
| ``Palette/Status/infoText`` | 5.59 | 4.80 | 4.91 | light |

``Palette/onAccent`` on ``Palette/accent`` measures 6.64:1 on dark and 5.45:1 on light —
the pair inverts between themes and passes in both directions.

**Three backgrounds, not one.** Cards, the sidebar and every settings section sit on
`surfaceRaised`; chips, filter chips and the search field sit on `surfaceField`. A token
derived against `surface` alone is correct in the device list and nowhere else, which is
precisely what happened to the first contrast correction.

The values the artboards sample fail at 3.00:1 and 2.24:1, and the first correction of
them still failed at 4.18:1 and 3.89:1 on the raised surface. See <doc:Corrections> for
what shipped and why neither round was optional.

## No state is colour-only

Every state has a second, non-colour signal:

- ``StatusDot`` — online is **filled**, offline is a **hollow ring**. The shape is the
  signal; the colour is a bonus.
- ``ConfidenceMeter`` — bars **and** the word "Identified", "Partial" or "Minimal".
- ``EventRow`` — a coloured dot **and** an uppercase kind label.
- ``StageCard`` — a distinct SF Symbol per state, not just a colour.

## VoiceOver

A device row is **one element reading one sentence**, not five the user swipes through:

> "JC's MacBook Pro, online, identified, at 10.10.20.8, private hardware address
> 52:A1:8A:E0:7A:8A, last seen now."

That is ``DeviceRowModel/accessibilityDescription``, applied with
`.accessibilityElement(children: .combine)`. The same pattern covers ``EventRow``,
``KeyValueGrid`` rows and the sidebar.

Symbols are either labelled or hidden, never left to chance. A dot next to the word
"Online" is decorative and gets `.accessibilityHidden(true)`; a dot that is the only
indication of state gets a label. Getting this backwards produces either silence or a
stutter, and both are worse than no icon.

``TimelineHistogram`` collapses to one element with a summary value. Forty-eight bars is
forty-eight swipes and none of them mean anything individually.

## Growing text

`Metrics.tableRowHeight` was a minimum applied with `.frame(minHeight:)`. *Removed in stage 3: the row sizes to its content, which grows for the same reasons.* Fixed
heights and growing text are enemies: when a row's content needs more room it has to
grow, and clipping the second line would remove the only thing an unidentified device
tells you.

That guarantee is real and it is visible in the device list today — the two
neighbour-table-only rows have the longest subtitle on the network, it wraps to two
lines at the default window width, and those rows are taller than the others rather
than truncated.

**What is not true on this platform, and A1's accessibility floor assumes it is:** macOS
has no Dynamic Type. Setting `\.dynamicTypeSize` to `.accessibility5` changes nothing —
not for `Font.system(size:)`, and not for the semantic `.body` either, which was measured
rather than assumed. The environment value exists on macOS and is inert. So the previews
at accessibility sizes look identical to the default ones, and they are kept because they
cost nothing and become meaningful the day an iOS target exists.

The structural work is what carries the requirement here, and all of it is real:

- `.frame(minHeight:)` everywhere a row has a height, never `.frame(height:)`.
- `.fixedSize(horizontal: false, vertical: true)` on every block of prose, so it wraps
  rather than truncating.
- Two-line limits on the row title and subtitle rather than one, so a long name or a long
  explanation survives.
- No `.lineLimit(1)` on anything that carries meaning.

## Reduce Motion

Route every animation through ``Motion/honouring(_:reduceMotion:)``:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

withAnimation(Motion.honouring(Motion.disclosure, reduceMotion: reduceMotion)) { … }
```

Reduce Motion is not a preference about taste. For some people it is the difference
between using the app and feeling ill.

## Keyboard

Every control is a real `Button` with `.buttonStyle(.plain)` rather than a tap gesture on
a shape, so focus and activation work without anything extra. `NavigationSplitView`
supplies sidebar and table traversal.

## Text case

Uppercase is applied with `.textCase(.uppercase)`, never baked into the string. VoiceOver
reading "N-A-M-E" is a real bug, and a hard-coded uppercase string breaks localisation
into languages with different casing rules.
