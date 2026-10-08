# Rebuild — phases 0 and 1, report

2026-10-07. The ledger with every gate's evidence is `REBUILD-progress.md`; this is the
summary the brief asks for. **No screen exists.** Phase 2 starts when JC has looked at the
previews: `Docs/process/evidence/renders/components-{dark,light,darkIncreased,lightIncreased}.png`,
or the `#Preview`s in Xcode.

## What was built

| | |
|---|---|
| **Phase 0** | The old app deleted (88 files), its tests' findings extracted first-hand from `fdb7eaf`, the old helper removed from launchd, the dead app's documents moved to `Docs/process/` |
| **Project** | `Zhen.xcodeproj`, three folder-synchronised targets, shared scheme, zhen-core as a remote package from `0.5.0` (resolves `0.6.0`, pinned by a committed `Package.resolved`) |
| **Tokens** | `Utilities/`: `Spacing`, `CornerRadius`, `BorderWidth`, `IconSize`, read as `.padding(.spacing.medium)` |
| **Colour** | 20 colorsets × 4 variants, derived by `evidence/derive-palette.py` from the artboards |
| **Type** | text-style map; `.sectionLabel()`, `.numericValue()` |
| **Components** | `PressButtonStyle`, `StatusDot`, `Chip`, `SignalMeter`, each with dark / light / increased `#Preview`s |
| **Contrast helper** | zhen-swift/zhen-core#5, open, unmerged, untagged |
| **Ratchets** | `Scripts/check-tokens.sh` (in CI), `Scripts/check-palette.py` (reads the shipped `Assets.car`) |

## Gates, measured

| Gate | Result | Shown failing on |
|---|---|---|
| Old helper gone | `launchctl print` → "Could not find service", exit 113 | — |
| Findings traceable | contrast table recomputed: 100 pairs, 0 below floor, matches A1 to 2 dp; 30/30 symbols exist on 26.6.2 | AA floor 4.6 → 3 pairs; fake symbol → missing |
| Nothing names a deleted path | 0 hits outside the record | same grep at `fdb7eaf`: 4–11 hits per path |
| Project settings | MainActor default, Swift 6, strict complete, macOS 26, warnings-as-errors, asset symbols, remote package — read back from `xcodebuild -showBuildSettings` | a planted unused `let` → BUILD FAILED |
| Contrast helper | 632 tests (main 622), macOS CI green; Linux red only on AUDIT M2's existing crash | AA 4.6 → 5, linearisation 0.5 → 105, no flare → 113 |
| `check-tokens.sh` | self-test 20/20 at exact lines on BSD and GNU grep; 9 view files PASS; CI green | case-sensitive `width`, unmarked literal, broken exemption, empty tree |
| Palette | 60 pair × look cases in-process; 142 pairs × 4 appearances from `Assets.car` | wrong high-contrast value; missing variants; artboard grey restored → 2.24 / 1.92 / 1.96 |
| Renders | `ComponentRenderTests`: a dot's centre pixel equals the catalogue colour in all four looks | (the test itself was wrong once; see the ledger) |
| Whole scheme | `xcodebuild test`: 10 Swift Testing tests + UI launch test pass | — |
| No screen | the app's root is a `ContentUnavailableView` placeholder | — |

## What the artboards asked for that a platform control already provides

Built as nothing, on purpose. Phase 2 uses these:

