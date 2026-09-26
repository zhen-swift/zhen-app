# Corrections

Where this system deliberately differs from the artboards, and why.

## Overview

This article matters more than it sounds. Written down, these are decisions. Undocumented,
the next person "fixes" them back to match the artboards and quietly reintroduces the
problems they were made to solve.

Twelve divergences so far. Four were named in the appendices; four were found while
building; four came out of an architectural review. Entry 1 has since been corrected a
second time, for the same class of mistake it was itself fixing.

Entries 9 through 12 are not divergences from the artboards in the way the first eight
are — the artboards were right and the code was not. They are kept here anyway, because
the failure mode this article exists to prevent is identical: an undocumented decision
gets "fixed" back by the next person, and the problem it solved returns.

## Secondary text contrast, corrected twice

**A1's contrast correction, and the one that is not negotiable.**

The artboards sample `#65656C` on dark and `#ADADB0` on light. Measured against their own
surfaces those are **3.00:1** and **2.24:1**, against a WCAG AA requirement of 4.5:1.

This token carries the vendor, the model and the "Randomized MAC · no vendor · responds
to ping" line — the content that makes an unidentified device legible instead of blank.
On the reference network that is seven rows out of ten. It is not decorative and it
cannot be 3:1.

### The second round, and why the first was not enough

A1's correction — `#828285` and `#767679` — was derived against ``Palette/surface``
alone. **This design has three text backgrounds.** Against the other two, the corrected
values were still failing:

| Pair | First correction | Verdict |
|---|---|---|
| `#828285` on `surface` `#1A1A1F` | 4.52:1 | pass |
| `#828285` on `surfaceRaised` `#212127` | 4.18:1 | **fail** |
| `#828285` on `surfaceField` `#2C2C32` | 3.62:1 | **fail** |
| `#767679` on `surface` `#FFFFFF` | 4.53:1 | pass |
| `#767679` on `surfaceRaised` `#EEEDF3` | 3.89:1 | **fail** |
| `#767679` on `surfaceField` `#F0F0F0` | 3.97:1 | **fail** |

Which meant secondary text was compliant in the device list and non-compliant nearly
everywhere else: every card, every settings row, the sidebar's own footer, and the
"Known by" and "Open ports" cards — the explanatory text the correction existed to
protect in the first place.

``Palette/textSecondary`` now ships `#939396` and `#6B6B6E`, which clear 4.5:1 against
**every** surface in the palette. Hue is unchanged; every channel moved by the same
amount.

`surfaceField` is included, and A1's reasoning never mentions it. Chips, filter chips and
the search field all put secondary text on it, and the `private` chip is 10pt — small
text, so it needs the full 4.5:1. Fixing the raised surface and leaving the field surface
failing would have been the same error one step later.

**One token that is safe everywhere, not two chosen correctly at each call site.** The
alternative — a second on-raised token — moves the failure from the value to the call
site, where nothing can check it.

### What that costs: secondary and tertiary converge

Held to the same floor on the same three backgrounds, ``Palette/textSecondary`` and
``Palette/textTertiary`` land three units of blue apart on dark and one on light. There
is no visible colour step left between them.

That is a consequence, not an oversight, and it is worth being explicit about because the
obvious reaction is to "fix" it. Both tokens are at the AA minimum; a step below the
minimum is by definition non-compliant, so the only way to restore a colour step is to
push *secondary* louder — to about 6.65:1 on dark, well above the muted look the
artboards establish. That trade was available and not taken.

A1 described tertiary as "one step quieter than secondary", and its own values had the
step **inverted**: `#88888E` is lighter, and therefore louder, than `#828285` on dark.
That happened for the same reason as everything else on this page — the two were derived
against different backgrounds.

The hierarchy is typographic and always was: tertiary is 11pt semibold uppercase with
+0.6 tracking, secondary is 12pt regular sentence case. Those do not look alike.

