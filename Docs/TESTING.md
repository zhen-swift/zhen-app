# Testing

| Layer | Where | Runs |
|---|---|---|
| Unit | `ZhenTests/`, Swift Testing | every rule: the pipeline's isolation and coalescing, the session, the table's identities and order, fixtures, scanning behaviour, detail derivations, settings, export, plurals, the built app's Info.plist and daemon plist |
| UI | `ZhenUITests/`, XCUITest with the robot in `ZhenRobot.swift` | every room and flow end to end, by accessibility identifier; the harness gates (keyboard-only, window size range, restoration, four appearances, the all-unidentified acceptance case); two accessibility audits — the project's (every control has an identifier and a name) and Apple's `performAccessibilityAudit` on every screen and state |
| Marketing | `ZhenUITests/AppStoreScreenshotUITests.swift` | asset capture, not correctness — skipped unless `ZHEN_SCREENSHOTS=1` |
| Previews | `#Preview` on every view, fed by `Fixtures/PreviewContainer` | — |

## Commands

```
bundle exec fastlane test      # unit + UI → fastlane/test_output (JUnit + .xcresult)
bundle exec fastlane unit
bundle exec fastlane ui
```

First time: `bundle config set --local path vendor/bundle && bundle install`.

The lanes sign ad hoc (`CODE_SIGN_IDENTITY=-`), so forks and CI need no team.

Performance gates (`ScaleTests`, the session's coalescing) state their budgets as measured
on a developer's Mac and compare through `Budget.of(_:)`. CI sets
`TEST_RUNNER_ZHEN_BUDGET_SCALE=3` for its slower virtual Mac; locally the scale is 1.

## What a test can touch

Nothing real. Under `-UITesting`, and in the unit-test host (detected from
`XCTestConfigurationFilePath`), the app:
- reads the fixture network into an in-memory store
- scans with `FixtureScanRunner`
- talks to `FakeHelperService`
- keeps preferences in the throwaway `com.jctec.zhen.fixture` domain

A unit test that needs its own preferences passes its own `UserDefaults` to
`NetworkModel(environment:defaults:)`. The fixture domain is cleared whenever a fixture
model is made, so parallel tests would clear each other's.

The fixture every test runs on is a real home network, anonymised by `Scripts/anonymise-scan.py`.
`anonymise-scan.py --verify RAW FIXTURE` proves no raw identifier survives. The raw capture
is never committed. The marketing captures use a second, invented network instead
(`-ShowcaseData`, `Docs/SCREENSHOTS.md`). No test depends on it except
`ShowcaseFixtureTests`, which holds it to core's rules.

## UI tests and the desktop

UI tests type real keys and read real screen pixels. Run them with nothing else driving
the screen: no other app's UI tests, no window that could take key focus. `ZhenRobot`
activates the app before every key press, but cannot defend a capture against a window
drawn over it.

## The gates, and proving them

Every gate is first shown failing on a deliberate break, then recorded as passing. A
gate's doc comment says `Gate.`, and most also name the break (`Break: …`) so it can be
repeated; adding the break to a gate that lacks one is a welcome first pull request.
