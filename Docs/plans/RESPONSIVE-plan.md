# Responsive layout and accessibility

Revised 2026-09-23 after scope correction: **macOS stays the only platform.** iPad is
no longer a target. What survives from that idea is the *property* it was a proxy for —
a layout driven by content rather than by boxes — and it now has to be earned directly
instead of by porting.

Three requirements, one body of work:

| | Requirement |
|---|---|
| **R1** | Every fixed size definition removed. `HStack` is fine where it is responsive; `Grid` where it is not |
| **R2** | Size-class capable — the architecture must be able to select layouts, even though macOS does not vend size classes |
| **R3** | The whole application accessibility-compliant, since the UI is open anyway |

---

## 1. The inventory, counted not estimated

Grep definitions are in section 9 so the number is checkable rather than asserted.

| | Count |
|---|---|
| `.frame(width:/height:/min/max)` call sites, excluding `maxWidth: .infinity` | **82** |
| — of which use a `Metrics` token | 30 |
| — of which are bare numeric literals in a view file | **52** |
| Size-of-a-thing constants in `Metrics.swift` | **28** |
| `Grid` / `GridRow` / `Table` / `ViewThatFits` in the codebase | **0** |
| `.fixedSize` / `.layoutPriority` (the correct tool, already present) | 17 |

The 52 bare literals are the worse half. A token at least names the intent; `.frame(width: 130)`
inside a view records a measurement somebody took once at one font size.

### Why this is not a preference

Three shipped defects, same cause, each fixed locally:

| | What happened |
|---|---|
| **F2** | `DeviceRow`'s fixed columns forced a minimum the split view paid for by squeezing the sidebar 228 → 134pt |
| **`windowMinWidth`** | could not be derived, only measured — 948pt by summing tokens, 956pt by `fittingSize`, declared 1000 |
| **`reassigned` chip** | overflowed a 104pt IP column and wrapped an address mid-octet |

A fourth is waiting in the remaining 82.

---

## 2. What goes, what stays

"Remove all sizes" taken literally destroys the design system. The test is what the
number describes.

**Stays — rhythm.** `unit = 4` and its multiples, the type scale, corner radii
(`cardRadius`, `chipRadius`, `fieldRadius`), stroke weights, `hairline`, the palette.
Space *between* things.

**Goes — boxes.** All 82 frame call sites and all 28 size constants:
`sidebarWidth`, `tableRowHeight`, `sidebarRowHeight`, `headerBlockHeight`,
`deviceTileSize`, every `Column.*`, every `Activity.*` and `Ports.*` column,
`searchFieldWidth`, `emptyStateProseWidth`, `windowMinWidth`.

**Two survivors, each needing a written reason at the call site:**

- `dotSize`, `progressTrackHeight`, `barWidth` — a status dot and a histogram bar have
  no content to size to. They are glyphs, and they scale with type.
- `proseMaxWidth` / `contentMaxWidth` — a measure limit is a *typographic* constraint
  (line length), not a box. It stays, expressed in `em` via the type scale rather than
  in points.

---

## 3. HStack or Grid — the actual rule

`HStack` is not the problem. `HStack` **plus fixed child widths pretending to be a
table** is the problem: that is a table implemented without the mechanism that makes
tables work, which is columns that agree across rows.

| Use | When |
|---|---|
| `HStack` | siblings whose widths are independent of the next row — toolbars, chips, a label and its value |
| `Grid` / `GridRow` | anything where **row N's column must line up with row N+1's** — the device table, the ports table, the activity list, settings rows |
| `ViewThatFits` | a component with a genuinely different compact form, ordered widest-first |
| `Table` | rejected — sortable multi-column macOS `Table` would fit the device list, but it takes over selection, styling and row rendering, and the design system's row visuals would have to be rebuilt inside it |

`Grid` is the mechanism the hard-coded widths were substituting for. Columns size to the
widest cell, alignment is declared per column, and the whole thing is measured by
SwiftUI at the real font size instead of by a person at one font size.

---

## 4. Size classes on macOS — the honest version

**`horizontalSizeClass` is available on macOS and constant.** *Corrected 2026-09-23
during stage 1; this paragraph previously said it was unavailable.* It is declared in
`SwiftUICore`, which `SwiftUI` re-exports, `@available(macOS 10.15, *)`. It compiles and
returns a value — `regular`, measured at 320pt, 700pt and 1400pt. A Mac window resizes
continuously rather than snapping between two states, and the value does not move with
it.

So "size-class capable" still cannot mean "read the environment value", for a sharper
reason than the original: reading it would give a layout switch soldered to one
position. The *decision* must be isolated so that it could be read, if the value ever
varies.

```
ZhenDesign/Layout/LayoutClass.swift
    enum LayoutClass { case compact, regular }
    // derived today from available width via the container
    // one line changes to read horizontalSizeClass if the platform ever vends it
```

Views ask `@Environment(\.zhenLayoutClass)`, never a width. Deriving it from the
container is better than the environment value anyway: it responds to the *pane* the
view sits in, so a narrow detail pane inside a wide window gets the compact layout,
which the real size class would get wrong.

**Stage 1 verified this against the macOS 26 SDK** and found the claim wrong in the
direction that does not change the answer. The enum derives rather than wraps, because
wrapping a constant is not a layout switch. See `process/RESPONSIVE-progress.md`.

---

## 5. Accessibility — measured state

Surveyed today across 39 view files:

