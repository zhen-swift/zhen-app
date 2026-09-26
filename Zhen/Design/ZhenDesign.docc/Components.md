# Components

Every reusable piece, its anatomy, and the states it must handle.

## Overview

One rule governs all of them: **every component takes a value type and renders it.** None
fetch, none own a task, none know a store exists. If a component needs data it does not
have, it gains a parameter — never an environment object. That is what makes them
previewable, and previews are how this work is checked against the artboards.

Build order matters: later components compose earlier ones.

## The smallest pieces

``StatusDot`` is 8pt and the thing people read first. Online is filled, offline is a
hollow ring — **shape carries the meaning so colour does not have to**, which is what
lets it pass the "no state is colour-only" floor without a label beside every dot.

``ConfidenceMeter`` is three ascending bars and a word. It is the one piece of
iconography that is not an SF Symbol, because the number of filled bars is data.

``Chip`` is the small uppercase pill: `GATEWAY` and `WINNER` in accent, `private` in
neutral. The `private` chip does real work — it says this hardware address is randomised
and therefore not a stable identity — so it belongs beside the address it qualifies,
never in a column of its own.

## The row

``DeviceRow`` is the heart of the app: two lines, five columns, 52pt minimum.

@Row {
    @Column {
        ![The devices list, dark](artboard-devices-dark)
    }
    @Column {
        ![The devices list, light](artboard-devices-light)
    }
}

Its states, in the order they matter:

- **Online, unidentified.** The name reads "Unidentified device" and the subtitle carries
  what *is* known — "Randomized MAC · no vendor · responds to ping". No placeholder
  dashes, no collapsed row, no error styling. **This is the acceptance case**, and on the
  reference network it is seven rows out of ten.
- **Online, identified.** Everything at full strength.
- **Offline.** Hollow dot, relative last-seen, secondary content dimmed — and **the name
  stays at full contrast**. See <doc:Corrections>.
- **Selected.** ``Palette/selection`` fill at ``Metrics/selectionRadius``.

``DeviceTableHeader`` is plainly static. The headers look sortable and are not, so they
carry no chevron: a header that invites a click and swallows it is worse than one that
never suggested it.

## Containers

``Card`` is `surfaceRaised` with a hairline border and an optional title plus caption.
The caption pattern is worth copying everywhere — "Known by · competing names by source —
highest-trust source wins" teaches a person what they are looking at without a tooltip, a
help button or a manual.

``CardRows`` separates a list with hairlines and leaves the last one off, which is the
single most common way a card ends up with a stray line above its bottom edge.

``KeyValueGrid`` is a real `Grid` so values align across rows. Missing values render an
em dash, never an empty cell: an empty cell looks like a bug, a dash looks like an answer.

## Controls

``PrimaryButton`` takes its label colour from ``Palette/onAccent`` rather than a literal
white, because the correct answer differs by theme. ``SecondaryButton`` and ``LinkButton``
cover the quieter actions. ``SearchField`` exists only for the one place the artboards put
a field inline in a header row — prefer `.searchable` everywhere else.

## The scan

``StageCard`` shows one of three stages. The running card carries a 1pt accent border,
and that border is the difference between three cards and one card that is clearly *now*.

![The live scan](artboard-live-scan)

``DegradationBanner`` is the most important component in the app and the easiest to get
wrong. Three rules: say the consequence not the error; hedge what was inferred; never a
modal. Amber, not red — nothing here is broken. ``PartialRunStrip`` carries the same rows
into the device list after the scan ends, because degradations do not evaporate when a
run finishes.

## Activity

``EventRow`` mixes weights inside one sentence — the device name at full strength, the
rest secondary — because the name is what the eye hunts for. ``EventPalette`` decides its
colour, splitting mark from label for contrast reasons.

``TimelineHistogram`` draws hourly buckets with **no axis**, deliberately: the bars are a
rhythm, not a measurement, and an axis invites reading a precision that is not there.

![Activity](artboard-activity)

## Settings

Three shapes cover the whole screen: ``ToggleRow``, ``MenuRow`` and ``StaticRow``, grouped
under a ``SectionLabel`` inside one ``Card``. That is the standard macOS settings grammar,
which is the point — nobody should have to learn this screen.

![Settings](artboard-settings)

## Emptiness

``EmptyStateView`` covers every list. See <doc:StatesAndEmptiness> for the full set and
why ``EmptyStateView/nothingAnswered`` is the one that matters most.
