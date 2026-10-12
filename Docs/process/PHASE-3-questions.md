# Phase 3 — questions for JC

Append-only. Each says what it blocks and what was done instead, so nothing here stopped
the run.

## Q1 — zhen-core 0.7.0: what the app works around with core frozen (stage 1)

You chose app-only for this run. These are the places where the app works around core
instead of fixing it, each recorded as a bend in `PHASE-3-progress.md`. Together they make
a sensible 0.7.0:

| Core change | What it would remove from the app |
|---|---|
| A port-scan call that is not a run, or presence judged within the scanned subnet | `ProbeOnlyStore`; port results lost at relaunch |
| A port-stage option for new devices only | the relabelled "Check ports on every scan" |
| A `zhen-helper` product | `release.sh` building it separately (phase 2, E1, Q8) |
| Port events (`DerivedEvent.Kind` for ports) | the always-empty Ports segment (phase 2, Q3) |
| A shorter or cached helper check when the registration does not answer | the 3.2 s engine build on a stale registration |

**Blocks:** nothing in this run. **Instead:** each workaround is named in
`Docs/ARCHITECTURE.md`'s Known rough edges (stage 5).

## Q2 — The stale helper registration on this Mac (stage 1)

`sfltool dumpbtm` shows `com.jctec.zhen.helper` registered by
`/Users/jc/Dev/InfinityCastle/build/Zhen.app/`, the monorepo-era build, which no longer
exists. launchd's spawn fails, so every engine build waits out the helper's 3 s timeout.
**Blocks:** the first scan of each launch is 3 s slower on this Mac. **Instead:** the engine
is reused while the helper's state is unchanged. Remove the registration from Zhen's
Settings, using Remove beside the helper controls: the installed app has the same bundle
ID and team. If that fails, `sudo sfltool resetbtm`, which resets every app's background
items.

## Q3 — Push `phase-3` (and `phase-2`) so CI runs? (stage 5)

As in phase 2's Q1: both branches are committed locally, and neither has been pushed. A push
to a public repository is outward-facing. **Blocks:** `ci.yml` (now `bundle exec fastlane
test`) and `screenshots.yml` have never run on GitHub, and `macos-26` and Ruby `4.0` on the
runner are untested assumptions. **Instead:** the lanes ran locally (`fastlane unit`
green, JUnit and `.xcresult` written).

## Q4 — String keys are the English text, not symbol keys (stage 5) — **resolved in part 2**

Moved to symbol keys after all: 248 of them, every call site converted, no automatic key
left. Kept below as it was asked.


AGENTS.md asks for `Localizable.xcstrings` with symbol keys (`extractionState: manual`),
used as `Text(.key)`. The catalogue here is filled from the compiler's extraction: 243
strings, keyed by their English text, with plural forms for the 10 counted ones.
Symbol keys would touch every one of about 245 call sites. That is a mechanical change
that deserves its own pull request, and in this run it would have competed with the bugs
for attention. **Blocks:** nothing user-visible. **Instead:** recorded as a deviation in
`Docs/ARCHITECTURE.md`. Say whether you want the migration.

## Q5 — No marketing captures are committed (stage 5)

The pipeline runs end to end: `AppStoreScreenshotUITests` makes five 2880 × 1800
captures, the export script refuses any other size, and the renderer produced the
captioned images, the hero and the feature tiles. Rendered into scratch only.

The captures show this Mac's Dock across the bottom of the window and a Calendar
notification banner. An XCUITest window screenshot is the screen's pixels. A 1440 × 900
window cannot clear the Dock on a 1512 × 949 display.

**Blocks:** `AppStoreAssets/`, `Docs/assets/` and the README artwork. **Instead:**
`Docs/SCREENSHOTS.md` says how to take clean ones: Do Not Disturb, Dock hidden, then
`bundle exec fastlane screenshots`, check the images, and copy the captures to
`AppStoreSimulatorCaptures/macOS/` to commit.

## Q6 — The app icon is `Design/marks/03-z/png/icon-colour-1024.png` (stage 5)

The asset catalogue's AppIcon set had no images at all, so the built app had no icon.
Login Items would have shown a generic one, the exact failure the helper design exists to
prevent. The icon set is now generated from the colour mark (`Scripts/generate-app-icon.sh`).
**Blocks:** nothing. **Instead:** used the mark already in the repository. If a different
mark (or the grey one) is the app's, change `SRC` in the script and rerun it.

## Q7 — Leftovers from older builds on this Mac (end of run)

`~/Library/Containers/com.jctec.zhen` is a sandbox container from an earlier sandboxed
build. `defaults read com.jctec.zhen` resolves to it, which hides the real preferences
from that command. Zhen today is unsandboxed and never reads it. With the stale helper
registration (Q2), it is the last trace of the monorepo-era app.
**Blocks:** nothing. **Instead:** the run's own leftovers (test preference domains, and the
subnet a UI test wrote to the real domain before the stage-4 fix) are cleared at the end of
the run. The container is listed here rather than deleted, because macOS protects
containers and its contents predate this run.
