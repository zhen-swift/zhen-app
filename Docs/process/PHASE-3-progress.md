**Liveness:** 2026-10-11 — part 3 in progress: Spanish done; new-device notifications next.

# Phase 3 — fill in what phase 2 left thin, progress

JC tried the phase-2 release and found a lot still missing. This run fills it in, with the
same rules as phase 2 (`zhen-agents/rules/house-rules.md` == `AGENTS.md`, the phase-2
brief's working rules): no stopping to ask, every gate shown failing on a deliberate break
before it is recorded as passing, every design bend recorded here with the measurement
that forced it. Questions: `PHASE-3-questions.md`.

**JC's choices for this run (2026-10-11):** the app only, with zhen-core frozen at 0.6.0;
all four areas (device detail depth, scanning behaviour, settings and housekeeping, the
release/store layer); UI tests may run, with the desktop kept free.

Branch `phase-3`, off `phase-2` at `f1ef1f8`. Not pushed.

**To resume:** read the liveness line, then the last stage section. Unit gates run with
`xcodebuild -project Zhen.xcodeproj -scheme Zhen -destination 'platform=macOS' test
-only-testing:ZhenTests`; UI gates name their test. Deliberate breaks were run with a
throwaway script that applied one edit, ran the named test and restored the file.

The real history file (`~/Library/Application Support/zhen/history.ndjson`) is never opened
by a test. Its SHA-256 begins `d735909a`, checked at the start of the run.

## Stage 1 — the scanning bugs

Found by reading the code against zhen-core 0.6.0 after JC's test, not by any gate phase 2
had: each of these was a wrong answer on screen with every test green.

### 1. Scan Ports took the whole network offline

Every Scan Ports entry point ran `startScan(deepScan: true, network: /32)`. `ScanRunner`
records every run it finishes. Core judges presence by the latest run alone
(`HistoryLedger.devices()`: `isPresent = lastRunID == latestRun.id`) and emits `disappeared`
for every record the run did not see. So one Scan Ports made the /32 the latest run,
reported every other device as gone, set the footer to `x.x.x.x/32`, and re-keyed device
IDs to the /32 (`DeviceItem.identity` reads the latest run's network).

**Fix, app-only:** `HistoryStore` is a public protocol. `ProbeOnlyStore` passes reads through
to the real store and makes `record` a no-op. A per-device port scan runs a `ScanRunner`
over it (`ScanRequest.records = false`), and its ports go into `NetworkModel.portScans`,
which lasts for the session. The scan no longer takes over the window: Scan Ports opens the
device and the Ports card shows progress, then the result.

**Bend:** a single-device port scan is **not kept in history**. The card says so ("Scanned
14:02 · this session, not saved to history"). A full scan with ports on saves them, and
clears the session's results. The durable fix needs core: a port-scan API that is not a run,
or presence judged per scanned subnet (Q1).

| Gate | Test | Shown failing on |
|---|---|---|
| Other devices stay present; latest run, events unchanged | `ScanningBehaviourTests.portScanKeepsTheNetwork` | `records: true` in `performPortScan`: `onlineCount 1 == 11`, latest run changed, events 18 vs 8 |
| The live runner never writes on a probe-only request | `ScanningBehaviourTests.liveRunnerProbeOnly` | `make(store)` instead of `ProbeOnlyStore`: latest run and presence both changed |
| On screen: counts unchanged after a port scan | `DeviceDetailUITests.testPortScanLeavesTheRestOnline` | `records: true`: title read "13 devices · 1 online" against "· 11 online". **The first break did not fail it.** The model never reread history after a port scan, so the damage stayed invisible until the next reload. `performPortScan` now rereads, and the break fails it. |
| ⇧⌘R opens the device, shows progress, ⌘. stops it in place | `CommandsUITests.testDeviceShortcuts` (rewritten: it used to assert the /32 takeover) | the stage-F breaks in this test still hold; this part is new behaviour asserted directly |

### 2. Installing the helper did nothing until a relaunch

`LiveScanRunner` built one `ScanRunner` and kept it for the app's lifetime. Core decides at
construction whether the helper's capture device is there.

Rebuilding per scan was the first fix, and **measurement refused it**. A scratch harness
timed `ScanRunner(store:)` five times on this Mac, without scanning:

| Capture | Build time |
|---|---|
| `helperThenDirect` (default) | 3.15–3.20 s |
| `ZHEN_CAPTURE=direct` | 0.24–0.71 ms |

The 3.2 s is `HelperClient.timeoutMilliseconds = 3_000`. This Mac still has a helper
registered by the monorepo-era build, whose bundle is gone, so launchd's spawn fails and
the connection waits out the timeout. Rebuilt per scan, every scan would have paid it.

**Fix:** keep the engine until the helper's state changes (`LiveScanRunner.note(_:)`,
called before each scan with `HelperService.state`). It is also dropped after a scan that
finds nothing, which is what a network change looks like. Engines are built lazily: the
probe-only one only when a port scan needs it.

| Gate | Test | Shown failing on |
|---|---|---|
| Same helper state: one build. Changed state: a fresh one | `ScanningBehaviourTests.freshEngineOnHelperChange` | first version (rebuild per scan, `freshEnginePerScan`): `latest ?? make(…)` gave `built 1 == 2`. Current: `note` without the reset gave `built 1 == 2` |

### 3. A scan run in a terminal never reached the open window

The app read history at launch and after its own scans. `LogHistoryStore` re-reads the file
on every call, so the gap was only that nothing ever asked.

**Fix:** `HistoryWatcher` polls the file's inode, size and modification time once a second.
`NetworkModel.watchHistory()`, a `.task` on the window, rereads history on each change.

**Bend: polling, not a vnode source.** Compaction replaces the file by rename, so a source
on the old inode goes silent at the moment history changes most, and before the first
scan there is no file to watch. Re-arming across both is a state machine; one `stat` a
second is not.

A race, caught by the gate: the watcher took its baseline inside its polling task, so a
write landing before the first poll was never reported. The test failed once in two full
runs. The baseline is now taken when the stream is made, and `watchHistory` reloads once
after making it.

| Gate | Test | Shown failing on |
|---|---|---|
| Another process's write reaches the model | `ScanningBehaviourTests.terminalScanAppears` (writes after the watch is under way) | `continuation.yield()` removed: devices stayed `[]` |
| Append, replace by rename, and a file appearing are each reported | `ScanningBehaviourTests.watcherSeesEachKindOfChange` | the same break: all three `reported(n)` false |

The first version of the second test awaited the stream with no timeout, and the break hung
the run. It now counts reports against a deadline.

### 4. Smaller

- **"Deep-scan new devices" probed every device on every scan.** Core's port stage is one
  switch per run. **Bend:** relabelled "Check ports on every scan"; the defaults key is
  unchanged. Limiting it to new devices needs core (Q1).
- **The scan budget was always 30 s.** It is now a Settings picker (10, 20, 30, 60 s; any
  other value falls back to 30), read by both kinds of scan.
  `ScanningBehaviourTests.budget`.
- **Retention was applied only while Settings was open.** It is now also applied at
  `load()`, so it holds for every run a launch records.
- **The subnet override's error** now says what happens meanwhile: scans use the
  automatic network.
- **Scan Again** reruns the stopped request exactly (`NetworkModel.scanAgain`). It used to
  call the /32-capable entry point that no longer exists.

Unit suite: 58 tests, green three runs in a row after the race fix.

## Stage 2 — device detail depth

| Change | Where | Gate |
|---|---|---|
| **Known by lists every name each source offered.** It showed one per source (`.min()`), which hid exactly the losing names that make the card worth having (APP-PLAN §6). A repeated value at different ranks is one offer. Later offers from the same source leave the source column blank | `DeviceItem.nameOffers`, `KnownByCardView`, `SourceRowView` | `DetailDepthTests.everyCandidate`. Break: `.prefix(1)` gave `["Living Room"]` against `["Living Room", "AirPlay Speaker"]` |
| **Identity caption is A3's sentence.** It was "stability moderate", a raw value. It is now "identity key: rotating MAC, stabilised by Bonjour name" | `DeviceItem.identityCaption` | `DetailDepthTests.identityCaption` asserts no raw `Stability` value appears |
| **Identity history rows are every merge, rename and address move**, dated, under the current MAC | `IdentityCardView`, `DerivedEvent.Kind.isIdentityChange` | `DetailDepthTests.identityKinds` |
| **Recent events carry a date** for anything not from today. Activity keeps time only, under its day headers | `EventRow(showsDate:)` | seen in the detail capture |
| **Ports caption tells the truth** (stage 1): the session scan's time, or the latest run's when it checked ports and saw the device, else "From an earlier scan that checked ports". It used to print last-seen as the scan time | `PortsCardView.caption`, `ScanRun.checkedPorts` | — |
| **Live scan rows show MAC, vendor, and "matched to …"** when history knows the host by its MAC. An address alone matches only when neither side has a MAC | `FoundHostRowView`, `NetworkModel.knownDevice(for:)` | `DetailDepthTests.knownDeviceMatch`. Break: match by address gave the gateway's record for a stranger at its address |
| **Finished stages show their time**, core's `elapsedMillis`: "13 hosts answered · 1.2 s". The fixture scanner now reports each stage's own time, as core does, not time since the scan began | `ScanSession.stageDurations`, `LiveScanView.detail(of:)` | `DetailDepthTests.stageDurations` |
| **A helper degradation offers "Review in Settings…"**, which opens Zhen's Settings. Before, it offered Scan Again, which does nothing for a missing helper | `DegradationCopy.Action.reviewHelperSettings`, `DegradationBanner` | `DetailDepthTests.helperDegradation`, with core's helper-absent sentence verbatim. Break: the branch never matched, so the action came back `.scanAgain` |
| **Show in Activity starts from All.** It kept whatever segment was selected, so a device could arrive under Ports showing nothing | `RootView.showActivity` | `ActivityUITests.testShowInActivityStartsFromAll`. Break: the reset removed, so it failed with "arrived under the Ports segment, showing nothing" |
| **Partial-run strip says "N sources unavailable"** (A3's copy) | `PartialRunNoticeView` | `DevicesUITests.testPartialRunSaysSoAfterTheFact` |

**Bends:**
- **Identity history is not one row per MAC.** A3 asks for that, with date ranges. zhen-core 0.6.0 keeps only the current MAC on a `Device`. Its `merged` event says "was tracked as two devices", not which addresses those were. So the rows are the identity changes core did record. One row per MAC needs core to keep prior MACs (Q1).
- **The `reassigned` chip stays on the name line**, not on its own line under the subtitle as A3 asks. A3 measured width; a third line costs height instead. That would make the reassigned row the only three-line row in a `Table` whose acceptance gate (`AcceptanceUITests`) requires every row to be the same height. On the name line it costs no height. It shares only with the name, and "Unidentified device" plus the chip fits the 200 pt NAME minimum.

**Caught by a screenshot, not a gate:** `^[N identity change](inflect: true)` rendered literally in the caption. `String(localized:)` without a catalog entry does not inflect. The partial-run strip had the same markup. Both are now spelled out per count until `Localizable.xcstrings` (stage 5). The header's "1 independent source" uses `AttributedString(localized:)`, which does inflect, and was correct.

**Seen, not fixed here:** a `devices-partial` capture came out half-drawn, with placeholder rows and an empty sidebar. The test's assertions read accessibility and passed. This is phase 2's Q7 again, a capture taken mid-redraw. It belongs to stage 5's screenshot work.

UI: `ActivityUITests`, `DeviceDetailUITests`, `DevicesUITests`, `LiveScanUITests`, 17 tests, all green. Unit: 65 green.

## Stage 3 — Settings and housekeeping

| Change | Where | Gate |
|---|---|---|
| **One window.** The main scene was a `WindowGroup` from stage A until now, despite the phase-2 ledger's "a single `Window`" and a comment saying so in `ZhenApp.swift`. ⌘N opened a second window over the same model, and both windows' `.task(id: scan.runToken)` ran the same scan | `ZhenApp`: `Window("Zhen", id: "main")` | `CommandsUITests.testThereIsOneWindow`. Break: back to `WindowGroup` and ⌘N made a second window. `RestorationUITests` still passes under `Window` |
| **Export History…** (File, ⇧⌘S, and in Settings): JSON with every device (core's `Codable` `Device`, plus the name shown and presence), every event in a shape this app owns (core keeps `DerivedEvent` off the wire on purpose), and the latest run. Write-only | `HistoryExport`, `HistoryDocument`, `.fileExporter` in `RootView` and `SettingsView` | `HousekeepingTests.exportHoldsEverything`. Break: events emptied gave `0 == 8`. `SettingsUITests.testVersionHistoryAndExport`. Break: the button never set the document, so "Export opened no save panel". `CommandsUITests.testExportShortcut` |
| **Settings shows the version and the history file**: "Zhen 1.0 (1)", pinned above the form (A3: "Settings: title and version"). The file's size, Show in Finder, Export. Under a fixture it says so rather than show a size | `SettingsView.versionLine`, `historySize`, `Finder.reveal` | `HousekeepingTests.versionLine`, `SettingsUITests.testVersionHistoryAndExport` |
| **Retention applied at launch** (stage 1) | `NetworkModel.load()` | `HousekeepingTests.retentionAtLaunch`. **Its first version passed with the policy never applied.** It dated its "nine days later" run from the capture's own run, which is in January 2026, months before the fixture's history, so nothing was ever old enough to prune. It now dates from the store's latest run, and the break (no `applyRetention` in `load()`) fails it |
| **Status without colour.** With Differentiate Without Colour on, each tone draws its own symbol. Online and warning were both filled dots differing only in hue, with the same footer words ("Last scan 6 min. ago") | `StatusDot`, `StatusDot.Tone.symbol` | `StatusDotShapeTests.distinctShapes`. Break: warning given online's symbol gave 5 shapes for 6 tones |
| **Reduce Transparency**: no change needed. The only translucency is system materials (`.bar`, `.regularMaterial`), which macOS makes opaque under that setting itself | — | — |

**A test race, found on the way:** every fixture `NetworkModel` clears the shared `com.jctec.zhen.fixture` defaults domain when it is made. That is right for one app, but parallel unit tests wiped each other's settings between `set` and `load`. The retention test failed in the full run and passed alone. `NetworkModel(environment:defaults:)` now takes a test's own domain.

**Never seen passing in phase 2, now passing:** `SettingsUITests.testHelperPanelInstallApproveRemove`, with its helper-version wait.

UI: `SettingsUITests` (4) and `CommandsUITests` (5), green. Unit: 70 green, three runs in a row.

## Stage 4 — the outstanding phase-2 gates, on a quiet desktop

**The full UI suite ran: 37 tests, all green** (`ZhenUITests`, about 11 minutes). This is
the run phase 2's verification step 0 asked for. A notification banner from another app
showed in one capture; no window took focus.

**Never seen passing in phase 2, now passing:**
- `WindowSizeUITests.testDetailAndTakeoverFitAtBothSizes`
- the live-scan captures in `AppearanceUITests`, in all four looks
- `SettingsUITests.testHelperPanelInstallApproveRemove` (stage 3)

**Never shown failing in phase 2, now shown failing:**

| Gate | Break | Failure |
|---|---|---|
| `CommandsUITests.testEveryActionIsInTheMenuBar` | Copy MAC Address retitled to nothing | "Device ▸ Copy MAC Address is missing" |
| `AccessibilityAuditUITests.testEveryScreen` | Export… lost its identifier | "Settings: a button named 'Export…' has no identifier", in both Settings states |
| `WindowSizeUITests.testDetailAndTakeoverFitAtBothSizes` | `.frame(minWidth: 1600)` on the detail | "detailName (102.5, 175.0, 180.0, 20.5) leaves the window (165.0, 102.0, 1095.0, 534.0) at minimum, detail" |

### A real defect the captures found: Settings wrote the person's real preferences

The light-appearance Settings capture showed a subnet override of `192.168.7.0/24` on a
fresh fixture launch. `com.jctec.zhen.plist`, the installed app's own preferences, held
`subnetOverride = 192.168.7.0/24`. `SettingsUITests` types that subnet.

`SettingsView` applied `.defaultAppStorage(model.defaults)` inside its own body. A view's
own `@AppStorage` reads the store its parent provides, so the modifier reached only the
children, and the Settings scene provided none. So:
- under fixtures, every Settings control wrote the real app's domain
- the fixture model read its own domain, so the setting never reached a fixture scan
- the installed app would have scanned `192.168.7.0/24` on its next launch

**Fix:** `.defaultAppStorage(model.defaults)` on the Settings scene's content in `ZhenApp`,
the way the main window already had it.

**Gate:** `SettingsUITests.testSubnetOverrideIsValidated` now carries the override through
to a scan. The footer must name `192.168.7.0/24` after ⌘R. Break: the scene-level modifier
removed gave "the scan ignored the override: … 192.168.50.0/24 · en0". The real domain is
cleared at the end of this run, after the last UI test (stage 5).

**Also fixed on the way:**
- **Fixture defaults were reset unreliably.** `removePersistentDomain` from a fresh instance
  left cached values readable. The fixture domain is now cleared key by key, through the
  instance in use.
- **The Override label inherited the field's monospaced face.** The field now sits in a
  `LabeledContent`.
- **The footer said "Last scan in 0 sec."** for a scan that had just finished. It now says
  "just now" under a minute.
- **Live-scan rows hid the MAC and vendor while a name query was in flight.** They now show
  both, with the query last.

## Stage 5 — the store layer (phase 2's stage H)

| Piece | Where | Evidence |
|---|---|---|
| **App icon.** The AppIcon set had no images, so the app had none, and Login Items would have shown a generic one. It is generated from the design mark | `Scripts/generate-app-icon.sh`, `Zhen/Assets.xcassets/AppIcon.appiconset` | Q6 |
| **String catalogue.** 243 strings from the compiler's extraction (`xcstringstool sync`). Plural forms for the 10 counted strings, three of them with several arguments | `Zhen/Localizable.xcstrings`, `Scripts/catalog-plurals.py` | `PluralTests.singular`. Break: the `one` form removed gave "1 identity changes" |
| **Screenshot mode.** `-WindowSize 1440x900` fixes the window at that size, toolbar included | `AppEnvironment.windowSize`, `ZhenApp`, `WindowSize.toolbarHeight` | measured twice. `defaultSize` alone lost to AppKit's saved frame (1093 × 532). A 900 pt content size made a 952 pt window: the toolbar is 52 pt and counts against the slot |
| **Captures.** Five ids, `-ShowcaseData` only, settle 1.5 s before each, exact window size asserted. Skipped unless `ZHEN_SCREENSHOTS=1` reaches the runner, so `test` never runs them | `ZhenUITests/AppStoreScreenshotUITests.swift` | five 2880 × 1800 captures |
| **Export.** Attachments by id. Anything not 2880 × 1800 is refused | `Scripts/export-screenshots.sh` | — |
| **Renderer.** AppKit: gradient, black title, semibold subtitle, rounded clip with shadow and white hairline. App Store plain and captioned, README hero 2400 × 1000, feature tiles 620 px wide, app icon. Missing capture: prints every path tried, exits 1. Never upscales | `Scripts/generate_appstore_assets.swift`, `Marketing/copy.json` | rendered all 17 outputs into scratch |
| **fastlane** 2.241 under Ruby 4.0, gems in `vendor/bundle`. Lanes `test`, `unit`, `ui`, `screenshots`, `marketing`, `release` | `Gemfile`, `Gemfile.lock` (four platforms), `fastlane/Fastfile` | `bundle exec fastlane unit` green; JUnit and `.xcresult` in `fastlane/test_output` |
| **CI**: `ci.yml` runs `bundle exec fastlane test` with a SwiftPM cache. `screenshots.yml` renders from committed captures | `.github/workflows/` | YAML parses; never run on GitHub (Q3) |
| **Docs**: ARCHITECTURE (ends in Known rough edges), TESTING, SCREENSHOTS, CI, APP_STORE, PRIVACY. README rewritten (it still said "there is no code here yet"). CHANGELOG, CONTRIBUTING | `Docs/`, root | — |

**Bends:**
- **No `Snapfile`.** fastlane `snapshot` is iOS-only; AGENTS.md's own macOS table
  captures through XCUITest attachments instead. A Snapfile would configure nothing.
- **`screenshots.yml` renders and does not capture.** AGENTS.md has it run `fastlane
  screenshots`. On a 1× runner that would make undersized captures, which the export
  refuses by AGENTS.md's own rule, so the workflow could only fail.
- **`Docs/`, not `docs/`** for the new documents and `Docs/assets/` (phase 2, decision 8).
- **String keys are English, not symbols** (Q4).
- **The 05 slot is the all-unidentified network, not Settings.** Settings is a 560 × 640
  window and cannot fill a 2880 × 1800 slot without upscaling, which the renderer refuses.

**Caught by the captures:**
- **The fixture scanner streamed IPv6-only devices as `0.0.0.0`.** `HostFacts` is IPv4;
  the engine never streams one. They now reach the report only.
- **Clean marketing captures cannot come from this desktop.** The Dock and a notification
  were in every capture (Q5). Nothing rendered is committed.

## Closing checks

| Check | Result |
|---|---|
| Unit suite | 71 tests, green |
| Full UI suite, quiet desktop | 37 passed; `AppStoreScreenshotUITests` skipped itself, as designed |
| Real history untouched | SHA-256 still begins `d735909a`. No test opened it; the live tests used a scratch file |
| No real network data committed | The fixture is unchanged since phase 2's verified copy (`git diff f1ef1f8` is empty for `home-network.json`). This phase's diff holds no `10.10.20.x` address, and no MAC outside the documentation (`00:00:5E:00:53:xx`) and fixture-private (`x2:5C:…`) ranges, except `F2:3A:91:6B:0D:44`: an artboard sample in `Chip.swift`'s preview since phase 1, covered by phase 2's `--verify`. It had been pulled into the catalogue, and is now `Text(verbatim:)` and out of it. Nothing rendered from the desktop captures is committed. **`--verify` itself could not be rerun:** the raw capture lived in the session scratch area, which was cleared at JC's request before this phase began |
| Release build | `Scripts/release.sh "Developer ID Application: … (S8662L649U)" --no-notarize`: signatures, runtime, team, helper identity and daemon plist PASS. Installed to `/Applications/Zhen.app` with the helper, `AppIcon.icns` and `Localizable.stringsdict`. Launched once on a scratch history: window "Devices – 0 devices · 0 online · 0 unidentified" |
| Preferences | The real `com.jctec.zhen` domain, which UI tests had written to before the stage-4 fix, the fixture domain and the unit tests' domains are all cleared. No `zhen` preference file remains |

**Commits on `phase-3`:**
- `ab8b4d6` stage 1
- `e8a0510` stage 2
- `490b116` stage 3
- `ac4d864` stage 4
- `50f3f05`, `445e4cf`, `c0727cf` stage 5

Not pushed (Q3).

**Left for JC:**
- `PHASE-3-questions.md` Q1–Q7
- `PHASE-2-verification.md` steps 1–6. Step 0, the quiet-desktop UI run, is done here.
- clean marketing captures (Q5)

---

# Part 2 — the app-only follow-ups (2026-10-11, evening)

JC: "continue with app changes; computer is unlocked; no other agents are running." The
app-only items from the "what is missing" list. Skipped: designer round 3, which needs the
designer, and translations. Hiding the Dock for clean marketing captures was not done; it
is JC's system setting.

The real history file changed during this part: SHA-256 `7600d79b`, modified 21:03, with
`com.jctec.zhen.plist` recreated. That was JC scanning in the installed app, not this
run. It is the new baseline, and the preferences are JC's and left alone.

## Apple's accessibility audit

`SystemAccessibilityAuditUITests` runs `performAccessibilityAudit(for: .all)` on Devices,
Detail, Activity, the live scan and Settings, and on the empty, silent and partial
fixtures. The first run reported 39 issues.

**Fixed (ours):**
- **No role:** every element made with `.accessibilityElement(children: .combine/.ignore)`
  (name cells, identity cells, footer, found-host rows, event rows, stage cards, banner
  rows, source rows) had "Unknown role". These now carry `.isStaticText`, and the dot,
  meter and histogram `.isImage`.
- **No name:** the device table, the found-so-far list and the Activity list. Now
  "Devices", "Found so far" and "Events".
- **The footer's dot said "Merged" to VoiceOver while a scan ran.** It used an event
  tone's word. It now says Scanning, Partial results, Complete or Never scanned
  (`NetworkModel.footerStatusLabel`).
- **The partial-run strip's title failed contrast on the translucent `.bar`.** It now
  sits on opaque `surfaceRaised`.
- **White on the app's global accent measured 2.61:1 in dark mode** (1.88:1 in dark with
  Increase Contrast). AppKit fills selections, switches and prominent buttons with the
  global accent and draws white on top. The global accent was `AccentColor`, the accent
  *text* colour, which is light in dark mode. It is now `SystemAccent`: `#6A58C9`
  standard, 5.45:1; `#4E4194` with Increase Contrast, 8.37:1. The `accent` text token is
  unchanged. `PaletteContrastTests.whiteOnSystemAccent`; break: dark set to `#A495E8`
  gave 2.61.

**Excused, matched exactly, each with its reason in the test:**
- **Form pickers' "Action is missing":** AppKit's popup inside SwiftUI's `Form`;
  `.pickerStyle(.menu)` made no difference.
- **The emoji-and-symbols input item and the Touch Bar host:** the system's.
- **Title-bar buttons:** 14 pt groups.
- **Unnamed container groups:** window, split column, table cell, list section. Excused
  only when something inside them is named; an empty unnamed group still fails.

**Contrast is judged on measured pixels, WCAG 4.5:1.** The audit is stricter for small
text, and its sampling varied run to run. It flagged "Minimal" at 4.86–5.60:1 measured,
the `private` chip at 4.56:1 and the empty-state copy at 5.51:1, but none of them in
every run. The test measures the element's own pixels (background is the commonest
luminance, text the farthest from it) and fails under 4.5. Text scrolled out of the
window is skipped: one "failure" at 4.21:1 was 25 pt below the window's edge, measuring
whatever was behind it.

**The selected sidebar row is excused, with its measured ratio logged.** It measured
3.92:1. The attached screenshot showed it green: macOS fills a sidebar selection with the
person's own system accent (this Mac's is green), and uses the app's only under
Multicolour. That is the same reason phase 2 recorded for prominent buttons.

**Two test-harness lessons:**
- **Settings is audited only on its own window's elements.** The audit covers every
  window, and the main window's table, behind Settings, "failed contrast" against
  Settings' pixels. Minimising the main window did not help: a minimised window stays in
  the tree with its old frames.
- **Closing the main window quits the app.** With one `Window` scene, closing the last
  window ends a SwiftUI app. That follows from stage 3's `Window`, and is normal for a
  single-window Mac app. Recorded in ARCHITECTURE.

| Gate | Break | Failure |
|---|---|---|
| `SystemAccessibilityAuditUITests.testEveryScreen` | `.isStaticText` removed from the name cell | "Unknown role — 'deviceName-192.168.50.1' …" on every row |
| the same | the Activity list's name removed | "Element has no description — 'activityList'" |

**Static text carries its words in the value, not the label.** Three UI tests read name
cells through `.label` and got empty strings. `ZhenRobot.words` now joins the non-empty
label and value, and those tests read `.text`.

## Shortcuts

`App/ZhenIntents.swift` adds two App Intents, with Siri phrases in an
`AppShortcutsProvider`:
- **Scan Network** opens the app and calls `NetworkModel.startScan()`, as ⌘R does. If a
  scan is already running it answers so.
- **Count Online Devices** reads history, loading it first after a cold launch, and
  returns a number.

`ZhenApp.init` registers the one model with `AppDependencyManager`. The built app's
`Metadata.appintents` lists both actions and all three phrases. `IntentTests` drives
each intent's `run(on:)` with a fixture model; break: `startScan()` dropped, so the scan
never ran.

## Symbol keys (Q4, resolved)

Every user-facing string is now a symbol key in `Localizable.xcstrings`
(`extractionState: manual`), used as `Text(.key)`, `String(localized: .key)`, or as the
resource itself in this app's components, whose `LocalizedStringKey` parameters became
`LocalizedStringResource`.

A throwaway script did the conversion:
1. Re-keyed 253 entries to camelCase symbols, keeping English values and plural forms.
2. Rewrote 300 call sites by their context.

Then by hand:
- ternaries the script wrapped on one side only
- plural strings with substitutions, whose symbols label that argument (`devices:`)
- an event sentence that was two styled `Text`s interpolated, now an `AttributedString`
  with token colours. `Text +` is deprecated on macOS 26, and the pair is not a string
  to translate.
- preview-only text, now `Text(verbatim:)`, or a real symbol where one exists
- 20 numbered or unclear names, such as `online2` → `onlineLower` and `known` → `knownBy`.
  The rename caught a key path (`\.lastSeen`) on the way, which was put back.

**App Intents need literal resources.** The metadata processor refused generated
symbols ("must be initialized with a call to its initializer or a string literal"), so
the intents spell `LocalizedStringResource("scanNetwork", defaultValue: …)` with the
same keys.

**Check:** after a build and `xcstringstool sync`, the catalogue has 248 keys, none
automatic (a literal that escaped would come back as one), and none unused.
`PluralTests` now reads the symbols; break: `identityChanges`' `one` form removed gave
"1 identity changes". `Scripts/catalog-plurals.py`, which re-keyed by English text, is
removed.

## The design system as DocC

A3 asks for `ZhenDesign.docc`. The design system was built inside the app target, not as a
`ZhenDesign` module (phase 1), so the catalogue is `Zhen/Zhen.docc`, documenting the app
module. It contains:
- `Zhen.md`, the landing page
- `Foundations.md`: colour roles and floors, type, every metric token with its values,
  symbols, motion
- `Components.md`: each component, what it is for and not for, linked to its symbol page
- the four articles A3 names:
  - `BuildingAScreen` (Devices as the worked example)
  - `StatesAndEmptiness` (every state on every screen)
  - `Accessibility` (the contrast table and how the audits check it)
  - `Corrections` (every deliberate difference from the artboards, collected from both
    phase ledgers)
- the six artboards

`xcodebuild docbuild` is clean: no warning from the app or its catalogue (one doc comment
fixed), and every component link resolves. The catalogue adds nothing to the app bundle.
`bundle exec fastlane docs` copies the archive to `build/docs`.

## Closing checks, part 2

| Check | Result |
|---|---|
| Unit | 74 tests, green |
| UI, full suite | 39 passed; the screenshot test skipped itself |
| Docs | `docbuild` clean |

---

# Part 3 — Spanish, and notice of new devices

## Spanish

This Mac's languages are `en-MX`, then `es-MX`. Spanish is the first translation, in
neutral Latin-American Spanish, with macOS's own Spanish names for its places
("Configuración del Sistema", "Ítems de inicio", "Mostrar en Finder").

| Piece | Where |
|---|---|
| 248 strings, by symbol key; plurals as `one`/`other`; the three substitution strings keep their argument order | `Scripts/translations/es.json` |
| A merge that refuses a missing key, an unknown key, or a placeholder that differs from the English | `Scripts/apply-translations.py es` |
| The Local Network permission prompt | `Zhen/InfoPlist.xcstrings` |
| `es` as a project region | `knownRegions` |

**Gates:**
- `LocalizationTests.spanishIsComplete` reads the built app's `en` and `es` tables.
  Break: one key's `es` entry removed gave "untranslated: [renameDevice]".
- `LocalizationTests.spanishPlurals` checks plurals, substitutions and their arguments.
- `WindowSizeUITests.testSpanishFitsAtMinimum` runs the minimum window, Devices and
  detail, in Spanish.
- UI tests now pin `-AppleLanguages (en)`, so their English assertions do not depend on
  the Mac's language order.

**Bends:**
- **"Nueva dirección" for `ipChanged`,** not "Dirección cambiada". At caption bold in
  capitals, the latter would overrun the 140 pt event-kind column, which "ADDRESS CHANGED"
  already fills to about 129 pt.
- **Core's sentences stay English** in a Spanish window ("was Apple TV", the degradation
  explanations). The app renders core's findings verbatim by design. Recorded in Known
  rough edges.
- **Siri phrases are English only.** An `AppShortcuts.xcstrings` would carry Spanish
  phrases. Left for when someone can test them with Siri.

**Seen in the Spanish captures:** at the minimum window the longer subtitles truncate,
with the full text in the tooltip, as long English ones do.
