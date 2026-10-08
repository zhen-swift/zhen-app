# Appendix A2 — Design System: Components

Read A1 first — everything here uses its tokens and none of it hard-codes a value.

Each component below gives you the anatomy, the states it must handle, and the code.
Build them in this order; later ones compose earlier ones.

A rule before you start: **every component takes a value type and renders it.** None
of them fetch, none of them own a task, none of them know a store exists. If a
component needs data it doesn't have, add a parameter — don't reach for an
environment object. That's what makes them previewable, and previews are how you'll
actually check this work against the artboards.

---

## StatusDot

The smallest thing in the app and the one people read first.

**Anatomy.** An 8pt circle. Online is filled `Palette.Status.online`; offline is a
1.5pt hollow ring in `offlineRing`. Shape carries the meaning so colour doesn't have
to.

```swift
public struct StatusDot: View {
    public enum State { case online, offline, scanning }
    private let state: State

    public init(_ state: State) { self.state = state }

    public var body: some View {
        Group {
            switch state {
            case .online:
                Circle().fill(Palette.Status.online)
            case .offline:
                Circle().strokeBorder(Palette.offlineRing, lineWidth: 1.5)
            case .scanning:
                Circle().fill(Palette.accent)
            }
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)   // the row's combined label already says it
    }
}
```

Don't animate the scanning state with a pulse. You'll have six of them on screen and
it turns the window into a Christmas tree.

---

## ConfidenceMeter

Three ascending bars, filled to match confidence, with the word beside them. This is
the one piece of iconography that isn't an SF Symbol, because the number of filled
bars is data.

**Anatomy.** Three 3pt-wide bars, heights 6/9/12, 2pt gaps, bottom-aligned. Filled
bars use `Palette.accent`; unfilled use `separator`.

**States.** `identified` (3), `partial` (2), `minimal` (1). The label sits 6pt to the
right in `.rowSubtitle`, primary colour when identified, secondary otherwise.

```swift
public struct ConfidenceMeter: View {
    public enum Level: Int { case minimal = 1, partial = 2, identified = 3

        var label: String {
            switch self {
            case .minimal: "Minimal"
            case .partial: "Partial"
            case .identified: "Identified"
            }
        }
    }

    private let level: Level
    public init(_ level: Level) { self.level = level }

    public var body: some View {
        HStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...3, id: \.self) { bar in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(bar <= level.rawValue ? Palette.accent : Palette.separator)
                        .frame(width: 3, height: CGFloat(3 + bar * 3))
                }
            }
            Text(level.label)
                .font(.rowSubtitle)
                .foregroundStyle(level == .identified ? Palette.textPrimary : Palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Identity confidence: \(level.label)")
    }
}
```

**What this meter shows, precisely.** It is bound to `device.identification` — how
well we know *what the thing is* — and never to identity-key stability. That is why
the gateway, whose hardware MAC is rock solid but which we could only name from its
model string, reads **Partial**, while a MacBook with a rotating private MAC that
advertises a clean Bonjour name reads **Identified**. That isn't a bug in the
artboards; it is the only reading that means anything to a person looking at a list
of their own devices.

The engineering quantity still exists — `identityStability` — and it surfaces in the
device detail's identity history card, where someone who came looking for it will
find it. Everyday surface gets the human answer; the pro answer moves one level in.

The view takes a `Level` from the caller either way, so neither definition leaks
into it.

---

## Chip

Small uppercase pill. Three flavours in the artboards: `GATEWAY` (accent-tinted),
`private` (neutral), `WINNER` (accent-tinted).

**Anatomy.** `.badge` font, 6pt horizontal / 2pt vertical padding, `chipRadius` 5.
Neutral uses `surfaceField` with secondary text; accent uses a 20%-opacity accent
fill with accent text.

```swift
public struct Chip: View {
    public enum Style { case neutral, accent }
    private let text: String
    private let style: Style

    public init(_ text: String, style: Style = .neutral) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(.badge)
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(style == .accent ? Palette.accent : Palette.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Metrics.chipRadius)
                    .fill(style == .accent ? Palette.accent.opacity(0.2) : Palette.surfaceField)
            )
    }
}
```

The `private` chip is doing real work — it tells the user this MAC is randomised and
therefore not a stable identity. Keep it next to the address it qualifies, never in
its own column.

---

## DeviceRow

The heart of the app. 52pt tall, two lines, five columns.

**Anatomy, left to right:** status dot (16pt gutter) · name over subtitle ·
confidence meter · IP (mono) · MAC (mono) with optional `private` chip · last-seen,
trailing-aligned in secondary.

**States.**

