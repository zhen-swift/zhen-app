# Building a screen

How tokens and components compose, using the Devices room as the worked example.

## Overview

Someone who has never seen the artboards should be able to build a new screen from this
system and have it look like it belongs. This article is the recipe.

## The window

``ZhenWindow`` is a `NavigationSplitView`, not a hand-rolled `HStack`. The sidebar
toggle, the correct material behind the traffic lights, keyboard traversal and state
restoration all come free, and a hand-rolled version is subtly wrong on at least one.

```swift
NavigationSplitView {
    Sidebar(selection: $room, deviceCount: …, eventCount: …, activity: …, target: …)
        .navigationSplitViewColumnWidth(Metrics.sidebarWidth)
} detail: {
    switch room {
    case .devices:  DeviceListView(state: …)
    case .activity: ActivityView(days: …, buckets: …)
    case .settings: SettingsView()
    }
}
```

### Three rooms, not five

The artboards show Devices, Activity, Events, Omada and Settings. Omada is dropped from
the project. Events and Activity are the same dataset behind two doors — Activity's header
says "12 events" and the Events badge says 12 — and only one of them was ever designed, so
Events folds into Activity and keeps the filter chips already there. If Events comes back
as a room it needs its own artboard and its own reason to exist.

## The screen skeleton

Every room has the same three parts, and building them in this order keeps the spacing
consistent without measuring anything:

1. **A header block.** Title in `Font.screenTitle`, subtitle in `Font.screenSubtitle`
   secondary, controls trailing. Inset ``Metrics/contentInset``.
2. **A hairline**, then any column header or filter strip.
3. **Content**, which is either the data or an empty state — never a blank area.

```swift
VStack(spacing: 0) {
    header                                    // title, subtitle, controls
    Divider().overlay(Palette.separator)
    content                                   // rows, or an EmptyStateView
}
.background(Palette.surface)
```

## Binding the device row

Every column in ``DeviceRow`` answers to exactly one source, and two of them are worth
stating because they are easy to get wrong.

| Column | Source |
|---|---|
| status dot | replied in the most recent run |
| name | the winning name candidate, else "Unidentified device" |
| subtitle | model · vendor when known; otherwise what *is* known |
| identity | ``Identification`` — **never** identity-key stability |
| IP | the address |
| MAC | the hardware address, with `private` when locally administered |
| last seen | relative |

The identity column is the one that trips people. ``Identification`` asks *how well do we
know what this thing is*. Identity-key stability asks *how likely is this record to
fragment*, and it appears in exactly one place in the whole app: the device detail's
identity card. That is why the gateway — whose hardware MAC never changes, but which
nothing named — reads **Partial**, while a MacBook with a rotating private MAC and a clean
Bonjour name reads **Identified**.

## Composing the detail screen

The artboards use two columns, with an Omada panel filling the right one. With Omada gone
the right column is half empty, so the detail reflows to a **single column of cards** at
``Metrics/Detail/contentMaxWidth``, in this order: identity history, known by, open ports,
recent events.

![Device detail](artboard-device-detail)

A two-column layout with one column holding a single short card looks like something
failed to load. One column at a readable width does not.

## What to reach for

- A container → ``Card``, with a caption that teaches.
- A list inside it → ``CardRows``.
- Facts in pairs → ``KeyValueGrid``.
- Nothing to show → ``EmptyStateView``, never a blank area.
- A dimension → ``Metrics``. If the value you want is not there, add it there rather than
  inlining it.
