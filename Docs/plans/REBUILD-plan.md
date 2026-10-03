# Rebuilding the app

Written 2026-10-01. **Decision: demolish `zhen-app/` and rebuild it.** The tool is
finished and untouched; this is about the app only.

`AGENTS.md` is the authority on **how**. This plan says **what** and **in what order**.
Where the two disagree, `AGENTS.md` wins and this file is wrong.

---

## 1. Why, measured

The app was built to a different standard. Against the house rules, as they stand:

| Rule | Required | Actual |
|---|---|---|
| macOS lists are `Table`, sortable, `Set<ID>` selection | — | **0** |
| `contextMenu(forSelectionType:)` | — | **0** |
| `.commands { }` — every action in the menu bar | — | **0** |
| `@FocusedValue` / `.focusedSceneValue` | — | **0** |
| Typed routes, `navigationDestination(for:)` | — | **0** |
| `ContentUnavailableView` | — | **0** (hand-built) |
| `Form` + `.formStyle(.grouped)` | — | **0** |
| Accessibility identifiers | all interactive | **0** |
| Asset-catalogue colour symbols | all colour | **0 colorsets**, 351 lines in code |
| `.help()` on icon-only controls | all | **1** |
| `var someView: some View` | banned | **18** |
| `Color(red:green:blue:)` | banned | **4** |
| `ObservableObject` / `@Published` | banned | **1** |
| Entitlements, each with a reason | sandbox + hardened | **0 files** |

Absent entirely: `fastlane/`, `Marketing/copy.json`, the screenshot pipeline,
`docs/ARCHITECTURE.md`, `Localizable.xcstrings`, `screenshots.yml`.

**The root cause is one decision.** The device list is `ScrollView` + `LazyVStack` +
`ForEach` + a `Button` per row. Choosing that over `Table` cost keyboard navigation,
context menus, selection semantics and column alignment — each of which then had to be
rebuilt by hand, which is why the accessibility work was expensive and why review-and-edit
is slower than starting again. The responsive plan is where that choice was made and
justified; it was wrong.

## 2. What dies, what survives

| | |
|---|---|
| **Dies** | everything under `zhen-app/`, `Scripts/generate-xcodeproj.py` (712 lines) and its CI step, `Scripts/make-icon.sh` |
| **Survives untouched** | the whole `zhen/` package. `ZhenCore` imports Foundation only, which already complies |
| **Survives and is kept deliberately** | `ZhenScan` — a target inside `zhen/`, not an intermediate package. It is the only boundary between a MainActor-by-default app target and `DarwinScanner`. Delete it and the first socket on the main actor serialises the scan behind the window, silently |
| **Moves to `Docs/process/`** | `A1`–`A3`, `03-zhen-app.md`, `REVIEW-ui-architecture.md`, `RESPONSIVE-plan.md`, `APP-CATCHUP.md`. Record, not instruction |

`generate-xcodeproj.py` existed because nobody owned a hand-maintained `.pbxproj`.
Folder-synchronised groups — which `AGENTS.md` requires for new projects — remove the
reason: the project file holds targets, settings and schemes, and the folders look after
the files.

## 3. The design source, and its two caveats

Committed 2026-10-01 to `Design/`, having previously existed nowhere in the repository —
which is why `A1`–`A3` were the only surviving record of them.

> **Correction, 2026-10-03.** The sentence above is wrong, and so is the same claim in
> commit `352e8c8`. The six artboards have been tracked since 2026-09-01 (`3aab64f`) at
> `Docs/Design/01-devices-dark.png` through `Docs/Design/06-settings.png`, and again at 2×
> in `zhen-app/Zhen/Design/ZhenDesign.docc/Resources/artboard-*@2x.png`. The claim came
> from a `find … | head -20` whose twenty results were all `Study/figures`; the artboards
> were below the cut. `Design/artboards-2026-10-01.pdf` is therefore a **convenience
> copy** — the same six screens as one multi-page export — not the only source.
> `Docs/Design/` is the canonical location. Checked with `git ls-files 'Docs/Design'` and
> `git ls-files | grep -i artboard`, neither truncated.

