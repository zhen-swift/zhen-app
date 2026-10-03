# Architectural review — the app and design system

**Reviewed:** `zhen-app` at commit `19bbd51` plus the wiring phase on top.
**Method:** read the manifest, the target graph, every file in `Tokens/`, `Patterns/`,
`Model/` and `Views/`, and the test targets. Contrast ratios recomputed independently.
Nothing was built or run — this review has no toolchain, so every claim below comes
from source, and anything requiring execution is listed as unverified at the end.

**Verdict:** the structure is sound and one decision in it is better than what the
briefs specified. Four findings are architectural rather than cosmetic, and one of
them is a correctness bug wearing a layout costume. None require a rewrite.

---

## The layering, as built

```
zhen ─┬─ ZhenCore    (portable: model, time, concurrency, protocols)
                └─ ZhenDarwin  (sockets, dns_sd, route table)
                          │
zhen-app ─┬─ ZhenScan     depends on both · .defaultIsolation(nil)
               ├─ ZhenDesign   depends on NOTHING · MainActor by default
               └─ Zhen         depends on both of the above · MainActor
```

Three targets in one package, and the split is the strongest architectural decision in
the app layer.

**Isolation is enforced by the target boundary, not by annotation.** `ZhenScan`
builds with `.defaultIsolation(nil)`; the design system and the app build main-actor by
default. That means it is not possible to accidentally main-actor a socket by
forgetting a `nonisolated`, because there is no annotation to forget — the compiler
setting does it. The manifest states the failure mode explicitly: if something in
`ZhenScan` ever needs `@MainActor` to compile, UI has leaked into the scanner.
This is better than what document 03 asked for, which was one target and discipline.

**The design system depends on nothing.** Not `ZhenCore`, not the scanner. Every
screen renders from value types it declares itself, which is what lets previews check
layout with no network in the room and no store standing up. `Presentation.swift` in
the app target is the only place core's `Device` becomes a `DeviceRowModel`, so the
translation is one-way, single-sited, and testable — and it is tested, including the
rule that row identity is the stable device id rather than the address, which is the
thing that would otherwise make every DHCP renewal look like a new device to SwiftUI's
diff.

**Stream lifetime is structural.** `RootView` attaches `.task(id: model.scanID)`, so a
new scan cancels the previous one and a disappearing view cancels the running one,
with cancellation propagating through the task group into `AsyncStream.onTermination`
where the sockets close. Nothing calls `stopScan()` because nothing can. That is the
right shape and it should not be softened later for convenience.

---

## Findings

### F1 — Two windows exist, and previews check the one that does not ship

`ZhenWindow` in the design module and `RootView` in the app both construct a
`NavigationSplitView` with a sidebar and a detail column. The previews exercise the
former; the application runs the latter. They have already drifted — `RootView` applies
`.background(Palette.surfaceRaised)` to the sidebar and the design module's version
does not.

This is not a tidiness complaint. It is the direct reason the sidebar instability in
F2 survived a design-system review with 57 previews: the preview and the product are
different objects, so a layout defect in one is invisible in the other. Any window-level
regression from here on is equally invisible.

**Fix:** `ZhenWindow` takes the sidebar content and the detail content as
parameters and owns the split-view configuration; `RootView` supplies the two and adds
the task. One window, previewed and shipped.

### F2 — Nobody owns the minimum width, so the sidebar absorbs the pressure

`DeviceRow` lays its columns out with fixed widths — identity, IP, MAC, last-seen, plus
the row inset — which gives the device list a hard intrinsic minimum. Activity and
Settings have no such minimum; their content is `maxWidth: .infinity` throughout and
compresses without complaint.

`RootView` then declares `.navigationSplitViewColumnWidth(Metrics.sidebarWidth)` — a
single value, which is a *preference*, not a constraint — under
`.navigationSplitViewStyle(.balanced)`. When the detail column cannot meet its minimum,
balanced style takes the difference from the sidebar. So the sidebar is 228pt on
Settings and Activity, and narrower on Devices, and narrower still as the window
shrinks.

The architectural point underneath the symptom: **layout authority is split between a
component that asserts fixed widths and a window that assumes elastic ones, and neither
declares a minimum window size.** The split view is left to arbitrate, and its
arbitration is to sacrifice the sidebar.

**Fix, in order.** Pin the sidebar with `min:ideal:max:` all equal so it cannot flex.
Then decide the table's compression behaviour deliberately — flexible columns with
minimums, which is what the appendix's measurements imply (they were taken at 1182pt,
never declared rigid). Then set a window `minWidth` from the resulting true minimum, so
the constraint lands on the window rather than on whichever view is least defended.

### F3 — Vertical-only scrolling over fixed-width content silently truncates

Every screen wraps its content in a vertical `ScrollView`. Combined with the fixed
column widths of F2, content wider than the viewport is clipped with no way to reach
it: at a narrow window the last column is simply gone. No scrollbar, no indication, no
recovery.

