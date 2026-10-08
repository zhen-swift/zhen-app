# Appendix A1 — Design System: Foundations

**Read this before document 03.** Same agent, in order: A1, A2, A3, then 03. By the
time you open the app brief you should already know what a row looks like, what a
chip looks like, and which grey to use — so 03 can talk about wiring instead of
pixels.

Everything here was measured from the six exported artboards, not invented. Where a
measured value is wrong — and several are — this appendix says so and gives you the
corrected value to ship.

**Revised after the module was built.** Three things in the original could not survive
contact with an implementation: the corrected contrast values were derived against one
background when the design has three, the asset-catalog instruction cannot work in a
SwiftPM module, and Dynamic Type does not exist on macOS. Each is fixed below and marked
*(revised)* with what the building found. `ZhenDesign`'s own `Corrections.md`
carries the long version.

---

## The module you're building

The design system is real code, not a PDF. It lives in `zhen-app` as its own
module so the app can only use tokens that exist:

```
zhen-app/Zhen/Design/
  Tokens/        Palette.swift, Typography.swift, Metrics.swift, Symbols.swift
  Components/    everything in A2
  Patterns/      everything in A3
  ZhenDesign.docc/
    ZhenDesign.md          the landing page
    Foundations.md              this appendix, as DocC
    Components.md               A2, as DocC
    Articles/…                  one per pattern
    Resources/                  the six artboard PNGs
```

Add it to the package like this:

```swift
.target(
    name: "ZhenDesign",
    swiftSettings: [
        .swiftLanguageMode(.v6),
        .defaultIsolation(MainActor.self),   // it's all views; main actor is correct here
    ]
),
```

### Rendering the docs locally

DocC is part of the toolchain, so there's nothing to install:

```bash
# live preview, reloads as you edit
swift package --disable-sandbox preview-documentation --target ZhenDesign

# build a static archive you can open or host
swift package generate-documentation --target ZhenDesign
```

The sandbox flag is needed because the preview server wants to bind a port, and SPM
plugins run sandboxed by default. That's the whole reason — nothing sinister.

Every public symbol gets a doc comment, and every component gets a `@Snippet` or a
preview referenced from its article. A design system nobody can browse is a design
system nobody uses.

---

## Colour

These are the values sampled directly out of the artboards.

### Dark (the primary theme — this app was designed dark-first)

| Token | Hex | Where it came from |
|---|---|---|
| `surface` | `#1A1A1F` | content background, 77% of the artboard |
| `surfaceRaised` | `#212127` | sidebar, card fills |
| `surfaceField` | `#2C2C32` | text field and chip backgrounds |
| `separator` | `#2A2A2F` | the line between table rows |
| `selection` | `#373548` | selected sidebar row fill |
| `accent` | `#A495E8` | wisteria — buttons, links, confidence bars, merged events |
| `textPrimary` | `#EBEBF0` | device names, values |
| `textSecondary` | `#65656C` | subtitles, column headers — **see the correction below** |
| `online` | `#4CD268` | status dots, completed stages, toggles |
| `warning` | `#D9A856` | partial-results dot, port events |
| `info` | `#6DB3D4` | IP-changed events |
| `offlineRing` | `#49494F` | the hollow dot on an offline row |

### Light

| Token | Hex |
|---|---|
| `surface` | `#FFFFFF` |
| `surfaceRaised` | `#EEEDF3` |
| `surfaceField` | `#F0F0F0` |
| `selection` | `#DBD8ED` |
| `accent` | `#6A58C9` |
| `textPrimary` | `#1D1D1F` |
| `textSecondary` | `#ADADB0` — **see the correction below** |

Note the accent changes between themes: `#A495E8` on dark, `#6A58C9` on light. That's
correct and deliberate. The same purple on white would be too pale to read, and the
darker one on `#1A1A1F` would disappear. Semantic tokens, not fixed colours.

### The tokens you must not ship as measured *(revised)*

I ran WCAG contrast on every pair. Almost everything passes comfortably — accent
6.64:1, online green 8.85:1, primary text 14.59:1 on dark. Two fail:

| Pair | Measured | Required |
|---|---|---|
| `textSecondary` `#65656C` on `#1A1A1F` | **3.00:1** | 4.5:1 |
| `textSecondary` `#ADADB0` on `#FFFFFF` | **2.24:1** | 4.5:1 |

Secondary text carries the vendor, the model, the "randomized MAC · no vendor"
explanation — the content that makes an unidentified device legible instead of blank. It
is not decorative and it cannot be 3:1.