| Artboard | Platform control |
|---|---|
| Devices list with NAME / IDENTITY / IP / MAC / LAST SEEN | `Table`, `KeyPathComparator`, `Set<ID>` selection |
| Search field, top right | `.searchable` |
| Scan Now, Stop Scan, Rename…, Rescan Device | toolbar `Button`s (`.borderedProminent` for the primary) |
| Sidebar rows with counts (`6`, `12`) | `List` in `NavigationSplitView`, `.badge(_:)` |
| ← Devices back link | the navigation stack's own back |
| Settings: grouped sections, fields, pickers, toggles, secure field | `Settings { }` scene, `Form` + `.formStyle(.grouped)`, `TextField`, `SecureField`, `Picker`, `Toggle` |
| Activity filter pills (All, Appearances, …) | segmented `Picker` (the plan's call). The artboard draws capsules; the design bends |
| 48-hour histogram | Swift Charts `BarMark`. The ordinary bar is exactly the accent at 50 % over the surface |
| Live-scan stage progress, spinner | `ProgressView(value:)` with `.tint`, `ProgressView()` |
| Empty and error states | `ContentUnavailableView` |
| Toggle on/off colours, popup fills | the controls' own |

## What I could not reconcile with the house rules as drawn

1. **Text greys.** The artboards use six greys below primary text. Four fail 4.5:1 on dark on
   every surface, and the light secondary fails too. "Legibility is non-negotiable" wins:
   they fold into secondary and tertiary, each moved the smallest step that clears every
   surface it sits on (dark `97979F`→`9F9FA6`, `65656C`→`939398`; light
   `7B7B7F`→`5F5F63`, `ADADB0`→`6C6C6E`). The hierarchy that colour can no longer carry
   falls to type (weight, case, size). The offline row's dimming in particular is gone as
   drawn; phase 2 should show offline with the ring and the "2 h ago", not with fainter text.
2. **Light theme exists for one screen.** Light values for cards, status colours and status
   text are derived, marked so in `derive-palette.py`. They want a designer's eye.
3. **Light online dot `23A844`** is 2.67:1 on the raised sidebar, under the 3:1 non-text
   floor. Kept as drawn because it is never the only signal; Increase Contrast fixes it.
4. **Chip padding.** Measured ≈ 6 pt horizontally, which is off the 4 pt grid; the chip uses
   8. Corner radii measured 8 (cards) and 4 (chips) where A1 said 10 and 5; the pixels won.
5. **Settings is a sidebar item and a scene.** The brief's four-item sidebar includes
   Settings; `AGENTS.md` puts Settings in a `Settings { }` scene. `REBUILD-questions.md` Q2.
6. **Events has a sidebar item and no artboard.** Phase 2 designs it or drops it (plan's open
   decision).
7. **App Sandbox is on** (`AGENTS.md`), and the scanner needs the network and the privileged
   helper over XPC. Phase 2 will need entitlements (at least outgoing network; Local Network
   usage string; Mach lookup for the helper), each with its reason. None is declared yet,
   because nothing is wired.

## Process notes

- `Docs/plans/PHASE-0-START.md` and `Docs/RULES.md` do not exist; JC's instruction ("delete
  all the code first") stood in for the first, the brief's decisions for the second (Q1).
- The old helper could not be removed through the old app: none of its buttons has an
  accessible name. JC ran a sudo script instead. Every launch of the old app went through a
  scratch history file, and the real store's hash never changed.
- The Xcode project was generated by a one-shot script at JC's request, verified from
  `xcodebuild`, and not kept: Xcode owns it now.
- Increase Contrast cannot be reached through AppKit in a test (`NSAppearance(named:
  .accessibilityHighContrastDarkAqua)` returns `darkAqua`); SwiftUI's `_colorSchemeContrast`
  can. Both facts are pinned as tests.

## The deleted scripts, and what the new app needs from each

At `fdb7eaf:Scripts/`. Table with detail in the ledger, P0.4.

| Script | Needed for |
|---|---|
| `build-app.sh` | bundling the helper daemon plist and binary (`Contents/Library/LaunchDaemons`), Bonjour services in Info, inside-out signing; becomes Xcode build phases |
| `release.sh` | Developer ID signing, notarisation, stapling (phase 3+) |
| `verify-helper.sh` | proof from the wire that the helper's frames are its own; belongs with zhen-core |
| `check-fixed-sizes.sh`, `count-fixed-sizes.py` | the ratchet's shape; `check-tokens.sh` replaces them |
| `fixed-sizes-baseline.txt` | nothing |

## For JC

- Look at the renders, or at the `#Preview`s in Xcode, and say go for phase 2.
- Merge and tag zhen-core#5 when it suits; phase 2 then raises `from:` and swaps the test's
  own WCAG formula for `ZhenCore.Contrast`.
- `~/Dev/InfinityCastle/build/` can be deleted: the helper is out of launchd. Login Items may
  still list Zhen until that bundle is gone.