- *Online, identified* — everything at full strength.
- *Online, unidentified* — name reads "Unidentified device", subtitle carries what we
  do know: "Randomized MAC · no vendor · responds to ping". **This is the acceptance
  case.** No placeholder dashes, no collapsed row, no error styling.
- *Offline* — hollow dot, last-seen shows relative time. Dim the secondary content;
  **keep the name at full contrast.** The artboards dim the whole row, which makes an
  offline device read as disabled rather than as "seen two hours ago". This is a
  deliberate correction.
- *Selected* — `selection` fill, full-bleed, 6pt corner radius.

```swift
public struct DeviceRow: View {
    private let device: DeviceRowModel   // a flat view model, not the store type

    public var body: some View {
        HStack(spacing: 0) {
            StatusDot(device.isOnline ? .online : .offline)
                .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)   // full strength even offline
                Text(device.subtitle)
                    .font(.rowSubtitle)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ConfidenceMeter(device.identification).frame(width: 120, alignment: .leading)

            Text(device.ip).font(.mono).frame(width: 130, alignment: .leading)

            HStack(spacing: 6) {
                Text(device.mac).font(.mono).foregroundStyle(Palette.textSecondary)
                if device.isPrivateMAC { Chip("private") }
            }
            .frame(width: 240, alignment: .leading)

            Text(device.lastSeen)
                .font(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, Metrics.rowInset)
        .frame(minHeight: Metrics.tableRowHeight)   // minimum, so Dynamic Type can grow it
        .opacity(device.isOnline ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(device.accessibilityDescription)
    }
}
```

`minHeight`, not `height`. Fixed heights and Dynamic Type are enemies.

Give the row an accessibility label that reads like a sentence: *"JC's MacBook Pro,
online, identified, 10.10.20.3, last seen now."* Not five separate elements the user
has to swipe through.

---

## Card

The container used throughout device detail and settings.

**Anatomy.** `surfaceRaised` fill, `cardRadius` 10, hairline `separator` border, 16pt
padding. Optional header: title in `.rowTitle` with a trailing caption in
`.rowSubtitle` secondary — "Identity history · 4 MAC addresses — private Wi-Fi
address rotation".

```swift
public struct Card<Content: View>: View {
    private let title: String?
    private let caption: String?
    @ViewBuilder private let content: () -> Content

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.rowTitle).foregroundStyle(Palette.textPrimary)
                    if let caption {
                        Text(caption).font(.rowSubtitle).foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                Divider().overlay(Palette.separator)
            }
            content()
        }
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius).fill(Palette.surfaceRaised))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius)
                .strokeBorder(Palette.separator, lineWidth: 1)
        )
    }
}
```

The caption pattern is worth copying everywhere. "Known by · competing names by
source — highest-trust source wins" teaches the user what they're looking at without
a tooltip, a help button, or a manual.

---

## KeyValueGrid

Two-column label/value used by the device detail panels and settings.

**Anatomy.** Label in `.columnHeader` (uppercase, tertiary), value in `.rowTitle` or
`.mono` if it's an address. 12pt row spacing, 24pt column gap. Use `Grid` so values
align across rows.

```swift
Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
    ForEach(pairs) { pair in
        GridRow {
            Text(pair.label).font(.columnHeader).textCase(.uppercase)
                .foregroundStyle(Palette.textSecondary)
            Text(pair.value).font(pair.isAddress ? .mono : .rowTitle)
                .foregroundStyle(Palette.textPrimary)
        }
    }
}
```

Missing values show an em dash `—` in secondary, never an empty cell. An empty cell
looks like a bug; a dash looks like an answer.

---

## PrimaryButton and SearchField

**PrimaryButton** — "Scan Now", "Test Connection". Accent fill, white-on-accent in
light, `surface`-on-accent in dark, `fieldRadius` 6, 13pt semibold, 12/6 padding.
Both directions pass contrast comfortably.

**SearchField** — `surfaceField` background, `magnifyingglass` leading in secondary,
placeholder in secondary, `fieldRadius` 6, 28pt tall. Wire it to `.searchable` where
the platform allows; use the custom one only where the artboard puts it inline in a
toolbar row.

---

## StageCard

The four-across strip on the live scan screen.

**States.** `queued` — `circle` symbol, secondary text, empty track. `running` —
indeterminate accent fill, accent border on the card, symbol is a spinner.
`done` — `checkmark.circle.fill` in `online`, full green track, secondary detail text.

**Anatomy.** Card with title row (symbol + name), a detail line in `.rowSubtitle`, and
a 3pt progress track pinned to the bottom with 2pt radius.