This is a correctness defect, not a styling one — the UI is withholding data the model
holds. It resolves automatically if F2 is fixed by making columns flexible; if the
table keeps fixed columns, that region needs horizontal scrolling.

### F4 — Pinned versus scrolling context is inconsistent across screens

Four screens share one shape: `VStack { header; Divider; ScrollView { … } }`, header
pinned. The device list follows it and correctly pins its column-header row. But Live
Scan and Activity put the stage strip and the histogram *inside* the scroll view, so
they scroll away — while the artboards draw both as fixed context above a scrolling
list. Losing the progress strip while scrolling a growing "found so far" list is the
wrong behaviour, and the inconsistency means there is no rule to apply on the next
screen.

**Fix:** state the rule in the appendix — header and any context that describes the
whole screen are pinned; only the collection scrolls — then apply it, using
`safeAreaInset` rather than nesting.

### F5 — The persistence seam is in the wrong package

`HistoryStore` is declared in `ZhenScan`, inside the app package. Document 03
proposed it in `ZhenCore`, and that difference matters: the CLI cannot reach it
where it currently lives, so when the SwiftData decision lands there is no shared
protocol for the two conformances to satisfy — the portable log and the SwiftData store
would be two unrelated types with two unrelated shapes.

The protocol itself is well made: narrow, structs in and structs out, with the
executor-affinity reasoning stated. It is in the wrong module, not the wrong shape.

**Fix:** move the protocol and its value types to `ZhenCore`; leave the in-memory
conformance where it is. Cheap now, expensive after a second conformance exists.

### F6 — The AppKit surface is two files, one of which is dead

`ZhenApp.swift` imports AppKit and uses no AppKit symbol — every `NS`-prefixed
string in it is Info.plist content. Delete the import.

`Palette.swift` uses `NSColor(name:dynamicProvider:)` for per-token appearance
resolution, and the reasoning is correct: SwiftPM cannot compile an `.xcassets` catalog
without Xcode's build system, so the asset-catalog approach the appendix originally
specified resolves to clear at runtime. But `NSColor` is not the only way out. A custom
`ShapeStyle` implementing `resolve(in:)` reads `\.colorScheme` from the environment and
does the same job in pure SwiftUI — and gains `\.colorSchemeContrast`, so the palette
could honour Increase Contrast, which the current provider ignores.

The cost is bounded and known: `ShapeStyle` covers `foregroundStyle`, `background` and
`fill`, but a handful of APIs demand a concrete `Color`, and fourteen components are
written against `Palette.x` as `Color` today. That refactor is cheapest now and gets
more expensive with every call site the app phase adds.

---

## Risk if nothing changes

F2 and F3 together mean the product is unusable below a certain window width in a way
the user cannot diagnose — columns vanish and the navigation moves. F1 means the next
window-level defect is equally invisible to review. F5 becomes a migration rather than
a move the moment a second store conformance exists. F4 and F6 are quality and
consistency, and they compound slowly.

None of this is structural debt in the expensive sense. The layering is right, the
isolation boundary is right, the translation layer is right, and the lifetime model is
right. These are all local repairs inside a sound design.

---

## Recommended order

1. Pin the sidebar; make the table columns flexible with minimums; set a window
   minimum. *(F2, F3 — one change, they share a cause.)*
2. Collapse to one window implementation. *(F1 — do it second so the fix is previewable.)*
3. State and apply the pinned-context rule. *(F4)*
4. Move `HistoryStore` to core. *(F5)*
5. Delete the dead AppKit import; convert the palette to `ShapeStyle` and pick up
   Increase Contrast. *(F6)*

---

## Not verified

No build, no run, no screenshots — this review is source-only. Specifically unproven:
that the sidebar footer keeps a constant height between its idle and scanning states,
which would produce a reflow with the same symptom as F2 but a different cause;
whether the app in fact launches and scans; the 17 app tests and the design tests
pass; and every claim about how the split view behaves at a given window size, which
is inference from the API contract rather than observation.

---

## Outcome

Worked through on 2026-09-04. Every claim in the layering and findings sections was
checked against a build before being acted on, and the unverified section's open questions
were settled by measurement.

