# zhen-app on zhen-core 0.7.0 — progress ledger

**Brief** `zhen-agents/briefs/core-0.7.0-and-the-app-catches-up.md` (second half)
**Branch** `core-0.7.0`, off `phase-3` · **Core ledger** `zhen-core/Docs/process/0.7.0-progress.md`
**Questions** `CORE-0.7.0-questions.md` · **For JC to run** `CORE-0.7.0-verification.md`

## How to resume

The table under **State** names each commit. Every gate below says which deliberate break
turned it red; reproduce one by applying that break and running the one test with
`-only-testing:`. To build against zhen-core 0.7.0 before it is on GitHub, see **Building
against an unpushed core**.

## State

| Commit | What |
|---|---|
| `47f2502` | fastlane lanes renamed so the Fastfile loads (pre-existing defect, found at baseline) |
| `27d8e3c` | adopt zhen-core 0.7.0; every workaround in the brief's table deleted |
| `aec075a` | the helper embedded from zhen-core's `zhen-helper` product; `release.sh` no longer builds it |
| (this commit) | docs: ARCHITECTURE Known rough edges, CHANGELOG, DocC, PRIVACY, README; process files |

## Baseline, and the defect found there

`bundle exec fastlane unit` on `phase-3` **exited 1 before running anything**: fastlane 2.241
(the locked version) rejects a lane named `docs` ("Lane name 'docs' is invalid"), and that
lane arrived with `5074c4d`, phase 3 part 2. So since that commit no lane — `unit`, `ui`,
`test` — could run, locally or in CI. The lane is `docc`; the private `run_tests`, which
fastlane reports as taken by a built-in action, is `run_suite`. README and ARCHITECTURE name
the new lane. After the rename, against zhen-core 0.6.0: **171 unit tests, 0 failures**.

## Decisions

**A1 — the pin.** `upToNextMinorVersion` from `0.7.0`. For a 0.x package `upToNextMajor`
from 0.5.0 admits every 0.x — the silent adoption the brief warns about. Minor-bounded
admits 0.7.x patches and nothing that may break. `Package.resolved`: 0.7.0 at `9a2310a`.

**A2 — a port scan is a probe.** `ScanRunning.probePorts(PortProbeRequest)` beside
`run(ScanRequest)`; `PortProbeOutcome`; `ScanPipeline.probePorts` is `@concurrent` like
`run`. `LiveScanRunner` calls core's `ScanRunner.probePorts`; the fixture runner folds its
replayed ports through `HistoryStore.recordPorts`. `ScanRequest.records` is gone: every run
records, and a probe is not a run. `ProbeOnlyStore` deleted.

**A3 — an offline device's probe shows nothing.** The review fix (part 7) compared the MAC
the /32 run's ARP found. A probe has no discovery and no MAC, so the guard is now presence:
an offline device's old address may be anyone's, and `PortScan.result` reports a new
sentence (`offlineSoPortsNotItsOwn`) instead of ports. Core makes the same refusal and does
not record them. `PortScanTarget.mac` became `isOnline`.

