# Appendix A3 — Design System: Patterns and Screens

Read A1 and A2 first. This is where the tokens and components become the five
screens, and where the artboards get corrected for the fact that Omada is gone.

The six artboards in `Docs/Design/` are the visual reference. Keep them open beside you:

```
Docs/Design/01-devices-dark.png
Docs/Design/02-devices-light.png
Docs/Design/03-device-detail.png
Docs/Design/04-activity.png
Docs/Design/05-live-scan.png
Docs/Design/06-settings.png
```

Copy them into `ZhenDesign.docc/Resources/` so they render in the local docs
alongside the components they specify.

---

## Window

```swift
NavigationSplitView {
    Sidebar(selection: $room)
        .navigationSplitViewColumnWidth(Metrics.sidebarWidth)   // 228
} detail: {
    switch room {
    case .devices:  DeviceListView()
    case .activity: ActivityView()
    case .settings: SettingsView()
    }
}
```

`NavigationSplitView`, not a hand-rolled `HStack`. You get the sidebar toggle, the
correct material behind the traffic lights, keyboard traversal and state restoration
for free, and any hand-rolled version will be subtly wrong on at least one of them.

**Sidebar composition.** A section label "Zhen" in `sectionLabel`, then
rows at 28pt: symbol, title, trailing count in secondary. Selected row gets a
`selection` fill with 6pt radius, inset 8pt from both edges.

Pinned at the bottom, above a hairline: the scan status — a `StatusDot` and "Last
scan 4 min ago", then `10.10.20.0/24 · en0` in `.rowSubtitle`. During a scan the dot
turns accent and the text becomes "Scanning…". This footer is the only always-visible
proof the app is alive, so it is never empty; before the first scan it reads "Never
scanned".

### Sidebar rooms — a decision you need to make

The artboards show five: Devices, Activity, Events, Omada, Settings.

Omada is gone, so that room goes with it.

**Events and Activity are the same data.** Activity's own header says "12 events" and
the Events badge says 12 — one dataset, two doors, and only one of them was ever
designed. Fold Events into Activity and keep the filter chips that are already
there. That leaves:

```
Devices   square.grid.2x2.fill   count of known devices
Activity  waveform.path.ecg      count of events in the window
Settings  gearshape              no badge
```

Three rooms, each with a design. If you want Events back as a separate room later it
needs its own artboard and its own reason to exist.

---

## Devices

The default room. Header block is 87pt: title "Devices", subtitle
"6 devices · 5 online · 2 unidentified", `SearchField` and `PrimaryButton("Scan Now")`
trailing. Then the column header row, then rows at 52pt separated by hairlines.

**Column widths are measured, not declared.** *Changed in stage 2 of the responsive
work; this previously read "from the artboards at 1182pt: NAME flexible, IDENTITY 120,
IP ADDRESS 130, MAC ADDRESS 240, LAST SEEN 90 trailing".*

Every column except NAME sizes to the widest cell in it, header included, through
`deviceColumn` in `ZhenDesign/Layout/ColumnWidths.swift`. NAME stays flexible and
absorbs the remainder. Alignment is declared per column: LAST SEEN trails, the rest
lead.

The artboard numbers were right for the artboard and wrong for a real network. They
forced a table minimum the split view paid for out of the sidebar, which is defect F2,
and they put a 104pt floor under the IP column that a chip then overflowed. Removing
them dropped the Devices screen's required width from 956pt to 624.

The header is a **pinned section header inside the table's scroll view**, not a separate
view above it. It has to be, for the columns to agree: a `Grid` sizes columns among its
own rows, and a header in a different view tree can only agree with the rows by both
being told the same numbers, which is the thing being removed.

**Bindings.**