``Palette/textTertiary`` moved on dark only, from `#88888E` to `#939399`, because
`#88888E` was 3.94:1 on `surfaceField`. Its light value `#6A6A6E` already cleared all
three and is unchanged.

## The offline row keeps its name at full contrast

**A2's DeviceRow.**

The artboards dim the entire offline row. That makes a sleeping laptop read as
*disabled* — as though the app cannot act on it — rather than as *seen two hours ago*.

``DeviceRow`` dims only the secondary content and holds the name at
``Palette/textPrimary``. Offline is a fact about the network, not a state of the control.

## The partial-run strip

**A3's Devices screen.**

The artboards have no state for a finished run that lost a source, and one is needed.
Degradations do not evaporate when a scan ends: a green dot over an incomplete scan is a
lie of omission.

``PartialRunStrip`` sits under the Devices header with a one-line summary and a disclosure
onto the same ``DegradationBanner`` rows the live scan showed, and the sidebar footer dot
turns amber.

## Hedged permission copy

**A2's DegradationBanner.**

The artboards say the Local Network permission "was denied". We cannot query that grant —
denial is *inferred* from finding nothing by ICMP while the neighbour table is populated.

``DegradationModel/mdnsDenied`` says "appears to be denied". A tool that quietly overstates
one thing has its other claims doubted, and this tool's entire pitch is that it does not
guess.

## Status colours split into marks and text

**Found while building. A1 gives no light-theme value for the status colours at all.**

The artboards use one vivid green for both the status dot and the "APPEARED" label in the
activity list. As a dot that is fine — a dot is a shape, filled versus hollow carries the
meaning, and A1's accessibility floor says so explicitly. As *text on white* that green is
**1.96:1**, amber is **2.17:1** and blue is **2.32:1**. All three are unreadable.

``Palette/Status`` therefore has two families. ``Palette/Status/online`` and its siblings
are the artboard colours, unchanged in both themes, for dots, fills and progress tracks.
``Palette/Status/onlineText`` and its siblings are identical on dark — where the vivid
colours already reach 7–9:1 — and darkened on light so a kind label passes 4.5:1 on both
``Palette/surface`` and ``Palette/surfaceRaised``.

``EventPalette`` is where the choice is made, and it is the only place either family is
selected.

## Type roles A1's table does not name

**Found while building.**

A1's type scale lists eight roles, and none of them is the 13pt body text the artboards
plainly use for every button label, every settings row, the detail body and the
degradation copy. Nor the 14pt sidebar row, nor the 12pt filter chip.

Rather than let a bare `.system(size: 13)` spread across seventeen call sites — which is
exactly how a token system stops being one — the missing roles are named:
`Font.control`, `Font.controlEmphasis`, `Font.sidebarRow`, `Font.filterChip` and
`Font.filterChipSelected`.

`Font.control` shares its metrics with `Font.screenSubtitle` and is deliberately a
separate token: they are different roles and either could move without the other.

## Light-theme values A1 does not give

**Found while building.**

A1's colour section gives light values for seven tokens and dark values for twelve. The
five with no light value — `separator`, `offlineRing` and the three status colours — were
derived to match the light artboard's appearance, with contrast checked where they carry
text:

| Token | Light value | Basis |
|---|---|---|
| ``Palette/separator`` | `#E3E3E8` | sampled from the light artboard's row hairlines |
| ``Palette/offlineRing`` | `#C4C4C9` | sampled from the light artboard's hollow dot |
| ``Palette/Status/onlineText`` | `#217538` | 5.73:1 on white, 4.92:1 on raised |
| ``Palette/Status/warningText`` | `#8A6114` | 5.53:1 on white, 4.75:1 on raised |
| ``Palette/Status/infoText`` | `#256F90` | 5.59:1 on white, 4.80:1 on raised |