**There are three text backgrounds, not one.** This is the part the first version of this
section got wrong, and it is the single easiest mistake to make in a two-theme palette.
`surface`, `surfaceRaised` and `surfaceField` all carry text: cards, the sidebar and
every settings section sit on the raised surface, and chips, filter chips and the search
field sit on the field surface. A colour derived against `surface` alone is correct in
the device list and non-compliant in most of the rest of the app.

The values below clear 4.5:1 against **all three**, in both themes:

```
textSecondary  dark   #939396
textSecondary  light  #6B6B6E
textTertiary   dark   #939399
textTertiary   light  #6A6A6E
```

Measured — and these numbers come from a test, not a spreadsheet:

| Token | `surface` | `surfaceRaised` | `surfaceField` | Theme |
|---|---|---|---|---|
| `textPrimary` `#EBEBF0` | 14.59 | 13.48 | 11.68 | dark |
| `textSecondary` `#939396` | 5.66 | 5.23 | 4.53 | dark |
| `textTertiary` `#939399` | 5.67 | 5.24 | 4.54 | dark |
| `accent` `#A495E8` | 6.64 | 6.13 | 5.31 | dark |
| `textPrimary` `#1D1D1F` | 16.83 | 14.46 | 14.77 | light |
| `textSecondary` `#6B6B6E` | 5.31 | 4.56 | 4.66 | light |
| `textTertiary` `#6A6A6E` | 5.39 | 4.63 | 4.73 | light |
| `accent` `#6A58C9` | 5.45 | 4.68 | 4.78 | light |

`onAccent` on `accent` is 6.64:1 dark and 5.45:1 light, passing in both directions.

**Secondary and tertiary converge, and that is correct.** Held to the same floor on the
same backgrounds they end up three units of blue apart on dark. The only way to restore a
visible colour step is to push secondary *louder*, to about 6.65:1, which is well above
the muted look the artboards establish. Do not do it. The hierarchy between them is
typographic — tertiary is 11pt semibold uppercase tracked, secondary is 12pt regular
sentence case — and this appendix's original pair had the step inverted anyway, with
tertiary lighter and therefore louder than secondary on dark.

**Light values this section did not originally give.** `separator` `#E3E3E8`,
`offlineRing` `#C4C4C9`, and the status text colours below.

### In Swift *(revised)*

Semantic names only. Nobody in the app writes a hex value, ever.

**Do not use an asset catalog.** The original instruction here was to put each colour in
`Assets.xcassets` with Any and Dark appearances, which is the right instinct on an Xcode
app target and does not work in a SwiftPM module: **`swift build` never runs `actool`.**
Asset-catalog compilation belongs to Xcode's build system, so SwiftPM copies the
`.xcassets` directory into the resource bundle verbatim, `Color(_:bundle:)` finds no
compiled `.car` at runtime, and every token silently resolves to **white**. The design
system was built that way first and the previews came out blank — white text on white,
with no error anywhere.

One dynamic provider per token gives every property the asset catalog was wanted for:

```swift
public enum Palette {
    public static let surface       = dynamic(dark: 0x1A1A1F, light: 0xFFFFFF)
    public static let surfaceRaised = dynamic(dark: 0x212127, light: 0xEEEDF3)
    public static let textPrimary   = dynamic(dark: 0xEBEBF0, light: 0x1D1D1F)
    public static let textSecondary = dynamic(dark: 0x939396, light: 0x6B6B6E)
    // …
}

private func dynamic(dark: UInt32, light: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(srgb: isDark ? dark : light)
    })
}
```

`NSColor(name:dynamicProvider:)` is exactly what an asset-catalog colour compiles down
to: a colour that resolves against the current `NSAppearance`, which SwiftUI drives from
`\.colorScheme`. Light and dark are still a data change rather than a branch in view
code — the branch lives in this one file — the values still appear exactly once, and a
high-contrast appearance later is still a change to this file alone.

sRGB explicitly when building from a literal. The artboards were sampled in sRGB, and
letting AppKit pick the generic calibrated space shifts every value by an amount that is
invisible in isolation and obvious beside the exported PNG.

Resist the urge to write `Color(hex:)`. The moment that helper exists, hex values start
appearing in views, and the system stops being a system.

**Pin the contrast table with a test.** It is the one part of a design system that is
objectively verifiable, it is the claim everything else rests on, and a number in a
markdown table cannot catch a value that is right against one background and wrong against
another — which is exactly how the contrast values were wrong twice. Read the tokens back
through the same dynamic provider the views use, never from duplicated constants:

```swift
appearance.performAsCurrentDrawingAppearance {
    let resolved = NSColor(Palette.textSecondary).usingColorSpace(.sRGB)!
    // …compute WCAG luminance and assert against every surface
}
```

### Status colours split into marks and text *(revised)*

