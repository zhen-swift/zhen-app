# Architecture

Zhen.app is a SwiftUI front end over [zhen-core](https://github.com/zhen-swift/zhen-core),
linked as a Swift package by version (`Package.resolved` pins 0.6.0). It never runs the
`zhen` command line and never parses its output. The house rules are `../AGENTS.md`;
where this document and they disagree, they win.

## One history, two doors

```
   zhen (CLI)          Zhen.app
       │                  │
       └──────┬───────────┘
              ▼
  ~/Library/Application Support/zhen/history.ndjson     (ZHEN_HISTORY overrides)
```

Both open the same append-only file through core's `LogHistoryStore`. It re-reads the file
on every call and locks it with `flock`, so the app and a terminal can both scan. The app
polls the file once a second (`Platform/HistoryWatcher.swift`) and rereads history when it
changes, so a scan run in a terminal appears in the open window.

## Isolation

| Side | Isolation |
|---|---|
| app target | `MainActor` by default (`SWIFT_DEFAULT_ACTOR_ISOLATION`), approachable concurrency on |
| `Scanning/` | `nonisolated`: `ScanPipeline.run` is `@concurrent`; `LiveScanRunner` is an actor |
| zhen-core | non-isolated value types and actors |

`ScanPipeline` is the seam. It runs a `ScanRunning` off the main actor, buffers its
`ProbeEvent`s and hands them to the view model in display-rate batches. The engine
emits far faster than 60 Hz. `ScanPipelineTests` constructs the pipeline from a
`nonisolated` context, so marking it `@MainActor` stops the tests compiling.

## The pieces

| Folder | What lives there |
|---|---|
| `App/` | `AppEnvironment` (the one reader of launch arguments and the environment), `ZhenCommands` (the menu bar), the launch appearance |
| `Model/` | `NetworkModel` (one per app: devices, events, latest run, the scan and port scans), `ScanSession` (a scan as it happens), `DeviceItem` (a `Device` flattened for the table), `Preferences`, presentation extensions |
| `Scanning/` | `ScanRunning` and its two conformances: `LiveScanRunner` over core's `ScanRunner`, and `FixtureScanRunner`, which replays the committed fixture. Also `ScanPipeline` and `ProbeOnlyStore` |
| `Features/` | One folder per screen: `RootView` (window, sidebar, footer), `DevicesView` (the `Table`), `DeviceDetailView`, `LiveScanView`, `ActivityView`, `SettingsView` |
| `Components/` | The design system's pieces: `Card`, `StatusDot`, `Chip`, `StageCard`, `DegradationBanner`, `EventRow`, `TimelineHistogram`, … |
| `Platform/` | AppKit and system edges: pasteboard, Finder, System Settings URLs, `LiveHelperService` (`SMAppService`), `HistoryWatcher` |
| `Utilities/` | Tokens: spacing, radii, borders, icon sizes, dimensions, window sizes |
| `Fixtures/` | The anonymised home network (`home-network.json`, made by `Scripts/anonymise-scan.py`), its variants, and `PreviewContainer` |

## Scenes

- **One `Window`**, not a `WindowGroup`. Each scan runs from that window's
  `.task(id: scan.runToken)`, so a second window would run every scan twice.
  `CommandsUITests.testThereIsOneWindow` pins it.
- **`Settings { }`**, ⌘,. Its content gets `.defaultAppStorage(model.defaults)` at the
  scene, never inside the view: a view's own `@AppStorage` reads what its parent
  provides.
- **Rooms**: Devices and Activity, in a `NavigationSplitView`. A device detail is pushed
  on the detail column's `NavigationStack`. The live scan replaces the Devices content
  and hands back when it finishes.
- **Commands** reach the window through `@FocusedValue(\.windowActions)`. Scanning acts
  on the model directly, so ⌘R works before the window has published.

## Scanning

- **A scan.** `NetworkModel.startScan()` builds a `ScanRequest` from `Preferences`:
  network, budget, ports or not. The window's task runs it through the pipeline.
  `ScanSession` folds the batches, and the model rereads history at the end.
  Degradations are kept per run, so a partial run still says so after a relaunch.
- **A port scan of one device.** `NetworkModel.scanPorts(_:)` scans that device's /32 with
  `records: false`. `LiveScanRunner` runs it over `ProbeOnlyStore`, which reads history and
  never writes it. History judges presence by the latest run alone, so a recorded /32 would
  mark every other device gone. The result lives in `NetworkModel.portScans` for the session.
- **The engine.** `LiveScanRunner` keeps core's `ScanRunner` until the helper's state
  changes, or a scan finds nothing. Core decides at construction whether the helper's
  capture device is there.

## The privileged helper

`Helper/com.jctec.zhen.helper.plist` is copied to `Contents/Library/LaunchDaemons/`, with
`AssociatedBundleIdentifiers = [com.jctec.zhen]` so Login Items shows "Zhen" with the icon.
`HelperPlistTests` reads the built app's copy. Settings registers and unregisters the
helper through `SMAppService.daemon`. Without the helper every screen works; it adds the
layer-2 ARP sweep and SYN scanning. The binary itself is built and embedded by
`Scripts/release.sh` (see Known rough edges).

## Tests and fixtures

Under `-UITesting` and `-ShowcaseData`, and in the unit-test host, the app runs on the
fixture. That means an in-memory store, a replaying scanner, a fake helper and a throwaway
defaults domain, so no test can see or change real history or preferences.
`Docs/TESTING.md` has the layers and commands.

## Deviations from the house rules

- **`Docs/`, not `docs/`.** APFS is case-insensitive and `Docs/` already held 30+ files.
  Phase 2 ledger, decision 8.
- **Bundle identifiers `com.jctec.zhen` and `com.jctec.zhen.helper`**, not
  `dev.jc.<app>`. They are baked into the helper's code-signing requirement and the
  installed launchd plist.
- **No SwiftData.** History is core's NDJSON file, shared with the command line. A
  database beside it would make the app's history a second opinion.
- **String keys are the English text**, not symbol keys. `Localizable.xcstrings` is filled
  from the compiler's extraction (`Scripts/catalog-plurals.py`). Moving 243 strings to
  symbol keys is a mechanical change of its own (phase 3, Q4).

## Known rough edges

Each of these is a workaround for zhen-core 0.6.0, which this app did not change, or a
gate only a person can run. Phase-3 ledger and questions have the detail.

- **Single-device port scans are not saved.** They are kept for the session only, and the
  card says so. A full scan with "Check ports on every scan" saves ports to history. The
  durable fix is a port-scan call in core that is not a run, or presence judged within the
  scanned subnet.
- **"Check ports on every scan" means every device.** Core's port stage is one switch per
  run; "new devices only" needs core.
- **The Activity Ports segment is always empty.** Core derives no port events
  (`DerivedEvent.Kind` has none).
- **Identity history is not one row per MAC.** Core keeps only the current MAC, and its
  merge event does not name the absorbed addresses. The card lists the merges, renames and
  moves core did record.
- **The helper binary is not in an Xcode build.** zhen-core declares no product for
  `zhen-helper`. `Scripts/release.sh` builds it from the pinned checkout and embeds it
  (phase 2, defect E1). An Xcode-built app can register the daemon, but launchd finds no
  program.
- **A stale helper registration costs 3 s.** When a registration exists but does not
  answer, core's helper check waits out its 3 s timeout. Every engine build pays it, which
  is why the engine is kept between scans.
- **Marketing captures need a clean desktop.** An XCUITest window screenshot is screen
  pixels. The Dock and notifications land in it, and a 1440 × 900 window does not fit
  above the Dock on a 1512 × 949 display (`Docs/SCREENSHOTS.md`).
- **Not yet verified by a person:** Developer ID signing and notarisation, helper
  registration in Login Items, a mis-signed caller being refused, a real-LAN scan, and the
  main-thread trace. `Docs/process/PHASE-2-verification.md` steps 1–6.