``Palette/onAccent`` is also new: A2's PrimaryButton describes the button label as
"white-on-accent in light, `surface`-on-accent in dark", which is a semantic token in
prose. It is one here.

## Dynamic Type does not exist on macOS

**Found while building, by measuring rather than assuming.**

A1's accessibility floor requires that "Dynamic Type is respected… let rows grow", and
A2's previews section asks for previews at a large Dynamic Type size. On macOS neither
does anything: setting `\.dynamicTypeSize` to `.accessibility5` leaves
`Font.system(size:)` unchanged, and leaves the semantic `.body` unchanged too. It was
rendered both ways side by side to be sure.

The requirement is met structurally instead — minimum heights, wrapping prose, two-line
limits — and <doc:Accessibility> says exactly which parts are real and which are inert.
The accessibility-size previews are kept because they cost nothing and start meaning
something the day there is an iOS target.

## Layout authority: the sidebar was paying for the table

**Found by an architectural review, then measured.**

`DeviceRow` laid its columns out with `.frame(width:)`, which gives the table a hard
intrinsic minimum. `RootView` asked for `.navigationSplitViewColumnWidth(228)` — which is
a *preference*, not a constraint — under `.balanced` style. When the detail column could
not meet its minimum, the split view took the difference from the sidebar:

| Window | Sidebar on Devices | Sidebar on Settings |
|---|---|---|
| 1182 / 1100 / 1000 | 228 | 228 |
| 900 | **204** | 228 |
| 820 | **164** | 228 |
| 760 | **134** | 228 |

Settings never caused it, because its content is elastic. So the layout pressure landed
on whichever view was least defended, and the thing least defended was the navigation.

Worse, a fixed-width table inside a vertical-only `ScrollView` does not scroll sideways.
Past the minimum the last column was simply gone — no scrollbar, no indication, no way to
reach it. That is the UI withholding data the model holds, which is a correctness defect
rather than a styling one.

Three changes, in the order they have to happen:

1. **Columns are ranges.** `Metrics.Column` carried a minimum beside each measured
   width. The appendix recorded those numbers at a 1182pt window and never declared them
   rigid; reading them as rigid is what created the minimum in the first place.

   *Superseded in stage 2 of the responsive work.* Ranges were the right correction to
   rigid widths and the wrong answer to the underlying question, which is why a view
   holds a number at all. The columns are measured from their content now and
   `Metrics.Column` no longer exists. What survives from this entry is the diagnosis.
2. **The sidebar is pinned**, with `min:ideal:max:` all equal, so it has no give to take.
3. **The window has a minimum**, so the pressure lands somewhere it can be refused.

### The minimum is rendered, and the two earlier ways of getting it were both wrong

The first attempt summed the tokens: sidebar + columns = 948pt, and it was 8pt short.
The second asked the layout system — `NSHostingView.fittingSize` on the assembled
window — and got 956pt, which was right at the time and stopped being right in stage 2.

**`fittingSize` cannot see the table.** The device list is inside a `ScrollView`, and a
scroll view accepts any width and reports no minimum on behalf of what it holds. Once
the fixed columns were replaced by measured ones, the only thing left asserting a width
outside the scroll view was the header block, so the Devices room answered **398pt** for
a room whose table needs 650 and which visibly runs out from under the sidebar at
anything below 886. Three suites asked that question and believed that answer.

Stage 4 replaced it with rendering. The window is drawn and the detail pane's leading
ink is measured: content that fits starts at `rowInset` inside the pane, and content
wider than the pane centres itself and runs back underneath the sidebar, which reads as
leading ink at or near zero. ``Metrics/windowMinWidth`` is **890**, four points above the
886pt threshold that method found, and `WindowLayoutTests` now fails in both directions —
if a room stops fitting, and if the table still fits well below the declared number.