| | |
|---|---|
| `Design/artboards-2026-10-01.pdf` | six screens: Devices dark, Devices light, Device detail, Activity, Live scan, Settings |
| `Design/marks/03-z/` | the mark: `layer-1-plate.svg` + `layer-2-glyph.svg`, light and dark glyphs, PNG 16–2048 |

**Caveat one — the artboards are branded "Infinity Castle" and carry Omada throughout.**
18 mentions: a sidebar item, a Settings section, a panel in the device detail. Omada was
dropped from the project. Phase 1 subtracts it and re-brands to Zhen. The sidebar goes from
five items to four: Devices, Activity, Events, Settings.

**Caveat two — the artboards draw native controls.** The Devices screen is a header row
with NAME / IDENTITY / IP ADDRESS / MAC ADDRESS / LAST SEEN, a search field and a toolbar
button; Settings is grouped sections with toggles, pickers and a secure field. Those are a
`Table` and a `Form`. The design never asked for the hand-built version — the
implementation chose it.

**The mark is layered**, which is what macOS 26 wants: plate and glyph as separate layers
for Icon Composer, with tinted and dark variants, rather than one flat rasterised `.icns`.
That is an upgrade over `make-icon.sh`, not a port of it.

## 4. Two conflicts with the house rules, to settle before phase 1

**Bundle identifiers.** The rules say `dev.jc.<app>` and `dev.jc.<app>.<Role>`. This
project uses `com.jctec.zhen` / `com.jctec.zhen.helper`, baked into the helper's
code-signing requirement, the installed launchd plist and `verify-identifiers.sh`. Changing
it means unregistering and re-registering the daemon. **Proposed: keep `com.jctec`, amend
the standard.**

**SwiftData.** The rules require it, CloudKit-ready. `SPEC.md` withdrew the SwiftData
conformance because the app reads the same NDJSON history file the command line writes —
one store, two front ends. **Proposed: `LogHistoryStore` through the `HistoryStore`
protocol in Core**, which is what the standard's own "Linux consumers bring their own
conformance" sentence anticipates. Recorded as a deviation, in one line, not dropped
silently.

---

## Phase 0 — demolish

Branch `v2` off `main`.

1. **Unregister the helper first.** `BundleProgram` resolves relative to the bundle root,
   so deleting the bundle while the daemon is registered leaves a registered system daemon
   pointing at nothing — and `SMAppService` unregisters by identity, which comes from code
   inside the app being deleted. `unregister()` is wired, unit-tested and **has never
   run**. Verify with `sudo launchctl print system/com.jctec.zhen.helper` before and after.
2. Move the six documents to `Docs/process/`, before deleting the code they describe.
3. `git rm -r zhen-app`, `Scripts/generate-xcodeproj.py`, `Scripts/make-icon.sh`, and the
   project-regeneration step in `ci.yml`.
4. Point `Scripts/check-docs.sh` and `Docs/README.md` at what remains.

**Done when:** `swift test` in `zhen/` is green, CI is green with the app jobs gone, no
daemon is registered, and nothing in the repository references `zhen-app`.

## Phase 1 — the design system

A new Xcode project at `zhen-app/`, folder-synchronised groups, one app target referencing
the `zhen` package by path. **No intermediate packages.**

> **Amended 2026-10-03, at the split.** Not by path: this repository is now `zhen-app`, the
> package is `zhen-core`, and the app target references it as a **remote package, by
> version**:
>
> ```swift
> .package(url: "https://github.com/zhen-swift/zhen-core.git", from: "0.5.0")
> ```
>
> In Xcode: File ▸ Add Package Dependencies, that URL, *Up to Next Major* from `0.5.0`. The
> new project lives at this repository's root, not at `zhen-app/`. One consequence for the
> table below: the adaptive-contrast helper is a change to `zhen-core`, and the app can use
> it only once `zhen-core` has tagged a release containing it. At the time of writing `0.5.0`
> itself is not yet tagged — `Docs/process/SPLIT-progress.md` in the archived monorepo says
> why — so phase 1 starts by checking `git ls-remote --tags` on the URL above.

