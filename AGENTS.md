# AGENTS.md — Swift & SwiftUI house rules (iOS + macOS)

Sources, in order of authority:

1. **This file.**
2. JC's app standard — [JCTec/Tapper](https://github.com/JCTec/Tapper) (`APP_DEVELOPMENT_STYLE.md`, `docs/`), ported here and updated to Swift 6 / OS 26.
3. [twostraws/SwiftAgents](https://github.com/twostraws/SwiftAgents) — API-level rules, extended here to macOS.

Feature briefs in `Docs/` say **what** to build; this file says **how**. These are default rules. If one genuinely doesn't fit, say so in one line and propose the alternative — never drop it silently.

## Principles

| | |
|---|---|
| **Focus over features** | One purpose, done well. No accounts, analytics or social layers unless asked. |
| **Native and modern** | Newest first-party frameworks, system look. Personality from colour and motion, never re-skinned controls. |
| **Legibility is non-negotiable** | Text is readable on any background, including user-chosen ones. Contrast is computed at runtime. |
| **Tactile** | Springs and feedback tied to real events. No decorative motion. |
| **Tokens, not numbers** | Spacing, radii, borders, icon sizes, colours defined once. |
| **Structure where complexity earns it** | No view model for a one-line action. |
| **Calm by default** | Progressive disclosure: advanced controls appear only when needed. |

## Shape

```
              <Name>Core            Swift package · no UI imports
             /          \           Sendable models · rules · protocols · actors
     <Name>App          <Name>CLI   (optional)
  SwiftUI · iOS + macOS    portable · must build on Linux
```

- Core imports Foundation only. Never SwiftUI, SwiftData, Combine, AppKit, UIKit or `os`.
- Platform seams are protocols in Core, conformances in the consumer.
- `#if os(...)` lives only in `Platform/` files and modifier extensions — never inside a feature view.
- A single-screen app with no CLI may skip Core and keep rules on the `@Model`; the moment a second consumer appears, extract Core.

## Baseline

- iOS 26 / macOS 26 minimum. Universal iPhone + iPad from one codebase; macOS from the same codebase.
- Swift 6.2, Swift 6 language mode, complete strict concurrency. Warnings are errors in CI.
- App target: default actor isolation `MainActor`. Packages: nonisolated by default, isolate explicitly.
- async/await always. No completion handlers, no new Combine, no GCD.
- SwiftUI only. UIKit and AppKit are interop, never architecture: only where SwiftUI has no API, wrapped in one `…Representable` file under `Platform/`. Build tooling scripts (see Marketing assets) are exempt.
- Dependencies: none without asking. Each one justified in `docs/ARCHITECTURE.md` and pinned to a version or exact revision — never a branch.
- New Xcode projects use folder-synchronised groups, so new files join the target without editing the `.pbxproj`.
- Two-space indentation.

## Concurrency

- Shared state: `@Observable @MainActor final class`. Owned with `@State`, passed with `@Environment` / `@Bindable`. No `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`.
- Services: `actor` when they own mutable state, `Sendable` struct otherwise.
- Streaming results: `AsyncStream` / `AsyncThrowingStream`, cleanup in `onTermination`.
- Views start work with `.task` / `.task(id:)`. Never `onAppear { Task { … } }`.
- Unstructured `Task {}` only from user actions; keep the handle if it must be cancellable.
- `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)`: only with a comment stating the invariant that makes it safe.
- Time is injected as `any Clock<Duration>`. `Task.sleep(for:)`, never `(nanoseconds:)`.

## Architecture

### Feature = namespace

```
Features/
└── ItemsListView/
    ├── ItemsListView.swift                  root only: state, body, main actions, #Preview
    ├── ItemsListView+ViewModel.swift        extension ItemsListView { @Observable final class ViewModel }
    ├── ItemsListView+Helpers.swift          computed values, secondary functions
    ├── ItemsListView+SortMode.swift         any other nested type
    ├── ItemsListView+ControlsView.swift     struct ControlsView: View — one inner view per file
    ├── ItemsListView+PreviewContainer.swift in-memory container for previews
    └── ItemCardView/                        inner view that grew subviews → subfolder
        ├── ItemCardView.swift               (ItemsListView.ItemCardView)
        └── ItemCardView+TitleView.swift     prefix drops the parent's name
```

- Inner types are short names inside the feature: `ViewModel` inside, `ItemsListView.ViewModel` outside (tests).
- Inner views are `struct TopView: View`, never `var topView: some View`. They receive only what they need: values, `@Binding`, `@Bindable var viewModel`, or action closures (`onReset: () -> Void`).
- Cross-feature UI lives in `Components/` (e.g. `PressButtonStyle`). Never copied between features.

### Where logic lives

| Logic | Home |
|---|---|
| Business rules (guards, transitions, invariants) | The model / Core. Never in a view. |
| Draft state, validation, save/delete orchestration | `Feature.ViewModel` (MVVM) |
| One-line actions on a model | The view, directly |

MVVM is applied where it earns its keep, not uniformly.

### Navigation — typed routes

- One `Hashable` route enum per navigation root; `navigationDestination(for:)` switches over it exhaustively. No router object, no strings. Adding a screen = adding a case; the compiler finds the rest.
- iOS: `NavigationStack(path:)` owning the only path; children get `@Binding var path`.
- macOS: `NavigationSplitView` with a typed sidebar enum as selection; the detail column hosts a `NavigationStack` driven by the same route enum.

### Design tokens

- `Utilities/` holds `Spacing`, `CornerRadius`, `BorderWidth`, `IconSize` enums, extended so call sites read `.padding(.spacing.medium)`, `.cornerRadius.large`, `.iconSize.small`. A missing value is added to the enum, never inlined.
- Colours live in the asset catalog (light/dark variants) and are used as generated symbols (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`). Never `Color(red:green:blue:)` in a view.

### Launch environment

Parsed once at launch into an `AppEnvironment` value and injected; nothing else reads `ProcessInfo`.

| Argument | Effect |
|---|---|
| `-UITesting` | In-memory store, fake side-effecting services (network, clock, helper) |
| `-ShowcaseData` | Same, plus seeds the marketing dataset |

Tests and screenshots can never see or damage real data. Showcase seed values are **marketing assets**, not fixtures — changing them changes the screenshots.

## Swift

- No force unwrap / `try!` unless genuinely unrecoverable.
- Swift-native over Foundation-legacy: `replacing(_:with:)`, `URL.documentsDirectory`, `appending(path:)`.
- `FormatStyle` only — no `DateFormatter`, `NumberFormatter`, `MeasurementFormatter`, no `String(format:)`.
- User-input filtering uses `localizedStandardContains()`.
- Static member lookup: `.circle`, `.borderedProminent`.
- One type per file (the `Feature+Name.swift` pattern satisfies this).

## SwiftUI — every platform

- `foregroundStyle()`, `clipShape(.rect(cornerRadius:))`, `bold()` over `fontWeight(.bold)`.
- `onChange` two-parameter or zero-parameter form only.
- `Button` over `onTapGesture` unless location/count matters. Image buttons carry text: `Button("Add", systemImage: "plus", action: add)`.
- No `AnyView` unless forced.
- Dynamic Type; no fixed font sizes. Spacing and padding only through tokens.
- `containerRelativeFrame` / `visualEffect` / `ViewThatFits` before `GeometryReader`. Never `UIScreen.main.bounds`.
- `ScrollPosition`, `defaultScrollAnchor`, `.scrollIndicators(.hidden)`; no `ScrollViewReader`.
- `ForEach(x.enumerated(), id: \.element.id)` — no `Array(...)` wrap.
- `ImageRenderer` for rendering views. No UIKit/AppKit colours.
- Empty and error states: `ContentUnavailableView`, never hand-built.
- Destructive actions confirm with `confirmationDialog`.

## Visual style & motion

- System font only. Changing numbers use `.monospacedDigit()` + `.contentTransition(.numericText())`.
- Small, curated, warm/muted palette. Colour choice = tasteful presets first, full `ColorPicker` as escape hatch.
- **Adaptive contrast:** foreground on any variable background is computed from the WCAG contrast ratio at runtime. Implemented as a small helper in Core — no dependency.
- Depth: soft colour-matched shadows; low-opacity hairline strokes so light elements don't dissolve; system materials (`.regularMaterial`, `.ultraThinMaterial`) for chrome.
- Springs, never linear. Every animation tied to a real event.
- Feedback: `.sensoryFeedback(_:trigger:)` — heavy impact for the primary action, lighter for secondary. Fully usable silently; no sound unless asked.
- Press feedback: custom `ButtonStyle` scaling down slightly on press, with a spring. Content controls only — toolbar and menu controls stay native.
- Progressive disclosure: search/sort appear past a sensible item count; secondary actions go in menus.

## Accessibility (always on)

- Every interactive and dynamic element has an identifier, label and value.
- Identifiers are stable camelCase, suffixed with the item for collections: `addItemButton`, `saveItemButton`, `openItem-<name>`, `increment-<name>`. They are the UI-test API — tests never match on labels (labels are copy and will change).
- Dynamic Type via `@ScaledMetric`; text scales and shrinks gracefully.
- Light/dark and increased contrast handled through asset-catalog variants.

## macOS — the rules iOS habits break

```
┌ Menu bar ── App · File · Edit · View · Window · Help ── every action lives here
├──────────────┬────────────────────────────┬──────────────┐
│ Sidebar      │ Content                    │ Inspector    │
│ NavigationSp │ Table / detail             │ .inspector() │
│ litView      │ .toolbar · .searchable     │              │
└──────────────┴────────────────────────────┴──────────────┘
 Settings scene (⌘,)   ·   extra Window scenes   ·   MenuBarExtra (if needed)
```

| iOS habit | macOS rule |
|---|---|
| `TabView` as root | `NavigationSplitView` sidebar. Shared code may use the `Tab` API with `.tabViewStyle(.sidebarAdaptable)`. |
| Settings screen inside navigation | `Settings { }` scene, opened with ⌘, / `openSettings`. |
| Sheet for everything | Sheets only for modal tasks that block the window. Secondary content → inspector, popover, or its own `Window`. |
| `List` / grid of tappable cards | `Table` with sortable columns (`KeyPathComparator`), `Set<ID>` multi-selection, `contextMenu(forSelectionType:)`. Grids only where the content is visual. |
| Swipe actions | `.onDeleteCommand`, context menu, toolbar button. |
| Size classes | Don't exist on macOS. Adapt to window width with `GridItem(.adaptive)`, `ViewThatFits`, `containerRelativeFrame`. |
| Haptics carry feedback | Mostly unavailable. Motion and state carry it; `.sensoryFeedback` stays as a harmless no-op. |
| Touch only | Hover states, `.help()` on every icon-only control, right-click menus. |
| No keyboard | Every action in `.commands { }`; frequent ones get `.keyboardShortcut`. `@FocusState`, `focusable()`. Full keyboard navigation. |
| One scene | `WindowGroup` + `Window` for singletons. `.defaultSize`, `.windowResizability(.contentMinSize)`, `@SceneStorage` restoration. |
| Navigation bar | `.toolbar` with explicit placements, `.navigationTitle` + `.navigationSubtitle`. |
| Share sheet | `ShareLink`, `.fileExporter`, `.dropDestination`, `.copyable`. |
| 44 pt touch targets | Native control sizes; `.controlSize(.small)` in dense panes. |
| `UIApplication` | Scene APIs + environment (`openWindow`, `dismissWindow`, `openSettings`). `@NSApplicationDelegateAdaptor` only for what SwiftUI cannot do, with the reason in a comment. |

- Menu commands reach the active window through `@FocusedValue` / `.focusedSceneValue` — never a global singleton.
- `Form` + `.formStyle(.grouped)` for settings and editors.

### macOS distribution & security

- App Sandbox + Hardened Runtime on. Every entitlement carries an XML comment saying why.
- Never declare an entitlement, capability or background mode for a feature that isn't wired.
- Privileged work goes in a helper registered with `SMAppService`. Never `sudo`, never `AuthorizationExecuteWithPrivileges`.
- Helper launchd plist declares `AssociatedBundleIdentifiers` so Login Items shows the app's real name and icon.
- App ↔ helper over XPC, code-signing requirement enforced on both ends (`setCodeSigningRequirement`).
- Readable reverse-DNS ids: `dev.jc.<app>`, helper `dev.jc.<app>.<Role>`.
- Direct distribution: Developer ID + notarization. Claims the app makes must be verifiable with OS tools.

## iOS specifics

- `NavigationStack` + `navigationDestination(for:)`; never `NavigationView`.
- `Tab` API, never `tabItem()`.
- One adaptive layout driven by size class — never a separate iPad code path.
- Primary action wired to App Intents / App Shortcuts when it makes sense (also on macOS).

## Data

- SwiftData (`@Model`, `@Query`, `ModelContext`), never Core Data.
- SwiftData lives only in the app target. Core defines the storage protocol; the app conforms with SwiftData; Linux consumers bring their own conformance.
- Models are CloudKit-ready even before sync is wired: no `@Attribute(.unique)`, every property defaulted or optional, every relationship optional.
- Derived values are `@Transient`. Persist the minimum (one hex string, not four colours).
- One `ModelContainer`, built in the `App` from `AppEnvironment`.
- Secrets never enter the repo.

## Repository layout

```
<Repo>/
├── AGENTS.md  CLAUDE.md → AGENTS.md
├── README.md                      hero + features grid from docs/assets/
├── CHANGELOG.md                   entries under **Unreleased**
├── CONTRIBUTING.md
├── Gemfile  Gemfile.lock          fastlane, always `bundle exec`
├── fastlane/  Fastfile  Snapfile
├── Marketing/copy.json            captions, palettes, targets — single source
├── Scripts/generate_appstore_assets.swift
├── AppStoreAssets/                GENERATED — never edit
├── AppStoreSimulatorCaptures/     GENERATED — committed raw captures
├── docs/
│   ├── assets/                    GENERATED — README artwork
│   ├── ARCHITECTURE.md  TESTING.md  SCREENSHOTS.md  CI.md
│   └── APP_STORE.md  PRIVACY.md
├── <App>/  Features/  Components/  Utilities/  Platform/  Assets.xcassets/
├── <App>Tests/
└── <App>UITests/                  incl. AppStoreScreenshotUITests, vendored SnapshotHelper.swift
```

- `docs/` is accurate, not aspirational — updated in the same PR as the behaviour. `ARCHITECTURE.md` ends with a **Known rough edges** section.
- `SnapshotHelper.swift` is vendored verbatim from the fastlane gem; re-copy, never edit.
- User-facing strings in `Localizable.xcstrings` with symbol keys (`extractionState: manual`), used as `Text(.helloWorld)`.

## Testing

| Layer | Tool | Covers |
|---|---|---|
| Unit | Swift Testing (`@Test`, `#expect`) | Every rule: guards, transitions, validation. `@MainActor` where SwiftData is touched. |
| UI | XCUITest, Robot Pattern | Every flow a user can complete end to end, driven by accessibility identifiers |
| Launch | XCUITest | Launch screenshot per configuration |
| Marketing | `AppStoreScreenshotUITests` | Asset generation, **not** correctness — excluded from `test` |
| Previews | `#Preview` | Every view, fed by the feature's `PreviewContainer` (in-memory) — reused, never rebuilt inline |

- Core is unit-testable without UI: inject clocks, sockets, stores.
- Results land in `fastlane/test_output/` (JUnit + `.xcresult`), gitignored, uploaded by CI.
- Test lanes pick the first available of a preference list of iPhones (override with `TEST_DEVICE`), so they never break on simulator naming.

## Marketing assets

Every App Store screenshot and README image is generated. Nothing is cropped by hand.

```
AppStoreScreenshotUITests            launched with -ShowcaseData
  snapshot("02-tap-to-count")        status bar 9:41, appearance pinned
        │
        ▼
fastlane/screenshots/<locale>/       raw PNGs, already at upload size
        │
        ▼
Marketing/copy.json ──────► Scripts/generate_appstore_assets.swift
  captions · palettes · targets       AppKit renderer, no bezels, no ImageMagick
        │
        ├──► AppStoreAssets/              upload-ready: plain + captioned per size
        ├──► docs/assets/                 hero.png 2400×1000, feature-NN.png 620 px, app-icon.png
        └──► AppStoreSimulatorCaptures/   committed sources → re-render without a simulator
```

**Commands**

```
bundle exec fastlane screenshots   # capture on every target, then render
bundle exec fastlane marketing     # re-render from committed captures (fast path)
swift Scripts/generate_appstore_assets.swift   # what `marketing` runs
```

**Rules**

- `copy.json` entry `id` is the contract with the UI test: `snapshot("<id>")` must match. New screenshot = new `snapshot` call **and** new entry.
- Colours in `copy.json` are `[r, g, b]` 0–255, optional alpha. Copy changes need no Swift edits.
- Targets are declared once, in `copy.json`. `Snapfile` and `Fastfile` read them from there — never three hand-synced lists.
- Each capture device renders natively at an upload size; the renderer never upscales and refuses an undersized capture.
- `prepare_simulators` lane creates missing devices from the newest runtime — reproducible on a fresh checkout or CI.
- Snapfile pins `override_status_bar(true)` and the appearance the palettes were designed against (e.g. `dark_mode(true)`).
- Renderer: vertical `NSGradient`, title `systemFont` `.black`, subtitle `.semibold`, screenshot clipped to a rounded rect with drop shadow and 0.18-alpha white hairline. iPhone frames inset by fixed width; iPad/Mac frames sized to available height.
- Env overrides: `<APP>_PROJECT_ROOT`, `SCREENSHOT_INPUT_DIR` (default `fastlane/screenshots/<locale>`, then `AppStoreSimulatorCaptures`), `APPSTORE_OUTPUT_DIR`, `DOCS_ASSET_DIR`.
- No capture found → print every path tried, exit 1. Never guess.
- Never regenerate assets inside an unrelated PR; say so in the description when a change needs new screenshots.

**iOS targets**

| Simulator | Pixels | Slot |
|---|---|---|
| iPhone 16 Pro Max | 1320 × 2868 | 6.9″ |
| iPhone 11 Pro Max | 1242 × 2688 | 6.5″ |
| iPad Pro 13-inch (M4) | 2064 × 2752 | 13″ |

**macOS targets** — fastlane `snapshot` is iOS-only, so the Mac path differs only at capture:

| Step | How |
|---|---|
| Launch | `-ShowcaseData -ApplePersistenceIgnoreState YES`; screenshot mode fixes window content size 1440 × 900 and pins appearance |
| Capture | `app.windows.firstMatch.screenshot()` → `XCTAttachment`, `name = <id>`, `lifetime = .keepAlways` |
| Export | `xcrun xcresulttool export attachments` → `fastlane/screenshots/macOS/` |
| Size | Captured on a Retina display → 2880 × 1800 (16:10 slot). CI runners at 1× produce undersized captures, which the renderer rejects — capture locally, commit to `AppStoreSimulatorCaptures/macOS/` |
| Render | Same script, same `copy.json`, Mac canvas 2880 × 1800 |

## CI

Two GitHub Actions workflows: fast feedback on PRs, slow marketing work on demand.

| Workflow | Trigger | Runs | Artifacts |
|---|---|---|---|
| `ci.yml` | push to `main`, every PR; `concurrency` cancels superseded runs | `bundle exec fastlane test`; plus `swift test` on Linux for Core/CLI | `fastlane/test_output`, `if: always()` |
| `screenshots.yml` | `workflow_dispatch`, `v*` tags | `bundle exec fastlane screenshots` | `appstore-assets` 30 d, `readme-artwork` 30 d, `raw-captures` 14 d |

- `setup-xcode` `latest-stable`; `setup-ruby` with `bundler-cache: true`; `xcrun simctl list devicetypes` as a diagnostic.
- SPM cache keyed on `Package.resolved`; `SPM_CACHE_PATH` threaded to `scan`'s `cloned_source_packages_path`, or the cache is never read.
- No App Store Connect auth, no `deliver` / `pilot` / `match` / `gym`, no secrets. Every job targets a simulator or the host Mac, so forks run CI unchanged.
- Workflows never commit back. Download the artifact, review, commit deliberately.
- Local commands are exactly CI's commands. The only CI-only setting is `SPM_CACHE_PATH`.
- `Gemfile.lock` lists every runner platform (`bundle lock --add-platform arm64-darwin-26`).
- If signing ever blocks a simulator build: `xcargs: "CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO"`.

## Build & verify

- If the session has no `xcodebuild` (e.g. a Linux shell): **never claim a build or test passed.** Write the code, hand back the exact command, fix from the pasted output.
- Commands:
  ```
  bundle exec fastlane test          # unit + UI (no screenshots)
  bundle exec fastlane unit_tests
  bundle exec fastlane ui_tests
  swift build && swift test          # each package
  xcodebuild -scheme <App> -destination 'platform=macOS' build test
  swiftlint --strict                 # if installed; zero warnings before commit
  ```
- If the Xcode MCP is configured, prefer it: `DocumentationSearch` before using an API, `BuildProject` + `GetBuildLog` after changes, `RenderPreview` to check views, `XcodeListNavigatorIssues`, `ExecuteSnippet`, and `XcodeRead` / `XcodeWrite` / `XcodeUpdate` for project files.

## Pull requests

- Branch off `main`; focused diffs.
- `bundle exec fastlane test` passes — CI runs the same command.
- Docs updated in the same PR when behaviour changes.
- `CHANGELOG.md` entry under **Unreleased** for anything user-facing.

## Definition of done

**Any new screen**

- [ ] Route case added; `navigationDestination` exhaustive
- [ ] Feature folder in the `Feature+Name.swift` layout; inner views are structs
- [ ] Tokens only — no literal spacing, radius, size or colour
- [ ] Identifiers, labels, values on everything interactive
- [ ] Empty/error via `ContentUnavailableView`; destructive actions confirmed
- [ ] Unit tests for its rules; UI test for its end-to-end flow
- [ ] `#Preview` via the in-memory `PreviewContainer`

**macOS screen, additionally**

- [ ] Reachable from the sidebar **and** the menu bar
- [ ] Every action has a menu item; frequent ones have ⌘ shortcuts
- [ ] Usable keyboard-only: Tab, arrows, Return, Esc, ⌫
- [ ] Icon-only controls have `.help()`
- [ ] Lists are `Table`s with multi-select; context menu mirrors the menu bar
- [ ] Clean from min window size to full screen; light, dark, increased contrast
- [ ] Window and selection restore on relaunch
- [ ] No iOS-only API, no `#if os` in feature views

**New app**

- [ ] SwiftUI, universal, OS 26 target, Swift 6.2 strict
- [ ] SwiftData, CloudKit-ready models
- [ ] Typed navigation; design tokens; asset-catalog colours as symbols
- [ ] Curated presets + picker; runtime adaptive contrast; monospaced digits
- [ ] Springs tied to events; `.sensoryFeedback`; silent-usable
- [ ] `-UITesting` / `-ShowcaseData` launch environment
- [ ] fastlane lanes: `test`, `unit_tests`, `ui_tests`, `screenshots`, `marketing`, `prepare_simulators`
- [ ] Scripted marketing pipeline from `copy.json`
- [ ] `ci.yml` + `screenshots.yml`; docs set present

## Project specifics

Fill per repo.

| | |
|---|---|
| Name | |
| Bundle ids | |
| Packages / targets | |
| Platforms | |
| Showcase dataset | |
| Open decisions | |