One vivid green cannot do both jobs. As an 8pt dot the artboard colours are right in both
themes — a dot is a shape, filled versus hollow carries the meaning, and the accessibility
floor says so explicitly. As *text on white* they are 1.96:1, 2.17:1 and 2.32:1, which is
unreadable.

So there are two families. The marks are the artboard colours, unchanged in both themes.
The text variants are identical on dark, where the vivid colours already reach 7–9:1, and
darkened on light:

| Role | Dark | Light |
|---|---|---|
| `online` / `warning` / `info` — dots, fills, tracks | `#4CD268` / `#D9A856` / `#6DB3D4` | unchanged |
| `onlineText` | `#4CD268` | `#217538` |
| `warningText` | `#D9A856` | `#8A6114` |
| `infoText` | `#6DB3D4` | `#256F90` |

Use the text variants anywhere the colour spells a word — the kind label in an event row
is the only place today.

## Type

The artboards are 2× Retina exports, so every pixel measurement here is halved to
give you points.

| Role | Size / weight | Used for |
|---|---|---|
| `screenTitle` | 22 semibold | "Devices", "Activity", "Settings" |
| `screenSubtitle` | 13 regular, secondary | "6 devices · 5 online · 2 unidentified" |
| `sectionLabel` | 11 semibold, uppercase, +0.6 tracking, tertiary | "SCANNING", "HISTORY", "PRIVILEGED ENGINE" |
| `columnHeader` | 11 semibold, uppercase, +0.6 tracking, secondary | "NAME", "IP ADDRESS" |
| `rowTitle` | 15 medium | device names |
| `rowSubtitle` | 12 regular, secondary | "MacBook Pro 14″ · Apple" |
| `mono` | 13 regular, monospaced | IPs, MACs, ports, times |
| `badge` | 10 semibold, uppercase, +0.5 tracking | GATEWAY, WINNER, private |

```swift
public extension Font {
    static let screenTitle    = Font.system(size: 22, weight: .semibold)
    static let screenSubtitle = Font.system(size: 13)
    static let rowTitle       = Font.system(size: 15, weight: .medium)
    static let rowSubtitle    = Font.system(size: 12)
    static let mono           = Font.system(size: 13, design: .monospaced)
    static let columnHeader   = Font.system(size: 11, weight: .semibold)
    static let badge          = Font.system(size: 10, weight: .semibold)
}
```

**Monospace is a correctness decision, not a style one.** An IP address in a
proportional font makes `10.10.20.2` and `10.10.20.112` impossible to scan down a
column, and a MAC address becomes a smear. Anything the user compares vertically —
addresses, ports, timestamps — is monospaced. Anything they read as language is not.

Two rules that will save you:

Use `.monospacedDigit()` on any changing number that isn't full monospace — the "42
devices" counter, elapsed timers. Without it the layout jitters as digits change
width, and it looks broken in a way people notice but can't name.

Don't hard-code `.uppercased()` on a string for the small labels. Use
`.textCase(.uppercase)` so the underlying value stays intact for accessibility and
localisation. VoiceOver reading "N-A-M-E" is a real bug.

---

## Metrics

Measured from the artboards, at 1182pt window width:

| Token | Value |
|---|---|
| `sidebarWidth` | 228 |
| `tableRowHeight` | 52 |
| `sidebarRowHeight` | 28 |
| `headerBlockHeight` | 87 (title + subtitle + column header row) |
| `contentInset` | 20 horizontal |
| `rowInset` | 16 horizontal |
| `cardRadius` | 10 |
| `fieldRadius` | 6 |
| `chipRadius` | 5 |
| `gridUnit` | 4 |

```swift
public enum Metrics {
    public static let sidebarWidth: CGFloat = 228
    public static let tableRowHeight: CGFloat = 52
    public static let contentInset: CGFloat = 20
    public static let cardRadius: CGFloat = 10
    public static let unit: CGFloat = 4          // every gap is a multiple of this
}
```

Every spacing value is a multiple of 4. If you need 13, you need 12 or 16 — the
in-between value is how a layout starts looking hand-placed.

The 52pt row is worth defending. It's tall for a data table, and it's tall because
each row carries two lines: a name and the explanation underneath it. That second
line is the whole product for an unidentified device. Don't compress it to fit more
rows on screen.

---

## SF Symbols

Everything iconographic is SF Symbols. No bundled PNGs, no custom vector assets —
symbols scale, adapt weight to the text they sit beside, respond to accessibility
settings, and match every other Mac app the user has open.

