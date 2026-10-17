# Building a screen

How the pieces compose, with the Devices room as the worked example.

## Overview

Every screen has three parts: what describes the whole screen, which is pinned; the
collection, which scrolls; and the states the collection can be in. A screen is built
from a platform control first, and the design spends itself only on what that control
does not cover.

### 1. Start from the platform control

Devices is a SwiftUI `Table` (`DevicesView.DeviceTableView`):
- `KeyPathComparator` sorting, defaulting to status, then last seen, newest first
- `Set<DeviceItem.ID>` selection
- `contextMenu(forSelectionType:)`, mirroring the menu bar's Device menu
- `.searchable` in the toolbar

Rows are column cells, never a hand-built row view.

### 2. Measure, don't declare

Every column but NAME sizes to its widest cell (`DevicesView.ColumnWidths`, from
`TextMeasure`); NAME takes the rest, never under `WindowSize.nameMinimum`. The window's
minimum width is computed from the same measurement plus the sidebar, so the split view
can never take the difference out of the sidebar.

### 3. Pin what describes the screen

Title, search, Scan Now, the partial-run strip and the column headers stay put; only the
rows scroll. Use `safeAreaInset(edge: .top)` for pinned context, so there is one scroll
view per screen.

| Screen | Pinned | Scrolls |
|---|---|---|
| Devices | title, search, Scan Now, partial-run strip, headers | rows |
| Live scan | title, Stop Scan, stage cards, degradation banner | found so far |
| Activity | title, filter, histogram | events by day |
| Device detail | back, Rename, Scan Ports | the cards |
| Settings | the version line | the sections |

### 4. Cells say what is known, never nothing

The NAME cell is two lines: the name ("Unidentified device" when there is none) and a
subtitle that is the facts we do have, in sentence case — "Randomized MAC · no vendor ·
responds to ping". Accessibility reads the row as one sentence: name, state, how well it
is identified, address, last seen.

### 5. Every state, from fixtures

Every state renders from `FixtureNetwork` alone — `home`, `unidentified`, `empty`,
`partial`, `silent`, over the anonymised home capture or, for marketing, the invented
showcase one — with no store and no network. If a state needs live data to look
right, it is not finished. <doc:StatesAndEmptiness> lists them.

### 6. Reach it from the menu bar and the keyboard

Every action is in `.commands`, reaching the window through `@FocusedValue`; frequent ones
have shortcuts (⌘1/⌘2 rooms, ⌘R scan, ⌘F find, ⌘O open, ⇧⌘R scan ports…). Every
interactive element has a stable camelCase accessibility identifier — they are the UI
tests' API.
