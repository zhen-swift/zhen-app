# Components

The pieces every screen is built from, and what each one is for.

## Overview

Phase 1 built nothing a platform control already does. A list of devices is a `Table`, a
form is a `Form`, an empty screen is a `ContentUnavailableView`, search is `.searchable`.
What is here is what the platform does not provide.

| Component | Use it for | Not for |
|---|---|---|
| ``StatusDot`` | presence, or an event's kind, as a mark beside text | the only carrier of a meaning — it always has words beside it, and a shape of its own when colour cannot be relied on |
| ``Chip`` | a short qualifier: `private`, `reassigned`, `winner` | a button, or a count |
| ``SignalMeter`` | how well a device is identified (`Identification`), in bars beside a word | identity-key stability, which only the detail's identity card shows |
| ``Card`` | a titled block of the detail and the live scan, with a caption that teaches what it holds | grouping that a `Form` section or a list section already gives |
| ``KeyValueGrid`` | the detail's addresses: label, value, optional chip | anything with more than two columns |
| ``StageCard`` | one stage of a scan: queued, running with progress, done, or not requested | progress that is not a scan stage |
| ``DegradationBanner`` | what went wrong in a scan, in plain words, with the one action that helps | errors that stop the app; nothing here is a modal |
| ``EventRow`` | one change: time, kind, sentence | a device row — that is the `Table` |
| ``TimelineHistogram`` | events per hour over 48 hours, following Activity's filter | a chart that does not summarise the list beneath it |
| ``PrimaryButton`` | the screen's one prominent action, with its words | secondary actions, which are plain buttons |
| ``PressButtonStyle`` | the pressed feedback for borderless buttons | — |

Two view modifiers carry type roles: `sectionLabel()` and `numericValue()`
(<doc:Foundations>).

### Rows are table cells

A2 specified a hand-built `DeviceRow`. It is not built, on purpose: rows are `Table` column
cells (`DevicesView`), so sorting, selection, keyboard navigation and column sizing are
AppKit's. A hand-built row is what the previous app was demolished for.

### Previews

Every component has `#Preview`s in light and dark, fed by `PreviewContainer`'s fixture
network — never inline sample data that drifts from the real shapes.

## Topics

### Marks and qualifiers

- ``StatusDot``
- ``Chip``
- ``SignalMeter``

### Containers

- ``Card``
- ``KeyValueGrid``
- ``StageCard``
- ``DegradationBanner``

### Activity

- ``EventRow``
- ``TimelineHistogram``

### Actions

- ``PrimaryButton``
- ``PressButtonStyle``