```swift
public enum Symbols {
    // Navigation
    public static let devices  = "square.grid.2x2.fill"
    public static let activity = "waveform.path.ecg"
    public static let events   = "record.circle"
    public static let settings = "gearshape"

    // Actions
    public static let search   = "magnifyingglass"
    public static let rescan   = "arrow.clockwise"
    public static let back     = "chevron.left"
    public static let reveal   = "arrow.up.forward.app"   // "show in System Settings"

    // Device kinds — the icon in the detail header and, later, the list
    public static let laptop   = "laptopcomputer"
    public static let desktop  = "desktopcomputer"
    public static let tv       = "appletv"
    public static let router   = "wifi.router"
    public static let phone    = "iphone"
    public static let printer  = "printer"
    public static let unknown  = "questionmark.circle"

    // Status
    public static let online   = "circle.fill"
    public static let offline  = "circle"
    public static let done     = "checkmark.circle.fill"
    public static let queued   = "circle"
    public static let warning  = "exclamationmark.triangle.fill"

    // Event kinds
    public static let ipChanged    = "arrow.left.arrow.right"
    public static let appeared     = "plus.circle.fill"
    public static let disappeared  = "minus.circle.fill"
    public static let merged       = "arrow.triangle.merge"
    public static let renamed      = "pencil"
    public static let portOpened   = "lock.open.fill"
    public static let portClosed   = "lock.fill"
}
```

Three things to get right:

**Give every symbol an accessibility label, or hide it.** A status dot next to the
word "Online" is decorative — `.accessibilityHidden(true)`. A status dot that is the
*only* indication of state needs `.accessibilityLabel("Online")`. Getting this
backwards produces either silence or a stutter, and both are worse than no icon.

**Symbols inherit font weight**, so a symbol placed next to `.rowTitle` text
automatically matches it. Use `.imageScale(.medium)` rather than a fixed frame, and
let it size itself.

**Check availability, and check it in a test.** Some symbols only exist from certain OS
versions, and `Image(systemName:)` with a name the system does not know renders *nothing*
— no crash, no warning, no placeholder, just a blank space that reads as a layout bug and
gets chased somewhere else. Opening SF Symbols.app is a manual step that goes stale;
`NSImage(systemSymbolName:accessibilityDescription:) != nil` over every name is one test
that does not. Prefer an older symbol over a `#available` branch for something this
small.

The one thing you should *not* draw with a symbol is the confidence meter. The
artboards show a three-bar signal glyph where the number of filled bars is the
information — that's data, not decoration, and A2 specs it as a real view.

---

## Motion

The artboards are static, so this is a decision rather than a measurement, and it is
deliberately restrained. This app shows a network changing on its own; every
animation that isn't caused by the user is a distraction from one that is.

| Transition | Duration | Curve |
|---|---|---|
| Row appears in a live scan | 180 ms | `.easeOut` |
| Stage progress bar fill | continuous | `.linear` |
| Selection change | 120 ms | `.easeInOut` |
| Detail push/pop | system default | — |
| Value updates in place (RTT, counts) | none | — |

That last one matters. A number that animates every time it changes, when it changes
twice a second, reads as noise. Swap it.

Honour `accessibilityReduceMotion`:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

.animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: devices)
```

---

## Accessibility floor

Non-negotiable, and checkable:

- Contrast at least 4.5:1 for every text token, using the corrected values above.
- **No state is colour-only.** The online dot is filled, the offline dot is a hollow
  ring — that shape difference is the accessible signal and the colour is a bonus.
  Same for confidence: bars *and* a word.
- Full keyboard traversal. The sidebar, the table, and every control are reachable
  with Tab and arrow keys, with a visible focus ring.
- Text is allowed to grow. `tableRowHeight` is a *minimum*, never a frame; prose gets
  `.fixedSize(horizontal: false, vertical: true)`; nothing that carries meaning is
  `.lineLimit(1)`. In the shipped device list the two longest subtitles wrap to two
  lines and those rows are taller than the rest — that is the guarantee working.
  ***(revised)*** **macOS has no Dynamic Type**, so do not expect the type scale to
  scale. Setting `\.dynamicTypeSize` to `.accessibility5` changes nothing — not for
  `Font.system(size:)`, and not for the semantic `.body` either; both were rendered side
  by side to check. The environment value exists on macOS and is inert. Keep the
  large-size previews anyway: they cost nothing and start meaning something the day
  there is an iOS target.
- VoiceOver reads a device row as one sentence: name, then state, then address. Set
  `.accessibilityElement(children: .combine)` on the row and give it a label that
  reads like a person talking, not a column dump.

---

## What's in A2 and A3

**A2 — Components.** Every reusable piece with its anatomy, states and SwiftUI
implementation: sidebar row, device row, status dot, confidence meter, chip, card,
key-value grid, search field, primary button, stage card, degradation banner, event
row, timeline histogram, settings rows, empty states.

**A3 — Patterns.** How those assemble into the five screens, what each field binds
to, every empty and partial and error state, and the DocC article set that ships with
the module.