`Metrics.Column.nameMin` was 200 rather than 160 for a related reason: at 160 the
longest real subtitle — "Randomized MAC · no vendor · in ARP table, no ping reply" —
truncated at the window's minimum size, and truncating that line is not a cosmetic loss.
It is the entire content of a row with no name, no vendor and no model, which is seven
rows out of ten on the reference network.

## One window, previewed and shipped

**Found by the same review.**

There were two: ``ZhenWindow`` for the previews and `RootView` for the product, each
constructing its own `NavigationSplitView`. They had already drifted — the app's sidebar
had a background the design module's did not.

This is why the sidebar defect above survived a design-system review with 57 previews
behind it: **the preview and the product were different objects**, so a layout defect in
one was invisible in the other.

``ZhenWindow`` now owns the split-view configuration and takes its two columns as
parameters. ``FixtureWindow`` supplies fixtures for previews, `RootView` supplies live
views, and both get the same window.

## Increase Contrast, and the two attempts it took

**Attempted, measured, backed out, and then done properly.**

The review noted that ``Palette``'s `NSColor(name:dynamicProvider:)` ignores the system's
Increase Contrast setting, and proposed a custom `ShapeStyle` reading
`\.colorSchemeContrast`. The cheaper-looking answer is that macOS names two more
appearances, so a four-way `bestMatch(from:)` inside the existing provider should reach
the same place at no call-site cost.

It does not. Measured:

```
NSAppearance(named: .accessibilityHighContrastDarkAqua)!.name
    -> NSAppearanceNameDarkAqua
…bestMatch(from: [.aqua, .darkAqua,
                  .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
    -> NSAppearanceNameDarkAqua
```

The accessibility appearance collapses into its base. It is not constructible standalone
— it exists only on an appearance handed down by a live view hierarchy with the setting
on — which also means **a test can never build one**, so even a working version could not
be verified. The review's mechanism was right, for a reason neither of us had stated:
`\.colorSchemeContrast` is an environment value, and `ShapeStyle.resolve(in:)` is handed
the whole environment.

### The refactor, done

Every token is now a `PaletteColor`, a `ShapeStyle` carrying four values — dark, light,
and an increased-contrast variant of each — resolved in `resolve(in:)`. AppKit is gone
from the design module entirely.

The values are the ones derived here previously, and they hold: every text token clears
**7:1 against all three surfaces in both themes**, with the tightest pairing at 7.01:1.

| Token | HC dark | HC light | worst ratio |
|---|---|---|---|
| `textSecondary` | `#B8B8BB` | `#4F4F52` | 7.01 |
| `textTertiary` | `#B8B8BE` | `#4F4F53` | 7.01 |
| `accent` | `#BDAEFF` | `#4E3CAD` | 7.01 |
| `Status.onlineText` | `#4CD268` | `#085C1F` | 7.05 |
| `Status.warningText` | `#E2B15F` | `#6F4600` | 7.06 |
| `Status.infoText` | `#7CC2E3` | `#0B5576` | 7.01 |
| `separator` | `#75757A` | `#88888D` | 3.03 |
| `offlineRing` | `#75757B` | `#88888D` | 3.03 |

**One claim in the earlier version of this table was wrong and is corrected here.** It
said all of these were ≥ 7:1. `separator` and `offlineRing` are not, and should not be:
they are UI components rather than text, so their bar is WCAG 1.4.11's 3:1, and a
hairline held to a text floor is a rule rather than a hairline. They reach 3.03:1, which
is the bar they are actually held to. The contrast suite asserts them against
`floorNonText` and asserts nothing about them at standard contrast, where they are
deliberately faint.

`textPrimary` needs no variant: 11.68:1 at its weakest already. `onAccent` needs none
either, and that is a consequence rather than an oversight — the pair inverts between
themes, so lifting the accent carries the label with it, 6.64:1 and 5.45:1 becoming
8.80:1 and 8.16:1 with `onAccent` unmoved. The status **marks** are unchanged in every
appearance: a dot is a shape, filled versus hollow carries the meaning, and moving them
would change what the design looks like rather than what it is legible at.