| Column | Source |
|---|---|
| status dot | `device.isOnline` — replied in the most recent run |
| name | `device.names.best?.value`, else "Unidentified device" |
| subtitle | model · vendor when known; otherwise what *is* known — "Randomized MAC · no vendor · responds to ping" |
| identity | `device.identification` — never `identityStability`, see A2's ConfidenceMeter |
| IP | `device.ip`, at full strength only when the device answered — see below |
| MAC | `device.mac`, with `Chip("private")` when `mac.isLocallyAdministered` |
| last seen | `device.lastSeen`, relative |

**States.**

- *Never scanned* — the "No scan yet" empty state from A2's empty states, with Scan Now.
- *Scanning, first run* — rows stream in as hosts answer. Never a spinner over an
  empty table; the first host should be on screen within about 100 ms, which is the
  entire reason core exposes a streaming API.
- *Loaded* — as drawn.
- *Loaded from a partial run* — **the artboards have no state for this and they need
  one.** When the last run hit its deadline or lost a capability, the footer dot turns
  amber and a single-line strip sits under the header: "Last scan completed with
  partial results — 2 sources unavailable" with a disclosure that opens the same
  `DegradationBanner` rows the live scan showed. Degradations do not evaporate when
  the scan ends; a green dot over an incomplete scan is a lie of omission.
- *Search with no match* — "No matches" empty state, header counts unchanged.
- *Two rows at one address* — **added after the running app showed it.** A DHCP lease
  moves, and the list then holds two records at one address: one that answered in the
  last run and one that last answered hours ago. Both rows stay. The ledger is right to
  keep them apart — its anti-collapse guard refuses to join two devices on a shared
  lease, because devices swapping leases must never merge — and the list has to make
  that legible rather than look broken.

  The address is the loudest thing in the row, so it carries full strength **only when
  the device answered**. An absent device's address renders in secondary ink, and when
  a device that did answer is at that address now, the absent row carries
  `Chip("reassigned")` **on its own line beneath the subtitle**, in the name column.

  Not in the IP column, which is `ipMin` 104 — a dotted quad and nothing else — where a
  chip wrapped the address mid-octet and made the one row this exists to explain the
  only one whose address did not read as an address. Not beside LAST SEEN either, which
  is tighter still at 64. And not sharing the subtitle's line: measured, that row wants
  1046pt against a declared minimum window of 1000, so the subtitle pays for the chip by
  truncating, which is the loss `Column.nameMin = 200` was measured to prevent. On its
  own line the row wants 967pt and the chip costs no width at all.

  The name column is the right home on meaning as well as on measurement. The subtitle
  is what IS known about a device — "randomized MAC · no vendor · in ARP table, no ping
  reply" — and an address that has since been taken is a fact of exactly that kind, in
  exactly that register.

  That chip asserts exactly one thing: the address moved, which the app watched happen.
  It does not say the two records are the same machine. They may be one phone rotating
  a private address or two unrelated hosts, and nothing observed so far separates those
  — so nothing in the row claims to.

  Never merge the rows, never hide one, never reorder to hide the repetition. A device
  that stopped answering keeps its row and its last known address; "seen fourteen hours
  ago" is information, and dropping the row would shrink the network silently.

The column headers look sortable and aren't. Either make them sortable — with a
`chevron.up`/`chevron.down` on the active column — or make them plainly static. Do
not ship something that invites a click and swallows it.

---

## Device detail

Pushed from a row. Header: back button "← Devices", title row with a device-kind
symbol in a 44pt rounded square in `surfaceRaised`, the name, a `StatusDot` with
"Online", and a subtitle line — "MacBook Pro 14″ · Apple · macOS 15.6 (OS hint, TCP
fingerprint) · Identified — 3 of 4 sources agree". Trailing: IP, current MAC with its
`private` chip, first seen. Top right: **Rename…** and **Rescan Device**.

**Rename is local only.** There is no controller to write back to. The renamed value
is stored as a user-supplied name that outranks every discovered source, and the
detail view shows it as such in "Known by" — source "You", always the winner. Making
that visible is what stops a user wondering why their name stuck.

### The layout without Omada

The artboards use two columns: cards on the left, an Omada panel and recent events on
the right. Remove the Omada panel and the right column is half empty, so **reflow to
a single column of cards at content width**, in this order:

