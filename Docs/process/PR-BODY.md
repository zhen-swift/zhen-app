# Adopt zhen-core 0.7.0, and delete the workarounds it replaces

**Base:** `phase-3` · **Depends on:** zhen-swift/zhen-core 0.7.0 (the core PR — merge that first)

zhen-core 0.7.0 does what this app had been working around. This PR raises the pin to it on
purpose and deletes every workaround it makes unnecessary.

## The pin

`upToNextMinorVersion` from `0.7.0`, with `Package.resolved` pinning 0.7.0 at `9a2310a`. The
old `upToNextMajorVersion` from 0.5.0 admits any 0.x, so it would have adopted 0.7.0
silently. 0.7.0 adds cases to `DerivedEvent.Kind`, which breaks an exhaustive `switch`.

> **Merge order matters for the hash.** `9a2310a` is the commit tagged `0.7.0` in the core
> PR. If core is squash-merged and re-tagged, re-resolve here before merging
> (`xcodebuild -resolvePackageDependencies -project Zhen.xcodeproj -scheme Zhen`) and amend
> `Package.resolved`.

## What was deleted, and what replaced it

| Deleted | Replaced by (core 0.7.0) |
|---|---|
| `ProbeOnlyStore`, `ScanRequest.records`, and `LiveScanRunner`'s `[Bool: any ScanEngine]` | `ScanRunning.probePorts`, through `ScanRunner.probePorts` and `HistoryStore.recordPorts`. A single-device port scan is kept in history, survives a relaunch, and records no run |
| The always-empty Ports segment (`case .ports: false`) | `portOpened` / `portClosed`, shown in A2's warning amber. Closes PHASE-2-questions Q3 |
| `release.sh` building the helper with SwiftPM | an Embed Helper phase over the `zhen-helper` product. An Xcode-built app now has a program for launchd to start (phase 2, defect E1). The scheme list is still just `Zhen` |
| The relabelled "Check ports on every scan" | A3's "Deep-scan new devices", meaning `PortStage.newHosts` |
| The stale-registration wait: the engine cache keyed by helper state and network, and `NetworkFingerprint` | an engine built per scan. Core bounds the helper check at 750 ms, and the app asks the helper only when it has installed it |
| `DegradationCopy.forTheApp`, and the fixture pinning it | `ProbePermissionAdvice.appleLocalNetworkInApp`; the copy is core's sentence verbatim |
| The WCAG formula in `PaletteContrastTests` | `ZhenCore.Contrast`. The suite keeps the catalogue |
| Identity history listed as changes (`isIdentityChange`) | one row per MAC, with how it joined and when, from `StoredDevice.macHistory` (A3) |

## Also in this PR

- **fastlane could not load the Fastfile** at all since phase 3 part 2: `docs` is a reserved
  lane name. The lane is `docc` now, so `unit`, `ui` and `test` run again (`47f2502`).
- An offline device's port scan reports that what answers at its old address may be another
  device, and shows no ports. The review's MAC check needed a discovery that a probe no
  longer runs. Core refuses to record the result for the same reason.
- `ZhenDarwin` is an explicit product dependency, for `CapturePolicy`.
- `Docs/ARCHITECTURE.md` › Known rough edges: six entries out, five in, each with its reason.

## Tests

- `bundle exec fastlane unit`: **171 → 173**, 0 failures. Every new or rewritten gate was
  shown failing on a deliberate break first. The table is in
  `Docs/process/CORE-0.7.0-progress.md`.
- New gates: **port results survive a relaunch**, against a real history file;
  **the Ports segment shows an event**; a port probe runs off the main actor; the engine
  asks the helper only when it is installed; one identity row per MAC; the helper is
  embedded in an Xcode build.
- `Scripts/release.sh - --no-notarize` passes end to end.
- **The UI suite has not run against this branch.** The screen locked during the run, and
  XCUITest cannot activate an app on a locked session. This is
  `CORE-0.7.0-verification.md`, step 1.

## Screenshots

Marketing captures are not regenerated in this PR. The identity card and the Ports segment
look different now (verification, step 9).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
