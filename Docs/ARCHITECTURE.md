# Architecture

Zhen.app is a SwiftUI front end over [zhen-core](https://github.com/zhen-swift/zhen-core),
linked as a Swift package by version (`upToNextMinorVersion` from 0.7.0; `Package.resolved`
pins 0.7.0). It never runs the
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
| `Scanning/` | `ScanRunning` and its two conformances: `LiveScanRunner` over core's `ScanRunner`, and `FixtureScanRunner`, which replays the committed fixture. Also `ScanPipeline` |
| `Features/` | One folder per screen: `RootView` (window, sidebar, footer), `DevicesView` (the `Table`), `DeviceDetailView`, `LiveScanView`, `ActivityView`, `SettingsView` |
| `Components/` | The design system's pieces: `Card`, `StatusDot`, `Chip`, `StageCard`, `DegradationBanner`, `EventRow`, `TimelineHistogram`, … |
| `Platform/` | AppKit and system edges: pasteboard, Finder, System Settings URLs, `LiveHelperService` (`SMAppService`), `HistoryWatcher` |
| `Utilities/` | Tokens: spacing, radii, borders, icon sizes, dimensions, window sizes |
| `Fixtures/` | The anonymised home network (`home-network.json`, made by `Scripts/anonymise-scan.py`), its variants, and `PreviewContainer` |

## Scenes

- **One `Window`**, not a `WindowGroup`. Each scan runs from that window's
  `.task(id: scan.runToken)`, so a second window would run every scan twice.
  `CommandsUITests.testThereIsOneWindow` pins it. Closing the window quits Zhen, as a
  single-window app should, unless the person keeps it in the menu bar (below).
- **`MenuBarExtra`**, inserted only with "Keep watching from the menu bar" on. It shows
  status, Scan Now or Stop, Open Zhen, Settings and Quit. `AppDelegate` then keeps the app
  alive after its window closes.
- **Who runs the scans: `ScanHost`.** Scans run from a view's `.task(id:)`, so cancelling
  one is that view going away. The scan, port-scan, history-watch and automatic-scan tasks
  are one modifier, active on exactly one view: the window when the menu bar mode is off,
  the menu bar item when it is on. Two active hosts would run every scan twice. The switch
  is disabled mid-scan, so a scan never changes host while it runs.
  `MenuBarUITests` pins both halves.
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
  network, budget, and the port stage — `.newHosts` when "Deep-scan new devices" is on,
  core's `PortStage`, where "new" is history's answer. The window's task runs it through the pipeline.
  `ScanSession` folds the batches, and the model rereads history at the end.
  Degradations are kept per run, so a partial run still says so after a relaunch.
- **A port scan of one device.** `NetworkModel.scanPorts(_:)` asks for a port probe, not a
  scan: `ScanRunning.probePorts`, through core's `ScanRunner.probePorts` and
  `HistoryStore.recordPorts`. Core folds the ports into the device history holds and
  records no run, so every other device stays as it was and the result survives a
  relaunch. An offline device's old address is not trusted: what answers there is not
  shown as its ports, and core does not record it. `NetworkModel.portScans` holds only
  whether a probe is running and why one found nothing.
- **The engine.** `LiveScanRunner` builds core's `ScanRunner` for each scan, asking the
  helper for a capture device only when this app has installed it (`HelperState.installed`).
  Core bounds that check at 750 ms, so nothing is cached between scans.

## The privileged helper

`Helper/com.jctec.zhen.helper.plist` is copied to `Contents/Library/LaunchDaemons/`, with
`AssociatedBundleIdentifiers = [com.jctec.zhen]` so Login Items shows "Zhen" with the icon.
`HelperPlistTests` reads the built app's copy. Settings registers and unregisters the
helper through `SMAppService.daemon`. Without the helper every screen works; it adds the
layer-2 ARP sweep and SYN scanning. The binary is zhen-core's `zhen-helper` product: the
Zhen target depends on it and the Embed Helper phase copies it to
`Contents/MacOS/zhen-helper`, where the plist's `BundleProgram` points. `Scripts/release.sh`
signs it as `com.jctec.zhen.helper` before re-sealing the app.

## Design-system documentation

`Zhen/Zhen.docc` is the design system as DocC:
- Foundations: tokens, contrast and type
- Components
- Building a screen
- States and emptiness
- Accessibility
- Corrections: every deliberate difference from the artboards

The six artboards are in its resources. Build it with Product ▸ Build Documentation, or
`bundle exec fastlane docc`.

## Strings

Every user-facing string is a symbol key in `Zhen/Localizable.xcstrings`
(`extractionState: manual`), used as `Text(.scanNow)` or `String(localized: .scanNow)`. A
counted string has plural forms in the catalogue, for example `.identityChanges(count)`.
Controls without a resource initialiser take `String(localized:)`. Three places spell the
key out as `LocalizedStringResource("key", defaultValue:)`: the App Intents' titles and
descriptions, because the metadata processor reads them at build time. A string literal
in a view is extracted by the compiler as a new, automatic key; a catalogue with any
automatic key has a literal that should have been a symbol.

**Languages:** English (source) and Spanish. A translation lives in
`Scripts/translations/<lang>.json`, by symbol key, and `Scripts/apply-translations.py
<lang>` merges it into the catalogue. The script refuses a missing or unknown key and any
placeholder that differs from the English. `Zhen/InfoPlist.xcstrings` translates the Local
Network prompt. `LocalizationTests` checks the built app has every key in every language.
UI tests pin `-AppleLanguages (en)`, and `WindowSizeUITests.testSpanishFitsAtMinimum` runs
the minimum window in Spanish.

## New-device notices

With "Notify me when a new device joins" on (off by default; macOS's permission is asked
when it is switched on), each scan the app runs ends by comparing the devices it knew
before with the devices history holds now. A device is new when both are true:
- the app did not know it before the scan (by identity)
- history first saw it during the scan

Either alone is wrong: a merge re-keys an old device, and a device returning after a week
is not new. A history's first scan announces nothing. More than three new devices make one
summary. `NewDeviceNotice` holds the rule; `Notifier` is the seam (`LiveNotifier` posts
through `UNUserNotificationCenter`, `FakeNotifier` records).

Notices come only from scans the app runs, by hand or with "Scan automatically". With
"Keep watching from the menu bar" on, those continue after the window closes.

## Shortcuts

`App/ZhenIntents.swift`: **Scan Network** (opens the app and scans, as ⌘R does) and
**Count Online Devices** (reads history; returns a number), with Siri phrases. Both act
on the app's one `NetworkModel`, registered with `AppDependencyManager`.

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

## Known rough edges

Each of these is something core or the platform does not do yet, or a gate only a person
can run. zhen-core 0.7.0 removed six earlier entries — unsaved port scans, "check ports on
every scan", the empty Ports segment, identity history by change rather than by MAC, the
helper missing from Xcode builds, and the 3 s stale-registration wait. The
`CORE-0.7.0-progress.md` ledger has the detail.

- **A port probe's time is not in history.** History keeps ports, not when a probe checked
  them, so after a relaunch the ports card says "From an earlier scan that checked ports"
  rather than the probe's time. Within the session it says when.
- **An Xcode-built helper is signed ad hoc.** Xcode signs the embedded helper on copy
  under a derived identifier, which the helper's code requirement would refuse. Only
  `Scripts/release.sh`'s signature (`com.jctec.zhen.helper`, Developer ID) satisfies it,
  so registration is still a release-build check.
- **Identity history before 0.7.0 is one row.** A record written by an older core kept one
  MAC; its row starts at the record's first-seen. A rotation before 0.7.0 was not written
  down and cannot be shown.
- **A merge recorded before 0.7.0 may show twice in Activity.** Core logged each merge
  twice until 0.7.0; the duplicate event is still in an older history file.
- **An older `zhen` erases what 0.7.0 adds.** A 0.6.0 command line rewriting the shared
  history file drops port events and MAC history (zhen-core's questions, Q1).
- **Marketing captures need a clean desktop.** An XCUITest window screenshot is screen
  pixels. The Dock and notifications land in it, and a 1440 × 900 window does not fit
  above the Dock on a 1512 × 949 display (`Docs/SCREENSHOTS.md`).
- **Event details and degradation explanations are core's English.** The app shows core's
  sentences verbatim ("was Apple TV", "No packet-capture device could be opened…"), so a
  Spanish window shows them in English. Translating them needs core to send the facts as
  fields, not finished sentences.
- **Not yet verified by a person:** Developer ID signing and notarisation, helper
  registration in Login Items, a mis-signed caller being refused, a real-LAN scan, and the
  main-thread trace. `Docs/process/PHASE-2-verification.md` steps 1–6.