1. **Identity history** — one row per MAC with the reason it merged and a date range.
   The dot on the current row is accent; the rest are secondary. This card carries
   `identityStability` in its caption — "identity key: rotating MAC, stabilised by
   Bonjour name" — because a person who opened this card is asking exactly that
   question. It appears nowhere else in the app.
2. **Known by** — every name source, its candidate, and a `Chip("winner", .accent)`
   on the one that won. Sources that offered nothing show "— not advertised" in
   secondary. Do not hide them; the absence is information.
3. **Open ports** — port in mono, service, product/version. Caption carries the
   freshness: "last deep scan 22 min ago".
4. **Recent events** — the last few events for this device, same `EventRow` as
   Activity, with a link to Activity filtered to this device.

**States.** Never deep-scanned → the ports card shows "No port scan yet" with a
**Scan ports** button. No merge history → the identity card shows the single MAC and
a caption "No identity changes seen". Offline → status dot hollow, header subtitle
becomes "Last seen 2 h ago", actions stay enabled because rescanning an offline
device is exactly what you'd want to do.

---

## Activity

Header: "Activity", "Last 48 hours · 12 events", filter chips trailing — All,
Appearances, Identity, Ports, Network. Then the `TimelineHistogram`, then events
grouped under day headers in `sectionLabel`: "TODAY — SUNDAY, AUG 31".

Bindings are the derived event log, filtered by kind and window. Selecting a chip
filters both the list and the histogram — if the histogram keeps showing all events
while the list is filtered, the two stop agreeing and the screen loses its meaning.

**States.** No events at all → "Nothing has changed" empty state. Filter with no
matches → keep the chips and histogram, show "No <kind> events in this window".
Fewer than two hours of history → histogram hides rather than drawing three lonely
bars; the list stands alone.

---

## What is pinned and what scrolls *(added after review)*

Every screen has the same three parts, and until this rule was written down each screen
answered the question differently: the device list pinned its column headers, the live
scan let its stage strip scroll away, and Activity let the histogram go with it.

**The rule: the header and any context that describes the whole screen are pinned. Only
the collection scrolls.**

| Screen | Pinned | Scrolls |
|---|---|---|
| Devices | title, search, Scan Now, partial-run strip, column headers | the rows |
| Live scan | title, Stop Scan, the stage strip, the degradation banner | "found so far" |
| Activity | title, filter chips, the histogram | the day-grouped events |
| Device detail | back bar, Rename, Rescan | the cards |
| Settings | title and version | the sections |

The live scan is the case that makes it obvious. The stage strip slid out of view
exactly when the found-list grew long enough to scroll — which is exactly the moment a
person most wants to know which stage is running and what has already gone wrong. The
histogram is the same argument: it summarises the window the list beneath it is filtered
to, and a summary you have scrolled away from is not summarising anything.

Use `safeAreaInset(edge: .top)` rather than nesting a scroll view inside a `VStack`. It
keeps one scroll view per screen, so scroll position, keyboard traversal and rubber-band
behaviour stay the system's rather than being approximated.

---

## Live scan

Replaces the Devices content while a scan runs. Header: "Scanning 10.10.20.0/24",
subtitle "Stage 2 of 3 · 0:47 elapsed · 4 devices so far", **Stop Scan** trailing.

**Three stages now, not four** — Omada's is gone: Discovery, Naming, Deep scan. The
`StageCard` strip spans the content width, the running card carries the accent border.

Below: the `DegradationBanner` when anything degraded, then "Found so far · newest
first" with rows arriving as they answer. A host still being named shows its name
slot in italic secondary — "Resolving name…" — with a `.rowSubtitle` explaining what
is in flight: "found 4 s ago · NetBIOS query in flight".

That italic placeholder is worth the effort. It's the difference between a scanner
that looks like it's thinking and one that looks stuck.

