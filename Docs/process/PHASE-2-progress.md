**Liveness:** 2026-10-10 — stages A–C done and committed. Next: stage D.

# Phase 2 — build the whole app, progress

The ledger for `zhen-agents/briefs/app-build-the-whole-thing.md`. Rules:
`zhen-agents/rules/house-rules.md` (== `AGENTS.md`). Questions for JC, read once at the end:
`PHASE-2-questions.md`. What only JC can run: `PHASE-2-verification.md` (stage G).

**To resume:** read the liveness line, then the last stage section. Every gate below names
its test; `xcodebuild -project Zhen.xcodeproj -scheme Zhen -destination 'platform=macOS' test`
runs all of them. Deliberate breaks were run with a throwaway script that applied one edit,
ran the named tests and restored the file; the outputs are quoted, trimmed, under each gate.

Branch `phase-2`, off `main` at `57e4b27`. Not pushed (see Q1).

## Decisions taken (the brief's defaults, not re-litigated)

| # | Decision | Where it shows |
|---|---|---|
| 1 | Sandbox off, hardened runtime on | `ENABLE_APP_SANDBOX = NO`; `InfoPlistTests.appIsNotSandboxed` |
| 2 | Two rooms, Devices and Activity | `Model/Room.swift` |
| 3 | Settings is a `Settings { }` scene, ⌘, | `ZhenApp.swift` |
| 4 | Device detail is a pushed destination | `Route.device`, `navigationDestination` in `RootView` |
| 5 | Live scan replaces the Devices content and hands back | `DevicesView` body, `ScanSession.Phase` |
| 6 | Activity: segmented `Picker`, Presence / Addresses copy, device filter in `.searchable` | `ActivityFilter`, `ActivityView` |
| 7 | Sidebar selection: system highlight | `RootView.SidebarView` — no custom tint |
| 8 | `Docs/` stays capitalised | **Deviation from the house rules' `docs/`, recorded here in one line: APFS is case-insensitive and `Docs/` already holds 30+ files.** The rule itself lives in `zhen-agents/`, outside this repository, so amending it is Q4 |
| 9 | Default sort: status, then last seen descending | `DeviceItem.defaultOrder` |
| 10 | Offline = ring + last-seen weight, never dimming | `NameCellView` (hollow `StatusDot`), `LastSeenCellView` (semibold primary when offline) |

Also defaulted: the app is a single `Window`, not a `WindowGroup` — the scan runs from the
window's `.task(id:)`, and two windows over one model would run it twice. Bundle ids stay
`com.jctec.zhen` / `com.jctec.zhen.helper` (the brief's `AssociatedBundleIdentifiers`
value), against the house rules' `dev.jc.<app>`.

## Provisional — waiting on the designer's round 3

Every metric is a token, so round 3 changes a token, not a layout:
`Utilities/Dimension.swift` (event-kind column 140, histogram 64, device tile 44, table
intercell 17), `Utilities/WindowSize.swift` (sidebar 180–220, NAME minimum 200, Settings
560 × 640), and the type ramp, which is phase 1's text-style map unchanged. Row height is
the `Table`'s own (40 pt with a two-line name cell, measured from accessibility frames);
A1's 52 is not reachable without hand-building rows, which is the mistake this app was
demolished for.

## Stage A — the foundation · done

### A1 · The project tells the truth

Read back from the build, not from the project file:

    $ xcodebuild -target Zhen -showBuildSettings | grep …
        ENABLE_APP_SANDBOX = NO
        ENABLE_HARDENED_RUNTIME = YES
        INFOPLIST_FILE = Zhen/Info.plist
        SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
        SWIFT_STRICT_CONCURRENCY = complete
        SWIFT_TREAT_WARNINGS_AS_ERRORS = YES
    $ codesign -dv Zhen.app      →  flags=0x10000(runtime)
    $ codesign -d --entitlements - Zhen.app   →  only com.apple.security.get-task-allow (Debug)

No entitlements file, no sandbox keys. `NSLocalNetworkUsageDescription` is a build setting
(`INFOPLIST_KEY_…`), in plain words.

`NSBonjourServices` cannot be a build setting (arrays are not supported), so it is a
partial `Zhen/Info.plist` merged with the generated keys, **written by
`Scripts/generate-bonjour-services.sh`** from `BonjourVocabulary.serviceTypes` in the
zhen-core release the project resolves (17 types, rank order). `--check` fails on a stale
plist; CI runs it. The plist is excluded from the synchronised group's resources.

