**Liveness:** 2026-10-11 — stages 1–4 done; stage 5 next.

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