**States.** Starting, before anything answers → all stage cards queued, list shows
"Listening…". Every stage done → the screen hands off to Devices automatically; don't
make the user dismiss it. Stopped by the user → keep the partial results on screen
with "Stopped after 0:47 · 4 devices found" and a **Scan Again** button. Nothing is
discarded because someone pressed stop.

---

## Settings

Sections in this order, Omada removed entirely:

**SCANNING** — Scan automatically (menu: Off, 5 / 15 / 60 minutes), Subnet (static
value with "auto, from en0" caption plus an override), Deep-scan new devices
(toggle with explanation).

**HISTORY** — Keep events for (menu), Device identity history (static: "Kept forever
— it's what makes merges possible").

**PRIVILEGED ENGINE** — the helper. Title, a paragraph in `.rowSubtitle` explaining
in plain words what it does and what it can't, current state, and the action.

The helper panel is the one place in this app where the writing matters more than the
layout, so the copy is specified, not left to the implementer:

> **Use the privileged engine**
> OS fingerprinting and fast SYN port scans need raw network sockets, which macOS
> only grants to root. The engine is a small helper that runs only during scans and
> only sends results back to this app. Everything else works without it.
> **Not installed.** [Install Helper…]

Once installed, the state line becomes "Installed · Zhen Scan Engine" with two
buttons: **Show in System Settings…** and **Remove**. The first calls
`SMAppService.openSystemSettingsLoginItems()` so the user can verify our claim in the
OS rather than believing us, and the second is always present. An installer without
an uninstaller beside it is how software earns distrust.

**There is a third state and it was missing.** `SMAppService` returns
`requiresApproval` when the daemon is registered with launchd and waiting for the
person to allow it in Login Items. That was folded into the unavailable case, whose
headline reads "Not installed." — so the app said the helper was absent and then, in
the next sentence, told the reader to go and approve it. Somebody who reads the
headline does not read on.

It is now its own state: an amber dot, "Installed · waiting for your approval", the
sentence saying where to go, and **Open Login Items…** as the primary button with
**Remove** beside it. The actions differ from every other state, which is why it
cannot be a variant of one: there is nothing left to install, the useful button is the
one that opens the pane, and a registration exists to be removed.

**Settings has no Test Connection button any more** — that belonged to the
controller. The scanning section's only verification is running a scan.

---

## The DocC article set

This is what "documentation you can render locally" means concretely. In
`ZhenDesign.docc`:

```
ZhenDesign.md          landing: what this is, read order, the three appendices
Foundations.md              A1 — colour, type, metrics, symbols, motion, a11y
Components.md               A2 — catalogue, each entry linking its symbol page
Articles/
  BuildingAScreen.md        how patterns compose, using Devices as the worked example
  StatesAndEmptiness.md     every empty, partial and error state in one place
  Accessibility.md          A1's accessibility floor, with the contrast table
  Corrections.md            where we deliberately differ from the artboards, and why
Resources/
  *.png                     the six artboards
```

`Corrections.md` matters more than it sounds. Four deliberate divergences so far —
the two contrast tokens, the offline row keeping its name at full contrast, the
partial-run strip on Devices, and the hedged permission copy. Written down, they're
decisions. Undocumented, the next person "fixes" them back to match the artboards.

Build it with:

```bash
swift package --disable-sandbox preview-documentation --target ZhenDesign
```

---

## Definition of done

The design system is finished when:

- Every component in A2 exists with previews in both themes, and the previews use the
  real device fixtures — including the curly apostrophe in "JC's MacBook Pro" and a
  fully unidentified host.
- No hex literal, no font size and no magic number appears anywhere outside
  `Tokens/`. Grep for `Color(red:` and `Font.system(size:` outside that folder; both
  should return nothing.
- Every screen in A3 renders from fixtures alone, with no store and no network. If a
  screen needs live data to look right, its states aren't finished.
- The DocC archive builds and every page has content.
- Someone who has never seen the artboards can build a new screen from this appendix
  and have it look like it belongs.

Only then open document 03 and start wiring it to real data.