| | Finding | Outcome |
|---|---|---|
| F1 | Two windows | **Fixed.** `ZhenWindow` owns the split-view configuration and takes both columns as parameters; `FixtureWindow` supplies fixtures, `RootView` supplies live views. |
| F2 | Sidebar absorbs the pressure | **Fixed**, after confirming it. Columns are ranges, the sidebar is pinned `min:ideal:max:`, and the window has a minimum. |
| F3 | Vertical-only scroll truncates | **Fixed by F2.** Flexible columns plus a window minimum the content can actually fit in. |
| F4 | Pinned versus scrolling context | **Fixed.** Rule stated in A3's pinned-context rule, applied to Live Scan and Activity with `safeAreaInset`. Recorded in `Corrections.md`'s pinned-context entry on 2026-09-08 — the rule and the code landed here, the entry did not. |
| F5 | `HistoryStore` in the wrong package | **Done 2026-09-08**, once the ruling came. The protocol, `DerivedEvent` and `StoredDevice` are in `ZhenCore`; `InMemoryHistoryStore` stayed in `ZhenScan`. No conformance was chosen. |
| F6 | Dead AppKit import; `ShapeStyle` palette | **Done 2026-09-08.** Import deleted earlier; the palette is now a `ShapeStyle` and AppKit is gone from the design module entirely. Increase Contrast is honoured and measured — see `Corrections.md`'s Increase Contrast entry. |

### F2 was confirmed, and it was worse than described

Measured by rendering the window offscreen and reading the sidebar boundary off the
bitmap:

| Window | Sidebar on Devices | Sidebar on Settings |
|---|---|---|
| 1182 / 1100 / 1000 | 228 | 228 |
| 900 | 204 | 228 |
| 820 | 164 | 228 |
| 760 | 134 | 228 |

The shipped `minWidth: 960` was already below the threshold, so the defect was reachable
in the product. After the fix the sidebar holds at 228 across the whole range.

### The minimum could not be derived, only measured

Summing the tokens gives 948pt. `NSHostingView.fittingSize` says **956pt** — a
`NavigationSplitView` has a divider and insets no token knows about, and a `DeviceRow`
needs 799pt against its header's 723 because its chips are `fixedSize` and its two-line
subtitle has an intrinsic width. `Metrics.windowMinWidth` is now a declared 1000pt and
`WindowLayoutTests` fails if the measured requirement ever exceeds it.

> **Superseded 2026-09-23, stage 4.** `fittingSize` stopped being able to answer this
> the moment stage 2 moved the table's widths inside a `ScrollView`, which accepts any
> width and reports no minimum for what it holds — it then said 398pt for a room needing
> 886. The paragraph above is what was true when this review was written. The minimum is
> now found by rendering the window, and it is 890. See `process/RESPONSIVE-progress.md`.

`Column.nameMin` went to 200 because at 160 the longest real subtitle truncated at the
minimum window size, and that line is the entire content of an unidentified row.

### F6's mechanism recommendation was right, for an unstated reason

The cheaper-looking alternative — a four-way `bestMatch(from:)` including the two
accessibility appearance names, at no call-site cost — was built and then measured:

```
NSAppearance(named: .accessibilityHighContrastDarkAqua)!.name  ->  NSAppearanceNameDarkAqua
```

The accessibility appearance collapses into its base and is not constructible standalone,
so the provider cannot see the setting **and a test could never build one to check**. The
`ShapeStyle` route reads `\.colorSchemeContrast`, which is an environment value and is
settable in a preview and a test. The refactor is deferred rather than half-built; the
derived AAA values are in `Corrections.md`'s Increase Contrast entry, so it stays cheap.

### F5 — the ruling came, and the move was made

Recorded below as it stood at review time. Done on 2026-09-08: the protocol and its two
value types are in `ZhenCore`, the in-memory conformance stayed in `ZhenScan`,
and the SwiftData-versus-portable question was still open — moving the seam did not
narrow it. It was ruled on 2026-09-09: two conformances, SwiftData on Darwin and a
portable log everywhere else, which is the shape this move was made in anticipation of.
Amended 2026-09-11, and the move is what makes the amendment survivable: the SwiftData
conformance is withdrawn for shipping nowhere, and because the seam is in core rather
than beside a conformance, removing one cost nothing above it. Document 03 carries the
reasoning.

### F5 needed a ruling before it could be done

The move is right and the fix is not mine to make unilaterally: the wiring phase's
instruction was *"Do not modify either package. If you need something they do not expose,
tell me rather than reaching around them."* Moving `HistoryStore` into `ZhenCore` is
exactly that. It is three value types and a protocol, no behaviour, and it gets more
expensive the moment a second conformance exists.

### The unverified section's open questions, settled

- **Footer height between states** — constant. Rendered all four states side by side; the
  divider and both text baselines align. And the `Spacer` above it means a taller footer
  would eat blank space rather than move anything, so this could not have produced F2's
  symptom.
- **Does the app launch and scan** — yes. First device on screen at 132 ms warm, 660 ms
  cold; the difference is the neighbour table.
- **Do the tests pass** — 36 in 7 suites.
- **Split-view behaviour at a given width** — measured, table above.

### Still not verified

The app has not been seen on a screen. Capturing a running window needs a screen-recording
grant this environment does not have, so every image here is an offscreen render of the
real view tree. Nobody has resized the window by hand, and Login Items has not been
looked at.