```swift
public struct StageCard: View {
    public enum State { case queued, running(Double?), done }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .foregroundStyle(symbolColor)
                    .imageScale(.medium)
                Text(stage.title).font(.rowTitle)
                    .foregroundStyle(state.isQueued ? Palette.textSecondary : Palette.textPrimary)
            }
            Text(stage.detail).font(.rowSubtitle).foregroundStyle(Palette.textSecondary)
            ProgressTrack(state: state)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Give the running stage a 1pt accent border so the eye lands on it immediately. The
artboards do this and it's the difference between four cards and one card that's
clearly *now*.

---

## DegradationBanner

The most important component in the app, and the easiest to get wrong.

**Anatomy.** A card whose header is a `warning` dot, the title "Running with partial
results", and the caption "results are still valid, just less complete". Underneath,
one row per degradation: bold cause, then plain-language consequence, then a trailing
link button.

```
mDNS unavailable — Local Network permission appears to be denied, so Bonjour
names can't be read this scan.                        [Open System Settings…]
```

Three rules:

**Say the consequence, not the error.** "Bonjour names can't be read this scan" is
useful. "mDNS: EPERM" is not.

**Hedge what you inferred.** We can't query the Local Network grant — we infer denial
from finding nothing by ICMP while the neighbour table is populated. So the copy says
"appears to be denied". The artboards say "was denied", which claims certainty we
don't have. Correct it. A tool that quietly overstates one thing has its other claims
doubted.

**Never a modal.** These arrive mid-scan and the scan is still useful. An alert would
interrupt the thing the user is watching to tell them it's going slightly worse than
planned.

Amber, not red. Nothing here is broken.

---

## EventRow and TimelineHistogram

**EventRow** — time in mono secondary (60pt) · coloured dot · kind label in
`.columnHeader` uppercase and the kind's colour (140pt) · description with the device
name in primary and the rest in secondary.

The colour and symbol per kind come from A1's `Symbols` and palette: appeared green,
disappeared secondary grey, ipChanged info blue, merged accent purple, port events
warning amber, renamed accent.

Mixing weights inside one description string is what makes the list scannable — the
device name is what the eye hunts for:

```swift
Text(device).font(.rowTitle).foregroundStyle(Palette.textPrimary)
+ Text(" " + rest).font(.rowSubtitle).foregroundStyle(Palette.textSecondary)
```

**TimelineHistogram** — hourly buckets over the visible window, bars in accent with
the busiest bucket at full opacity and the rest at 60%, 3pt gaps, 2pt radius, hour
labels every six hours in `.columnHeader`.

Hover shows a count. Don't add an axis: the bars are a rhythm, not a measurement, and
an axis invites reading precision that isn't there.

---

## Settings rows

Three shapes cover the whole Settings screen: **toggle row** (title, optional
explanation underneath, trailing `Toggle`), **menu row** (title, trailing `Picker`
with `.menu` style), **static row** (title, trailing value in secondary, sometimes
with a trailing explanation like "Kept forever — it's what makes merges possible").

Group them under `sectionLabel` headers with 24pt above and 8pt below, rows separated
by hairlines inside a single `Card`. That's exactly the standard macOS settings
grammar, which is the point — nobody should have to learn this screen.

---

## Empty states

Every list needs one, and the artboards don't show any. Same skeleton each time:
symbol in secondary at `.imageScale(.large)`, a title in `.rowTitle`, one line of
explanation in `.rowSubtitle`, and an action button when there's something useful to
do.

| Where | Title | Explanation |
|---|---|---|
| Devices, never scanned | "No scan yet" | "Run a scan to see what's on your network." + **Scan Now** |
| Devices, scan found nothing | "Nothing answered" | "The scan completed but no devices replied. This usually means the Local Network permission is denied." + **Open System Settings…** |
| Devices, search no match | "No matches" | "No device matches '<term>'." |
| Activity, no events | "Nothing has changed" | "Events appear here when devices join, leave, or change." |

That second one is doing real work. An empty device list with no explanation is the
single most likely way a new user concludes the app is broken, when in fact the OS
withheld a permission nobody told them about.

---

## Previews are part of the deliverable

Every component ships with previews in both themes and, where it matters, at a large
Dynamic Type size:

```swift
#Preview("DeviceRow — dark") {
    VStack(spacing: 0) {
        DeviceRow(.identifiedSample)
        DeviceRow(.unidentifiedSample)
        DeviceRow(.offlineSample)
    }
    .frame(width: 900)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}
```

Keep the sample models in the design module as static fixtures, and **use the real
device data** — "Sala de entretenimiento", "JC's MacBook Pro" with its curly
apostrophe, `AppleTV5,3`, the randomised MACs. Lorem ipsum hides exactly the problems
this design has to solve: long Spanish names, non-ASCII punctuation, and rows where
almost every field is empty.