| Piece | Where | Note |
|---|---|---|
| `Spacing`, `CornerRadius`, `BorderWidth`, `IconSize` | `Utilities/` | enums with call-site extensions — `.padding(.spacing.medium)`. **Four tokens, not a 45-constant `Metrics`** |
| Colours | `Assets.xcassets` | light/dark variants, generated symbols. The biggest departure: 351 lines of `Palette.swift` become colorsets |
| Adaptive contrast | `zhen/Sources/ZhenCore` | the one phase-1 file outside the app. The rules put it in Core; the old hand-derived table was already caught right against one background and wrong against two |
| `PressButtonStyle` and cross-feature UI | `Components/` | |
| Type | system font, Dynamic Type, `@ScaledMetric` | no fixed sizes |

Derived from the artboards, under one rule: **find the platform control that gets closest
first, and spend the artboards on what it does not cover.** Where the design and `Table`
disagree, the design bends — `tableStyle`, row backgrounds and `labelStyle` reach further
than they look, and what they do not reach is cheaper to concede than to reimplement.

Extract from the dying tests before they go: the contrast table (`ContrastTests`, 313
lines), the symbol names (`SymbolTests`), and the keyboard traversal order
(`KeyboardTests`). Those are measured findings, not code.

**Done when:** every token is an enum case or a colorset; a preview exists for every
component in light, dark and increased contrast; the contrast helper is in Core with its
table as a test; zero literal colours, spacings or radii in any view.

## Phase 2 — the app

`Features/<Name>View/` per screen, in the layout the rules set out: root file, `+ViewModel`
where it earns its keep, one inner view per file, `+PreviewContainer`.

| Screen | Built from |
|---|---|
| Devices | `Table`, `KeyPathComparator` sorting, `Set<Device.ID>` selection, `contextMenu(forSelectionType:)`, `.searchable`, `.toolbar` |
| Device detail | detail column or `.inspector()` — decide against the artboard |
| Activity | `Table` with the category filter as a segmented control |
| Live scan | staged progress; degradations rendered as the calm notices the artboard draws |
| Settings | `Settings { }` scene, `Form` + `.formStyle(.grouped)`, opened with ⌘, |

Navigation: one `Hashable` route enum, `NavigationSplitView` with a typed sidebar
selection, `navigationDestination(for:)` exhaustive.

Every action in `.commands { }`; frequent ones get shortcuts; menu commands reach the
window through `@FocusedValue`. Identifiers on everything interactive, stable camelCase,
suffixed for collections — they are the UI-test API.

**Done when:** the macOS screen checklist in `AGENTS.md` passes for each of the five —
reachable from sidebar *and* menu bar, keyboard-only usable, `.help()` on icon-only
controls, clean from minimum window size to full screen in light, dark and increased
contrast, window and selection restored on relaunch.

## Phase 3 — the repo layer

None of this is app code and it should not tangle into phase 2.

`Gemfile`, `fastlane/` with `test` / `unit_tests` / `ui_tests` / `screenshots` /
`marketing` / `prepare_simulators`, `Marketing/copy.json`, the asset generator,
`AppStoreAssets/`, `docs/ARCHITECTURE.md` ending in **Known rough edges**,
`Localizable.xcstrings`, `screenshots.yml`.

**Collision to resolve first:** this repository has `Docs/` and the rules want `docs/`.
On APFS those are the same directory. Decide before creating the second one.

---

## Open decisions

| | |
|---|---|
| **One repo or two** | **Decided 2026-10-03: three** — `zhen-core`, `zhen-app`, `zhen-study`, with the app depending on a tagged core. What follows is the reasoning as written before the decision. The rules' layout assumes an app repo — fastlane, Marketing, AppStoreAssets at the root. This root is a CLI and a frozen study. Separate repos would let the app depend on a *tagged* library rather than a path, which is the schema-3 breakage prevented structurally. Defer until phase 1 proves the design system; it is a cheap move later and a distraction now |
| **`v2` means what** | The app's v2, or the repository's. If the app leaves, `v2` here is only "the branch where the app was removed" |
| **Device detail: inspector or column** | Decide against the artboard in phase 2, not now |
| **Events screen** | The sidebar draws it; no artboard does. Either design it or drop the item |