**A4 — the stale-registration wait: the engine cache is deleted.** The wait was the reason
`LiveScanRunner` kept an engine keyed by helper state and network (its own comment: "3.2 s
with a registration that does not answer"). With core's 750 ms bound — and the app asking
the helper only when `HelperState == .installed`, so a registration it did not install is
never contacted at all — an engine is built per scan. Deleted with it: the `[Bool: any
ScanEngine]` map, the build de-duplication, `note(_:network:)`'s network half, and
`NetworkFingerprint` (which existed only as that cache's key). `ZHEN_CAPTURE=direct` still
works: an installed helper is asked through `.fromEnvironment`.

**A5 — `import ZhenDarwin`.** `ScanRunner(store:capture:)` takes a `CapturePolicy`, defined in
ZhenDarwin, and the target's `MemberImportVisibility` refuses `.directOnly` without the import.
The ZhenDarwin product is now an explicit dependency of the Zhen target, like ZhenPrivilege,
rather than relying on the module being built transitively.

**A6 — "Deep-scan new devices" again.** A3's label is back; on means `PortStage.newHosts`.
The stored key never changed (`deepScanNewDevices`), so nobody's setting moves.
`ScanSession` skips the port stage card when the stage is `.off`.

**A7 — port events.** In the Ports segment, labelled "Port opened"/"Port closed", tone
`.warning` and text `statusWarningText` — A2's "port events warning amber". Not identity, not
presence.

**A8 — the fixture's port events.** The router's 80/tcp is closed in run 0 and open from run 1
(→ `portOpened`); a new 8080/tcp is open until the latest run, which finds it closed
(→ `portClosed`). Runs 1 and 10 carry no other change, keeping the script's one-change-per-run
rule. `merged` is still not staged, as PHASE-2 Q5 found.

**A9 — identity history.** One row per MAC from `StoredDevice.macHistory`: the current
address first (accent dot, "since …"), then earlier ones newest first (secondary dot, the
span as a localised date range). The reason: "first address", "rotated · recognised by its
⟨Bonjour name…⟩", "joined · shared a ⟨…⟩". Caption: the identity key sentence and "N
hardware addresses". `DerivedEvent.Kind.isIdentityChange` existed only to list changes in
place of these rows, and is deleted. The plural gates in `HousekeepingTests` and
`LocalizationTests` moved from the deleted `identityChanges` to `hardwareAddressesSeen`.

**A10 — Local Network wording.** `DegradationCopy.forTheApp` deleted; the consequence is
core's sentence verbatim. The fixture builds its degradations with `.appleLocalNetworkInApp`,
which is what core's engine chooses inside an app bundle.

**A11 — contrast.** `PaletteContrastTests` measures with `ZhenCore.Contrast.ratio` and its
floors with `Contrast.Level`; the suite keeps the catalogue (pairs, surfaces, the four
looks, the artboard values). No WCAG arithmetic is left in the app.

**A12 — the helper in an Xcode build.** The Zhen target depends on the `zhen-helper` product
(`PBXTargetDependency` with a `productRef`) and an Embed Helper Copy Files phase copies it to
Executables (`Contents/MacOS`) with Code Sign On Copy. Attempt 1 — the copy phase alone —
failed ("The file 'zhen-helper' couldn't be opened"): nothing built it. Attempt 2 added the
dependency and builds. `xcodebuild -list` still shows only `Zhen`. `release.sh` checks the
helper is there and signs it as `com.jctec.zhen.helper`; step 3's SwiftPM build is gone.

**A13 — the model's engine seam.** `NetworkModel.init(environment:defaults:engine:)`: a live
launch can be given a stand-in engine, and the live branch honours a test's defaults domain.
Needed for the relaunch gate, which must run over a real history file.

**A14 — strings.** Nine keys added (English in the catalogue, Spanish in
`Scripts/translations/es.json`, merged by `apply-translations.py`), six deleted:
`checkPortsEveryScan`, `alsoCheckCommonPortsEveryDevice`, `scannedThisSessionNotSavedHistory`,
`anotherDeviceAnswersAt`, `identityChanges`, `noIdentityChangesSeen`. The ports card's finished
caption is "Checked …" (the existing key), not "this session, not saved".

## Gates

| Gate | Result |
|---|---|
| `bundle exec fastlane unit` | **green: 173 tests, 0 failures** on the final tree (171 at baseline; 172 after `27d8e3c`) |
| Full `test` lane | **not passed — environment.** The Mac's screen was locked (`CGSSessionScreenIsLocked = 1`, idle 58 min, after midnight). Every UI test failed identically, "Failed to activate application … (current state: Running Background)", ~60 s each; the run was stopped after 9 so it would not spend 40 minutes timing out. Unlocking is a password. The UI target builds (`build-for-testing` succeeded). Handed to JC: verification step 1 |
| Behavioural harness (rooms, detail, takeover, scene; keyboard, sizes, four looks, restoration) | **not run** — it is the UI suite above |
| Port results survive a relaunch — a test | `ScanningBehaviourTests.portResultsSurviveARelaunch` |
| The Ports segment shows an event — a test | `ActivityTests.portsSegment` |
| No `@unchecked Sendable`, no reachable `fatalError`, no scanning on the main actor | `grep` over `Zhen/`: no `@unchecked Sendable`, no `fatalError`. Scanning: `ScanPipelineTests.scannerRunsOffMain` (existing) and `probeRunsOffMain` (new); the instrument trace is JC's |
| `Scripts/release.sh - --no-notarize` | **pass** end to end against 0.7.0 |

### Shown failing first

Each new or rewritten gate, with the break that turned it red (then restored):

| Test | Break | Red |
|---|---|---|
| `portResultsSurviveARelaunch` | probe engine over `InMemoryHistoryStore()` | ports empty after relaunch |
| `portScanKeepsTheNetwork` | fixture probe records a /32 run | `onlineCount 1 ≠ 11` |
| `engineFollowsTheHelper` | `asksHelper = true` | `[true×5] ≠ [false,false,false,true,true]` |
| `networkChange` | keep the engine between scans | `built 1 ≠ 2` (first attempt at this break did not compile; redone) |
| `portsOfAnotherDevice` | `guard isOnline \|\| true` | issue recorded |
| `probeRunsOffMain` | drop `@concurrent` from `ScanPipeline.probePorts` | probed on the main thread (2 issues) |
| `portsSegment` | `case .ports: false` | segment empty |
| `identityRowsPerMAC` | rows from the current MAC only | 1 row, not 2 |
| `scanUsesPreferences` | toggle → `.everyHost` | `.everyHost ≠ .newHosts` |
| `historyDerivesEvents` | no router staging | `portOpened`, `portClosed` missing |
| `silentVariant` | fixture uses `.appleLocalNetwork` | consequence contains "terminal application" |
| `helperIsEmbedded` | project without the Embed Helper phase | no executable at `Contents/MacOS/zhen-helper` |

## Building against an unpushed core

The app resolves `https://github.com/zhen-swift/zhen-core.git` by version, and 0.7.0 is only
local until JC pushes. Every build in this run redirected that URL for the build process
only, through git's environment configuration — no global or repository git config was
written:

```sh
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="url.file:///Users/jc/Dev/InfinityCastle/zhen-core.insteadOf"
export GIT_CONFIG_VALUE_0="https://github.com/zhen-swift/zhen-core.git"
export GIT_CONFIG_KEY_1="url.file:///Users/jc/Dev/InfinityCastle/zhen-core.insteadOf"
export GIT_CONFIG_VALUE_1="https://github.com/zhen-swift/zhen-core"
xcodebuild … -scmProvider system      # fastlane and release.sh worked with the variables alone
```

`Package.resolved` names GitHub and revision `9a2310a`. Once that commit and the `0.7.0` tag
are on GitHub, nothing here is needed.

## Leftovers kept as they were

- `Docs/plans/APP-PLAN.md` is still untracked, as found.
- Two string keys, `noPortEventsInWindow` and `noKindEventsInThisWindow`, are used by no code.
  They predate this run and are not the Ports copy (that was `case .ports: false`). Left.