| Gate | Test | Shown failing on |
|---|---|---|
| Built app's `NSBonjourServices` == `BonjourVocabulary.browsedTypes` | `InfoPlistTests.bonjourServicesMatchTheVocabulary` | `_hue._tcp` deleted from the plist → `Expectation failed: (declared → [… 16 types …]) == (BonjourVocabulary.browsedTypes → [… "_hue._tcp" …])` |
| Unsandboxed at runtime | `InfoPlistTests.appIsNotSandboxed` | `ENABLE_APP_SANDBOX = YES` (Debug) → `APP_SANDBOX_CONTAINER_ID → "com.jctec.zhen"` |

### A2 · The fixture network

Captured 2026-10-10 16:34 from this Mac on en0, default route into 10.10.20.0/24 (the home
LAN; checked before running), with **zhen 0.6.0 built from the tag into scratch** — the installed `zhen` was 0.5.0
and the app decodes 0.6.0's schema. Two runs, unprivileged: `scan --json` and
`scan --json --deep --scan-type connect`. `ZHEN_HISTORY` pointed at a scratch file; the real
store's SHA-256 was `d735909a…d239a` before and after (and after every later step).
Raw output stays in the session scratch directory, outside the repository.

The real LAN already holds the acceptance case: 13 hosts, **5 with a randomised MAC and no
name** (vendor is null for every host — 0.6.0 has no OUI lookup), 3 named over Bonjour
(one long Spanish name, one with a typographic apostrophe), 2 offering open ports. None
had to be added.

Transform: `Scripts/anonymise-scan.py` (stdlib Python, run with `-I`), output
`Zhen/Fixtures/home-network.json`. MACs → RFC 7042 documentation block (universal) or
synthetic locally-administered; IPv4 → `192.168.50.x`, order kept, gateway `.1`; link-local
IPv6 rebuilt from the rewritten MAC when EUI-64, else synthetic; names by class from a pool
(no real→synthetic table, which would publish the real values); TLS subjects and banners
only when they are bare product strings; filtered ports dropped; times moved to
2026-01-01. Byte-stable: two runs → identical SHA-1 `26bd21f5…`.

| Gate | How | Shown failing on |
|---|---|---|
| No raw identifier survives | `anonymise-scan.py --verify raw fixture` — 37 raw MACs, addresses, names, run id | the raw report checked against itself → `37 of 37 raw identifiers appear in the fixture — FAIL` (the output names the kind and length, never the value) |
| Decodes, holds the acceptance case, only synthetic ids | `FixtureNetworkTests` | — (assertions over committed data) |