### The call sites that wanted a concrete `Color` were changed, not accommodated

A `ShapeStyle` covers `foregroundStyle`, `background`, `fill` and `tint`, which is every
call site in the package except two kinds: a ternary mixing a token with `Color.clear`
(the selection fills), and a private computed property typed `Color` (the stage-card
symbol and progress fill, and `EventPalette`'s two functions).

Keeping a `Color` accessor for those would have been a quiet hole in the feature. A
`Color` is resolved against the colour scheme and nothing else — there is no way to make
one carry a contrast tier — so every site reached through such an accessor would have
silently kept the standard palette under Increase Contrast. Those sites are the selection
fill, the progress fill and the offline ring: precisely the low-contrast furniture the
setting exists to strengthen. A feature that works everywhere except where it was needed
is worse than one that is off, because nobody checks.

So `PaletteColor.clear` exists to keep the ternaries in the token type, and the four
`Color`-typed members became `PaletteColor`-typed. `PaletteColor.color(in:)` remains for
genuine interop and takes the environment as an argument, so a call site cannot obtain a
`Color` without stating which appearance it is for. `.tint` needed no change at all: it
has a `ShapeStyle` overload.

### `\.colorSchemeContrast` is get-only, which is a problem for previews before it is one for tests

SwiftUI derives it from the system setting and offers no setter, so nothing can ask to
see the high-contrast palette — not a test, and not a preview. A design system whose
accessibility variant is only visible after changing a system-wide setting and relaunching
is one nobody will look at.

Hence `\.paletteContrastOverride` and the `paletteContrast(_:)` view modifier. `nil` — the
default, and what the app runs at — follows the system. The contrast suite sets it, and so
can any of the 57 previews.

That override is also what the suite's honesty depends on, so it has its own guard.
`contrastTiersActuallyDiffer` asserts that every token declaring a variant resolves
differently between the two tiers. Without it, a renamed key or a lost `nonisolated`
would make the AAA suite measure the standard palette against a 7:1 floor — and most
tokens would still pass, because most already clear 7:1 on dark. That is the failure this
correction warned about in its first version, and it is now a test rather than a comment.

## Pinned context: the progress strip is not part of the list

**A3's pinned-context rule, and the artboards were right the first time.**

Every screen is the same three parts — a header, some context describing the whole
screen, and one collection — and until this was written down each screen answered the
question differently. The device list pinned its column headers and its partial-run
strip. Live Scan put the stage strip and the degradation banner *inside* its scroll view.
Activity did the same with the histogram.

**The rule: the header and any context that describes the whole screen are pinned. Only
the collection scrolls.**

| Screen | Pinned | Scrolls |
|---|---|---|
| Devices | title, search, Scan Now, partial-run strip, column headers | the rows |
| Live scan | title, Stop Scan, the stage strip, the degradation banner | "found so far" |
| Activity | title, filter chips, the histogram | the day-grouped events |
| Device detail | back bar, Rename, Rescan | the cards |
| Settings | title and version | the sections |

Live Scan is the case that makes it obvious, and it is a behaviour bug rather than a
matter of taste. The stage strip slid out of view exactly when the found-list grew long
enough to scroll — which is exactly the moment a person most wants to know which stage is
running and what has already gone wrong. The screen was at its least informative
precisely when it had the most to say. The degradation banner went with it, so a scan
that had already lost mDNS could scroll that fact off the screen while the user watched
the list it had made incomplete.

Activity is the same argument in a different shape. The histogram summarises the window
the list beneath it is filtered to, and the two are required to agree — that agreement is
correction 3's whole point. A summary you have scrolled away from is not summarising
anything, and a person who scrolls back up to check the bars has lost their place in the
list to do it.

### Why `safeAreaInset` and not a `VStack` around a `ScrollView`

The obvious implementation is to lift the strip out of the scroll view and put both in a
`VStack`. That works and it costs something worth keeping: it makes the pinned block and
the scrolling block siblings, so the scroll view no longer knows the strip is there.

`safeAreaInset(edge: .top)` keeps **one scroll view per screen** and tells it what is
overlaying it. Scroll position, keyboard traversal, rubber-band behaviour at the top edge
and the scroll indicator's insets all stay the system's rather than being approximated —
and the content can still scroll *under* the strip, which is what makes it read as
pinned context rather than as a second header.

Nesting a scroll view inside a scroll view is the other tempting shape and is worse than
both: two scroll views compete for the same gesture, and which one moves depends on where
the pointer happens to be.

### The part that was missing

The rule and the implementation both landed with the review. This entry did not, and its
absence is the exact hazard the overview above describes: A3's pinned-context rule states
the rule, but a reader working from this article alone would have found four review-driven
corrections recorded and this one not. Recorded now.

## The screen header is a component, because four copies disagreed

**Found by running the app and looking at it.**

A1 gives `headerBlockHeight` as 87 and `contentInset` as 20 *horizontal*. It says
nothing about the padding above and below a screen title, so there was no answer to look
up, and the four screens that need a header each answered for themselves:

| | above | below |
|---|---|---|
| Devices, Activity | 20 | 12 |
| Settings, Live Scan | 16 | 16 |

Both come to 32, so the block is the same height on every screen and nothing reflows.
What moves is the title inside it, by four points, at the one moment a person is looking
at the sidebar rather than at the words — which is why it survived a design review and
was found by someone switching rooms in the built app.

`Metrics.headerBlockHeight` was declared and referenced by nothing at all, and is now deleted. That is the
same failure one step earlier: a number that describes no code cannot be wrong, and
cannot be right either.

The correction is not a third number. ``ScreenHeader`` owns the title, the subtitle and
every inset; a screen describes what belongs on the trailing edge and nothing else. A
screen cannot disagree with another screen about padding it does not write. The values
kept are the Devices screen's, because Devices is the screen A1 measured 87 from.

``DeviceDetailView`` keeps its own header deliberately. It is a different pattern — a
device-kind tile, a status dot on the title row, and an actions bar above it — and A3
describes it as one. It is not a fifth copy of this.

## An empty screen still scrolls, or the window loses its bars

**Found by using the app, and only findable that way.**

macOS draws the window's top and bottom bars — the scroll-edge effect, under
`.windowToolbarStyle(.unifiedCompact)` — over a detail column that *scrolls*. A screen
that is a `ScrollView` when it has rows and a plain view when it has none is two
different things to the window around it, so the bars appeared in some rooms and not
others, and the content expanded into the space they had occupied.

The symptom was not a missing scroll bar. It was the whole window's content jumping
upward on one room, which reads as the app twitching as you move between rooms.

Nothing about it is visible while writing either screen, because each one is correct on
its own. It shows only when you switch, and only on a machine where one room has data
and another does not — which is every machine, in its first minutes of use, when the
device list is full and nothing has changed yet. Activity is empty by design after a
first scan: events are differences between runs, so the first run makes none.

``ScreenScroll`` decides the container from the screen rather than from its contents. An
empty state still gets a scroll view; it simply has nothing to scroll. It needs
`containerRelativeFrame(.vertical)` inside it, because a scroll view offers unbounded
height and an empty state asking to fill would otherwise collapse to its natural size
and sit at the top rather than centred.

Applied to all four branches that did not scroll, not only the one that was reported:
Activity's "nothing has changed", and Devices' "no scan yet", "nothing answered" and
"no matches". The first is what a person meets on first launch and the last any time a
search filters everything out.

## Telling the canvas

Items 1, 5 and 7 are corrections, not forks. The design canvas should be updated so the
two stay in sync — otherwise the next export re-introduces a contrast failure that has
already been fixed once.