| | Present | Verdict |
|---|---|---|
| `.accessibilityLabel` | 17 | partial — 7 raw `Image(systemName:)` unlabelled |
| `.accessibilityValue` | **1** | a scanner UI is full of values: progress, counts, confidence, last-seen |
| `.accessibilityHint` | **1** | |
| `.accessibilityElement` / `Hidden` | 17 / 14 | decorative hiding is actually done well |
| **Keyboard focus** — `@FocusState`, `.focusable`, `.onKeyPress`, `keyboardShortcut` | **0**, across 35 `Button`s | **the headline defect** |
| `accessibilityReduceMotion` | 4 | honoured |
| `accessibilityReduceTransparency` | **0** | the app uses material backgrounds |
| `accessibilityDifferentiateWithoutColor` | **0** | status is encoded in `StatusDot` and `Chip` colour |
| `dynamicTypeSize` outside previews | 6 | |

Two of these are compliance failures, not polish:

**Full Keyboard Access.** Zero focus handling over 35 buttons means the app is
operable only by mouse. That is WCAG 2.2 **2.1.1 Keyboard** (level A) and it is also
the one a sighted reviewer notices in ten seconds by pressing Tab.

**Colour-only status.** `StatusDot` and `Chip` carry state in hue alone — WCAG **1.4.1
Use of Color** (level A). The fix is the same one already applied to the paper's
figures: shape plus colour. A filled dot, a ring, a hollow dot; and under
`differentiateWithoutColor`, a glyph.

### Target and how it is verified

Standard: **WCAG 2.2 AA** for the criteria that apply to a desktop app, plus Apple's
macOS accessibility expectations. Verified four ways, none of them opinion:

| | Check |
|---|---|
| Xcode **Accessibility Inspector** audit, every screen | zero findings, or a written exemption |
| **VoiceOver** pass | every screen reachable and comprehensible without sight |
| **Tab** traversal with Full Keyboard Access on | every control reachable, visible focus ring, no trap |
| **Contrast** measured, not eyeballed | ≥ 4.5:1 text, ≥ 3:1 UI components and graphical objects, in both appearances and with Increase Contrast on |

Contrast gets measured with the same geometry-and-luminance method used on the icon —
that one found a 4.96:1 element that looked fine.

---

## 6. Stages, each of which builds and ships

57 previews and a design system in three documents. One sweep breaks them silently.

| | Work | Done when |
|---|---|---|
| **1** | Verify size-class availability. Add `LayoutClass`. No visual change | every screen fits the window, and the check is shown able to fail |
| **2** | `DeviceRow` + list → `Grid`. Columns sized by content | all `Column.*` deleted; F2's symptom cannot recur |
| **3** | Ports, activity, settings, events → `Grid`. Remaining frames removed pattern by pattern | the grep in section 9 returns only the section-2 survivors, each with a reason at the call site |
| **4** | `windowMinWidth` retired | the window resizes below 1000pt without clipping |
| **5** | Keyboard: focus, tab order, focus ring, `keyboardShortcut` on primary actions | Tab reaches all 35 controls; no trap |
| **6** | VoiceOver: labels on the 7 images, values and hints throughout, traits on custom controls | Inspector audit clean on every screen |
| **7** | `differentiateWithoutColor`, `reduceTransparency`, Increase Contrast; contrast measured | the four checks in section 5 all pass |
| **8** | `LayoutClass` put to work — compact forms for narrow panes | detail pane readable at its minimum without horizontal scroll |

Stages 1–4 are layout; 5–7 are accessibility; 8 spends what 1 bought. They interleave
badly, so they run in order — every accessibility fix made before stage 3 gets
rewritten by stage 3.

---

## 7. `@ScaledMetric` does nothing here, and neither does the test it was for

*Rewritten 2026-09-23 during stage 1. This section previously argued that `@ScaledMetric`
was worth adopting because the snapshot tests could exercise it across type sizes. They
cannot.*

macOS does not consume `dynamicTypeSize` at all. Measured in an `NSHostingView`: a view
holding `@ScaledMetric(relativeTo: .body) var x = 100` reports 100.0 at `.large` and
100.0 at `.accessibility3`; a `Text` in `.body` measures the same width at both; and all
three screens measure identically at both. The environment value can be set and nothing
reads it.

The gate this section promised — "a layout that survives `.accessibility3` in a test" —
therefore cannot be written. The first attempt passed on six combinations while
measuring one condition twice.

Converting the type scale to text styles was tried, since twelve of the thirteen tokens
resolve to the point size they already had. It changed 7.29% of the Devices screen's
pixels and 4.21% of Activity's: text styles carry different leading, so every table row
moved about 3pt. A visible change in exchange for scaling the platform does not perform.
Reverted.

**What replaces it** is the two things macOS does vary: the width of the window and the
length of the strings a real network puts in it. Stages 1 to 4 are measured against
those. `typeSizeIsInertOnThisPlatform` pins the finding, so the day this section becomes
wrong again is a failing test.

---

## 8. What this costs

- **A1, A2, A3** are written in fixed values and are the authority on what a person
  sees. Rewritten alongside, not afterwards.
- **`WindowLayoutTests` largely retires.** Its job was defending a declared minimum
  against fixed content. `RenderSnapshot` across widths and type sizes replaces it.
- **57 previews** need width and type variants — the moment they stop being 57 copies
  of one condition.
- **Nothing in `zhen-core` or `zhen-cli` changes.** The study is unaffected; it does not
  measure the app.
- **OUI vendor lookup waits for stage 2.** Both touch `DeviceRow`; wrong order means
  building the row twice.

---

## 9. The grep that defines "done"

```sh
APP=zhen-app
grep -rnE '\.frame\(' $APP --include=*.swift \
  | grep -E 'width:|height:' | grep -v 'maxWidth: \.infinity)'
grep -nE 'static let' $APP/ZhenDesign/Tokens/Metrics.swift
```

Baseline today: **82** and **28 of 45**. Target: only the section-2 survivors, each
carrying a comment saying why it is one. Wired into CI as a ratchet — the count may
fall, never rise.