History: `FixtureNetwork.history` lays 11 runs over 48 hours, one change per run, and folds
them through `InMemoryHistoryStore` — so every event in Activity was derived by core's
ledger: appeared ×3, left ×3, address changed, renamed. `merged` is not staged (Q5).
Variants: `home`, `unidentified` (every name, vendor, model stripped, every MAC randomised),
`empty`, `partial` (deadline + core's own name-silence sentence), `silent` (zero devices +
core's Local Network sentence, built with `LocalNetworkDenialHeuristic`).

**Bend — fixture location.** The superseded 2A brief said "a test-target resource plus a
preview container". The fixture is an **app** resource: `-UITesting` and `-ShowcaseData`
launch the app itself, which must find it. It is synthetic, so shipping it costs 13 KB.

### A3 · The harness

| Gate | Test | Shown failing on |
|---|---|---|
| Keyboard-only | `KeyboardUITests` (3 flows: Devices + detail + search; Activity + filters; scan + stop + Settings) | room shortcuts removed → `activityList never appeared after ⌘-key 2 ×3` |
| Window size range | `WindowSizeUITests` — minimum and full screen: pinned elements and every cell inside the window, no column under 20 pt, sidebar ≥ its minimum | the declared 860 minimum restored → `sidebar (57, 154, 222, 421) leaves the window (165, 102, 862, 534)` — F2 itself |
| Restoration | `RestorationUITests` — ⌘Q, relaunch: window size, open device, room | `restore()` not called → `deviceDetail never appeared` after relaunch |
| Four appearances | `AppearanceUITests` — Devices, Activity, detail, Settings × light / dark / lightIncreased / darkIncreased, kept as attachments; dark surface < 0.25, light > 0.75, Increase Contrast changes pixels | pinned scheme ignored → `the light capture is not light (surface luminance 0.2085)` |
| Acceptance case | `AcceptanceUITests` — all-unidentified fixture at default and minimum: one row height, 5 columns ≥ 20 pt each, every name "Unidentified device" | unidentified name left blank → `row 0 names itself ', online, minimal, …'` |
| Scan off the main actor | `ScanPipelineTests` — compile: a synchronous `nonisolated` function constructs `ScanPipeline`. Run: driven from the main actor, the app's fixture scanner emits 0 of its events on the main thread | compile: `@MainActor struct ScanPipeline` → `error: call to main actor-isolated initializer 'init(runner:interval:clock:)' in a synchronous nonisolated context`. Run: the scanner hops (`await MainActor.run { progress(…) }`) → `onMain → 11 == 0` failed |

**Two breaks that did not fail the off-main gate, and why — measured, not assumed.**
(1) Dropping `@concurrent` from `ScanPipeline.run`: an experiment showed a nonsending
function's code runs on the main actor (`direct=true`), but the body of a `withTaskGroup`
inside it does not (`viaGroup=false`) — the pipeline's task group already moves the scan
off. `@concurrent` stays as the stated intent. (2) Dropping `nonisolated` from
`FixtureScanRunner`: a type that states `Sendable` does not take the target's MainActor
default, and the dangerous spellings (`@MainActor` on the type or on `run`) do not compile
against the nonisolated protocol. So the type checker holds those lines; the runtime gate
holds the one it cannot see, a hop inside the scanner.

**Also not a break of the acceptance claim:** letting the subtitle wrap (removing its
`lineLimit(1)`). The test still passed — a SwiftUI `Table` gives every row one height by
construction, so wrapping text is clipped, not grown. The break that matters for that
claim is an unidentified row that says nothing, and that one fails.

### A4 · CI can run it

`ci.yml` keeps the Linux token job and adds `app` on `macos-26`: select the newest Xcode
26, `generate-bonjour-services.sh --check`, then `xcodebuild test` on the `Zhen` scheme
with ad-hoc signing (`CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=`, so
forks run it unchanged), uploading `fastlane/test_output` always. The same flags were run
here: 21 unit tests + the launch UI test pass. **Never run on GitHub** — the branch is not
pushed (Q1). Green on a runner is unverified; this says so rather than claiming it.

### Findings worth keeping (each cost a failed run)

- **A valueless launch flag must come last.** `-UITesting -Fixture home` is read by AppKit
  as the default `UITesting = "-Fixture"` plus a stray `home`, which it treats as a
  document to open — and an app opening a document skips its untitled window. Symptom:
  "the main window never appeared", process idle, `NSDiscardWindowsOnDocumentOpen` in the
  log. The robot puts `-UITesting` last.
- **SwiftUI's `Table` is an outline to accessibility** on macOS 26; its rows report
  disabled and refuse `click()`. Tests query by identifier, and select by keyboard or by a
  coordinate inside the row (never in the keyboard gate).
- **Return does not reach `contextMenu(primaryAction:)`** — only a double-click does.
  Return is handled with `.onKeyPress(.return)` on the table.
- **⌘F did not focus `.searchable`** on its own; a Find… command sets `searchFocused`.
- **Window state leaks across `-ApplePersistenceIgnoreState` launches** (AppKit writes it
  to a temporary location and the next flagged launch reads it). Under fixtures the app
  now restores only with `-RestoreState`, and resets before its first `await`, or a fast
  shortcut from the test is undone by a late reset.
- **These UI tests run on a desktop in use.** Another app's menu-bar popover took key focus
  mid-run and swallowed an Esc. The robot activates the app before each key, and re-sends
  an idempotent shortcut up to three times when the menu item was disabled during
  re-activation. A missing shortcut still fails all three (re-shown failing after the
  change). Recordings of the failures show the whole screen, so result bundles stay in
  scratch and nothing from them is committed.
- **A whole-screen fallback in a test captured other apps.** The Settings capture now
  finds the window holding the settings form, and fails rather than fall back.

### Design bends, each with what forced it

| Bend | Measurement |
|---|---|
| Window minimum is computed (sidebar 220 + 8 inset + measured table), not declared | at a declared 860 the table needed 1 087: cells ran to x 1160 in a window ending at 1027, then the split view pushed the sidebar off-window (gate output above) |
| Link-local IPv6 shown without `%en0` in the table (full form in the tooltip and detail) | the scope made the address column 220 pt wide — the widest column, on rows that are a minority |
| Table rows are 40 pt, not A1's 52 | `Table`'s own row height with a two-line cell, measured from accessibility frames; a hand-built row is out of scope by the brief |
| Event kind column 140, not "fits" | at 120, "ADDRESS CHANGED" overran by ~9 pt and pushed that row's sentence out of line (screenshot, activity-light) |
| Column headers are the system's, not A1's 11 pt tracked capitals | `TableColumn` titles are drawn by AppKit's header; restyling them means abandoning `Table` |
| Prominent buttons and the Activity picker follow the person's accent | `.borderedProminent` and segmented pickers take the system accent (green on this Mac, `AppleAccentColor = 3`); the app's accent token stays purple in chips, meters and links. Same reasoning as decision 7 |
| Toolbar Scan Now keeps its words (`.labelStyle(.titleAndIcon)`) | a toolbar drew it as a lone glyph, and it is the room's one primary action |
| A2's ConfidenceMeter is phase 1's `SignalMeter`, given an `init(Identification)` and its own accessibility name ("Identity") | the brief: reconcile, don't duplicate |
| Subtitle is sentence case with its own capitals ("in ARP table", "AppleTV5,3") | lower-casing every part after the first wrote "arp" |
| No `Color(hex:)`-style tokens added; two token enums added (`Dimension`, `WindowSize`) | `check-tokens.sh`: 83 files, 0 literals, 0 allow-comments |

### Code that landed ahead of its stage

The harness needs screens to drive, so the Devices table, the detail, the live-scan
takeover, Activity and Settings were written in this stage. Their own gates (coalescing
excepted, which is A3's off-main sibling and already passes) are run and recorded at
stages B–F; nothing here claims them.

## Stage B — Devices and detail · done

`Table` with `KeyPathComparator` sort, `Set<DeviceItem.ID>` selection,
`contextMenu(forSelectionType:primaryAction:)`, `.searchable`, `.toolbar` — built in A,
proven here. Columns measured from the rows on screen, NAME takes the rest (A's bends).
Detail: one column of four cards — identity history, Known by, open ports, recent events —
no Omada column and nothing laid out around its absence.

| Gate | Test | Shown failing on |
|---|---|---|
| Identity, order, subtitle, reassignment, link-local form, measured columns, search | `DeviceItemTests` (10) | **the address sort failed on a real bug** (below) before it was fixed |
| Sorting by a column, both directions | `DevicesUITests.testSortingAndSearch` | the same bug: `.10, .13, .28, .31, .1, .16 …` under "IP Address ↑" (screenshot) |
| Never scanned: empty state with Scan Now, footer says so | `testNeverScanned` | footer title blanked → `the footer is never empty` |
| First run streams rows; never a spinner over an empty table; hands back | `testFirstScanStreamsRowsNeverASpinner` | batches held to the end (interval 1 h) → the first host did not arrive while discovery ran |
| Loaded from a partial run: amber footer dot + persistent notice opening the degradation rows | `testPartialRunSaysSoAfterTheFact` | `latestRunIsPartial` forced false → `partialRunNotice never appeared` |
| Nothing answered: named, actionable, not an empty list | `testNothingAnsweredIsExplained` | Local Network sentence not recognised → no "appears to be denied" cause |
| Context menu mirrors the Device menu | `testContextMenuMirrorsTheDeviceMenu` | "Scan Ports" renamed → `the context menu has no Scan Ports` |
| Four blocks, winner chipped, losers shown, port as `5000/tcp`, rename among events | `DeviceDetailUITests.testFourBlocksForANamedDevice` | Known by removed → `knownByCard is missing` |
| An unidentified device's detail is normal: every source says "— not advertised", Scan Ports offered | `testUnidentifiedDeviceIsANormalDetail` | absence rendered as "" → `Assigned hides its absence` |
| Rename is local and wins, in detail and table | `testRenameIsLocalAndWins` | name not kept → `knownBy-You` never appeared |
| The app does not repeat CLI-only advice | `FixtureNetworkTests.silentVariant` | `forTheApp` bypassed → the sentence "…under the terminal application…" present |

Two breaks first failed to compile (warnings are errors: an unused binding) and were
re-spelled so the build succeeded and the test failed — a compile error proves nothing
about the gate. One break **passed**: deleting "Scan Ports" from the context menu, because
`app.menuItems["Scan Ports"]` also matched the menu bar's Device ▸ Scan Ports. The test
now requires each item to be on screen, and fails on the same break.

### Bugs the gates found

- **Address sort was not numeric.** `KeyPathComparator` over a `String` uses
  localized-standard comparison, which reads digit runs as numbers: the hex key `…8320a`
  (.10) sorted before `…83201` (.1). The key is now core's own `Comparable` `IPAddress`,
  and the MAC key the MAC's raw value, which had the same trap.
- **`extension DeviceItem` without `nonisolated`** compiled, and crashed the first time a
  nonisolated test called `DeviceItem.rows` — in a MainActor-default target an extension's
  members take the default even when the type is `nonisolated`. Every extension of a
  nonisolated type is now marked.
- **The rename field did not have focus** when the sheet opened; typing went nowhere. It
  takes focus, and Return confirms.
- **"Resolving name…" after Stop.** A stopped scan still said a name query was in flight.
  `isNamingPending` is false unless the scan is running.
- **Core's Local Network remedy ends with CLI advice** (Q6); the app drops that sentence.

### Bends

| Bend | Why |
|---|---|
| Before history loads, Devices shows nothing (`Color.clear`), not a spinner | "never a spinner over an empty table"; the load takes milliseconds |
| Return opens a row through `.onKeyPress`, not the primary action | measured in A: Return never reaches `primaryAction` |
| Rename keeps the name in this app's defaults, keyed by device identity | A3: local only, source "You", always the winner. The command line does not see it — the history file has no field for it (see stage F) |
| The unidentified detail's header tile is `questionmark.circle` | A1's `unknown` symbol; the kind is guessed only from a model or name, never from nothing |

### Test-robot changes, and why

Rows, headers and context menus are clicked at their centre (accessibility calls them not
hittable). Opening a row and opening a context menu re-try up to three times after
activating the app, for the same reason as A's shortcuts: the desktop is in use, and
another app's window was seen over Zhen mid-run (Q7).

## Stage C — Live scan · done

Replaces the Devices content while a scan runs: "Scanning 192.168.50.0/24", "Stage n of m ·
0:07 elapsed · 4 devices so far", three `StageCard`s (Discovery, Naming, Deep scan — the
last "Not requested" unless asked), the `DegradationBanner` when anything degraded, and
"Found so far · newest first". A host that naming has not reached reads *Resolving name…*
in italic secondary, with "found 4 s ago · name query in flight". Header, stages and banner
are pinned; only the list scrolls (A3).

| Gate | Test | Shown failing on |
|---|---|---|
| **Coalescing**, at the view model: 50 000 hosts in 0.4 s reach `ScanSession` in ≤ one batch per 16 ms frame, none lost, applied in < 3 s | `ScanSessionTests.coalescesIntoTheViewModel` (and A's pipeline gate) | tick of 50 µs → `publishedBatches 69 <= frames + 2 → 28` failed; `apply` searching linearly again → `elapsed 150.9 s < 3 s` failed |
| **Degradations do not evaporate**: a run that degrades during naming still shows it on Devices after the hand-back — amber footer, notice, the same rows | `LiveScanUITests.testDegradationsSurviveTheHandBack` | `lastDegradations = []` at hand-back → the notice had nothing to disclose (`partialRunDisclosure` absent) |
| Starting → "Listening…", stages queued, deep scan not requested | `testStartingThenNamingThenHandBack` | — (asserted on the way) |
| Mid-naming placeholder | same | placeholder replaced by "Unidentified device" → assertion at line 22 |
| Done → hands back to Devices, no dismissal | same | phase left `.stopped` at completion → `the scan never handed back` |
| Stopped → results kept, "Stopped after 0:0x · n devices found", Scan Again restarts, nothing claims a name in flight | `testStoppedKeepsWhatItFound`; `ScanSessionTests.stoppedKeepsResults` | arrivals cleared on stop → `stopping discarded the results` (first attempt failed a step early on a dropped shortcut; re-run, then the unbroken test re-run green) |
| Session rules: arrival order, in-place updates, stage states, degradation de-duplication, hand-back | `ScanSessionTests` (6) | — |

### Found by the gates

- **`apply` was quadratic.** Coalescing held the batch count to display rate, and each
  batch then cost O(n²): a linear search inside the batch and a re-index of every row.
  50 000 hosts took **88 s** on the main actor — the frame-time tail the gate exists for,
  moved inside the batch. Hosts are now stored in arrival order with a position index
  (`found` is the reversed view): 0.47 s. The gate asserts the time, and fails at 150 s
  with the linear search put back.
- **Scan Now was disabled right after launch** — the window had not yet published its
  focused value, so ⌘R did nothing. Scanning belongs to the app (one window, one model):
  Scan Now and Stop Scan now act on the model; room and device commands still reach the
  window through `@FocusedValue`. Bend recorded below.

### Bends

| Bend | Why |
|---|---|
| Scan Now / Stop Scan in the menu bar act on the model, not through `@FocusedValue` | measured: right after launch the focused value is nil and the shortcut is dropped. The house rule protects multi-window apps from acting on the wrong window; this app has one window |
| "Name query in flight" names no protocol per host | core's progress events say which stage runs, not which query is outstanding for a host; the card says "Asking Bonjour, UPnP and NetBIOS", which is what the naming stage does |
| A window's `hasKeyboardFocus` is not used by the robot | measured: it reads 0 even when the window is key |
