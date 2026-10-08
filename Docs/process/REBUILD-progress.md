**Liveness:** 2026-10-07 — P1.2 done. Next: P1.3 type, P1.5 components.

# Rebuild — phases 0 and 1, progress

The ledger for `Docs/process/prompts/rebuild-phase-0-1.md`. Read before each step.

## Inputs, and what was missing

The session prompt named four documents, in this order: `Docs/plans/PHASE-0-START.md`,
`Docs/RULES.md`, `AGENTS.md`, `Docs/process/prompts/rebuild-phase-0-1.md`.

**The first two do not exist.** Searched, no limit: this repository's tree at `fdb7eaf`
(`git ls-files`), every branch of `zhen-swift/zhen-app` and `zhen-swift/zhen-core` on GitHub
(`gh api …/contents/<path>`, 404 on each), the archived monorepo's history
(`git log --all -- <path>`, empty), `find ~/Dev -maxdepth 5` and Spotlight (`mdfind -name`).

In place of `PHASE-0-START.md`, JC said (2026-10-07): **phase 0 starts by deleting all the
code and starting from zero.** That supersedes the brief's phase-0 opening (P0.1
unregister → P0.2 extract → … → P0.4 delete), so deletion is step 0 here.

`RULES.md` (the product's decisions) stays missing. The brief's *Decisions already made*
list is used as the product decisions until it turns up; see `REBUILD-questions.md` Q1.

## Step 0 — delete all the code

Base: `fdb7eaf78a27467ee91ee0af95b3bdf8128065a1`. Everything deleted here is readable as
`git show fdb7eaf:<path>`; P0.2 and P1.2 read from that SHA.

**Why deleting first is safe, checked before deleting.** The brief ordered unregistration
first because deleting *the bundle* while the daemon is registered strands it. The
registration does not point at this repository's source:

    $ launchctl print system/com.jctec.zhen.helper        # no sudo needed to read
    system/com.jctec.zhen.helper = {
    	active count = 0
    	path = (submitted by smd.329)
    	type = Submitted
    	managed_by = com.apple.xpc.ServiceManagement
    	state = not running
    	program identifier = Contents/MacOS/zhen-helper (mode: 2)
    	parent bundle identifier = com.jctec.zhen
    	parent bundle version = 0.5.0
    	BTM uuid = 4FCC3863-71C1-48A7-A520-3F92BCDFC896
    	…
    	runs = 0
    	last exit code = (never exited)

The only bundle with `com.jctec.zhen` on this Mac (`mdfind kMDItemCFBundleIdentifier`) is
`~/Dev/InfinityCastle/build/Zhen.app`, untracked build output in the archived monorepo,
whose `Contents/Library/LaunchDaemons/com.jctec.zhen.helper.plist` has `BundleProgram =
Contents/MacOS/zhen-helper`. Its Settings carries the Unregister button
(`Zhen/Model/HelperInstaller.swift:84` at `fdb7eaf`, `service.unregister()`). **That bundle
must not be deleted until P0.1's gate passes.** `git rm` here does not touch it.

Scope: "all the code" = `Zhen/`, `ZhenTests/`, `Resources/`, `Zhen.xcodeproj`, `Scripts/`
— 88 of 126 tracked files, 12,611 lines of text (`git show --stat`; `wc -l` said
19,674 because it counted the icon PNGs' newline bytes as lines). The brief kept six scripts; JC's instruction is
wider, so they go too, and the phase-1 report still lists what the new app needs from each
(from `fdb7eaf`). Kept: `Docs/`, `Design/`, `AGENTS.md`, `README.md`, licence and
community files, `.editorconfig`, `.gitattributes`, `.gitignore`.

**Done:** `02adbb7`. `git ls-files Zhen ZhenTests Resources Zhen.xcodeproj Scripts` → 0
lines (88 before). Nothing left on disk under those roots (`ls` → "No such file" × 5).

## P0.1 — unregister the helper · done 2026-10-07 (by `launchctl`, not `SMAppService`)

**Before** — the print in step 0 above, read 2026-10-07 without sudo: `type = Submitted`,
`BTM uuid = 4FCC3863-71C1-48A7-A520-3F92BCDFC896`, `runs = 0`.

The only `unregister()` on this Mac is in `~/Dev/InfinityCastle/build/Zhen.app` (built
2026-09-23, signed `com.jctec.zhen`, team `S8662L649U`). Its binary carries
`unregisterAndReturnError:` and `onRemoveHelper` (`strings …/Contents/MacOS/Zhen`), and its
Settings draws `Remove` beside the helper (`SettingsView.swift:252,264` at `fdb7eaf`).
Unregistering needs no password; nothing here needs root.

**JC's steps:**

1. `open ~/Dev/InfinityCastle/build/Zhen.app`, then ⌘, → the helper row → **Remove**.
2. After: `launchctl print system/com.jctec.zhen.helper` — the gate is
   `Could not find service "com.jctec.zhen.helper" in domain for system`. Paste it here.
3. Optionally, System Settings → General → Login Items & Extensions: Zhen gone.

Only after the gate passes may `~/Dev/InfinityCastle/build/` be deleted. Nothing else in
phases 0–1 depends on this step, so work continues.

## P0.2 — extract the findings · done

`Docs/process/DESIGN-FINDINGS.md`, read at `fdb7eaf`. **Gate adapted:** step 0 deleted the
tests first, so "a test that still exists" means one that exists at `fdb7eaf`, cited by
path and line, readable with `git show`.

- **Contrast:** the test holds no ratio literals; `printTable()` computes them. Recomputed
  from `Palette.swift` at `fdb7eaf` by `Docs/process/evidence/contrast-table.py`, which uses
  the test's formula (lines 67–83) and the palette's tier lookup. 100 asserted pairs, 0
  below floor. **Would have failed:** run with the AA floor at 4.6 → 3 pairs below floor,
  printed. **Independent check:** matches A1's published table to two decimals, all 26
  numbers A1 prints. A1's two original failures recomputed: 3.00 and 2.24, as A1 says.
- **Symbols:** 30 names (`Symbols.swift` lines 18–86), checked with the test's own call,
  `NSImage(systemSymbolName:)`, on macOS 26.6.2: 30 exist. **Would have failed:** control
  name `zhen.not.a.symbol` → `MISSING`.
- **Keyboard: the brief's premise does not hold.** At `fdb7eaf`, `KeyboardTests.swift`
  withdraws the tab-stop counts (lines 9–23; 12 / 5 / 5, measured against a design JC
  replaced). Recorded as withdrawn; eight measured findings that survive are recorded with
  lines. No traversal order exists to extract.

## P0.3 — move the documents that describe the dead app · done

`git mv` of six files to `Docs/process/` (A1, A2, A3, `03-zhen-app.md`,
`REVIEW-ui-architecture.md`, `plans/RESPONSIVE-plan.md`); `APP-CATCHUP.md` was already
there. All six are 100% renames (`git status`: `R`). `Docs/README.md` and the README's table
rewritten. None of the six had relative links that a move could break
(`grep -o '](…)'` excluding URLs and anchors: no output).

**Gate:** every path the two indexes name exists, 17 of 17 ok. **Would have failed:** the
same loop given `Docs/process/not-a-file.md` printed `MISSING`.

## P0.4 — delete · done (by step 0), gate run here

The deletion was step 0 (`02adbb7`), wider than the brief's list. Gate, run on `83b3166`:

    $ git ls-files Zhen ZhenTests Resources Zhen.xcodeproj Scripts | wc -l
           0

`git grep -n -F '<p>' -- . ':!Docs/process' ':!Docs/plans'` for each of `Zhen/`,
`ZhenTests`, `Resources/`, `Zhen.xcodeproj`, `Scripts/`, `generate-xcodeproj`, `make-icon`,
`build-app.sh`, `release.sh`, `verify-helper`, `check-fixed-sizes`, `count-fixed-sizes`,
`fixed-sizes-baseline`, `Palette.swift`, `Metrics.swift`. No limit. Hits, each classified:

| Hit | Why it stays |
|---|---|
| `README.md:23–24` | the sentence saying these were deleted |
| `.gitignore:21` | names the **new** `Zhen.xcodeproj` P0.5 creates |
| `AGENTS.md:222, 264, 277` | `Scripts/generate_appstore_assets.swift`, a future file the rules require (phase 3) |

Nothing else. **Would have failed:** the same grep at `fdb7eaf` → `make-icon` 4 hits,
`generate-xcodeproj` 5, `build-app.sh` 11, `Palette.swift` 3.

### The deleted scripts, and what the new app needs from each

All at `fdb7eaf:Scripts/`. Deleted, not fixed. They named monorepo paths and did not run.

| Script | Lines | What it did | What the new app needs from it |
|---|---|---|---|
| `build-app.sh` | 172 | assembled `Zhen.app` by hand around Xcode's binary: Info.plist generated from the scanner's Bonjour vocabulary, the daemon plist where `SMAppService` looks, inside-out signing with a team check | **bundling.** The new project should do this in Xcode: a Copy Files phase for `Contents/Library/LaunchDaemons/com.jctec.zhen.helper.plist`, the helper as an embedded target, `NSBonjourServices` in the target's Info. Re-read for the Bonjour list and the signing order |
| `release.sh` | 187 | sign, notarize, staple, verify; credentials only via a keychain profile | **signing and notarization** for Developer ID (AGENTS.md: direct distribution). Phase 3 or later |
| `verify-helper.sh` | 295 | proved the helper from the wire: ARP frames the app built, not the kernel's | **the helper's proof.** The claim belongs to zhen-core's helper, so it likely moves there; the app needs it once it registers the helper again |
| `check-fixed-sizes.sh` | 86 | ratchet: fixed `.frame` sizes may fall, never rise; case-insensitive on `width:` | **the ratchet shape** for P1.6's `check-tokens.sh`, and the lesson about the case-sensitive grep |
| `count-fixed-sizes.py` | 72 | counted fixed frames, separating `#Preview` canvases from layout | the preview/layout split, if `check-tokens.sh` ever counts frames |
| `fixed-sizes-baseline.txt` | 1 | the ratchet's number | nothing: it counted views that no longer exist |

`generate-xcodeproj.py` and `make-icon.sh` were the brief's own deletions: the first is
replaced by folder-synchronised groups, the second by an Icon Composer icon from
`Design/marks/03-z/` (plan §3).

## P0.5 — the empty project · done 2026-10-07 (generated, not hand-made in Xcode)

**Precondition:** `git ls-remote --tags https://github.com/zhen-swift/zhen-core.git 0.5.0`
→ `5c3ea419… refs/tags/0.5.0`, peeling to `8aa7b97`. Tagged. Xcode 26.6 (17F113).

**JC's steps:**

1. Xcode → File → New → Project → macOS → App.
2. Product Name `Zhen`; Team as for the old app (`S8662L649U`); Organization Identifier
   `com.jctec`; Interface SwiftUI; Language Swift; **Testing System: Swift Testing with
   XCTest UI Tests**; Storage **None**.
3. Save into `~/Dev/zhen-app`, with **"Create Git repository on my Mac" unticked** (it is
   one already). Xcode puts the project in an enclosing `Zhen/` folder; leave it there and
   I lift it to the root, so the root holds `Zhen.xcodeproj`, `Zhen/`, `ZhenTests/`,
   `ZhenUITests/`.
4. File → Add Package Dependencies → `https://github.com/zhen-swift/zhen-core.git`,
   Dependency Rule *Up to Next Major Version* from `0.5.0`; add `ZhenCore`, `ZhenScan`,
   `ZhenPrivilege` to the `Zhen` target.
5. Don't commit. Say "it exists".

**Then I check, before building on it:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`,
`MACOSX_DEPLOYMENT_TARGET = 26.0`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` and
`GCC_TREAT_WARNINGS_AS_ERRORS = YES`,
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`,
`PBXFileSystemSynchronizedRootGroup` for the sources, and an
`XCRemoteSwiftPackageReference` with `minimumVersion = 0.5.0` (not an
`XCLocalSwiftPackageReference`). Settings Xcode's template doesn't set, I set in the
project and record here.

**Meanwhile:** P1.4 does not need the project (it is a zhen-core pull request), so it goes
next.

## P1.4 — the contrast helper: a zhen-core pull request · done (PR open, unmerged)

**zhen-core moved since the brief:** `0.6.0` exists (`ae0fc58`, 2026-10-05). It only removes
four rename-compatibility members of `HistoryLocation`, none of which the new app uses.
*Up to Next Major* from `0.5.0` resolves it, so P0.5's instructions stand.

Cloned to `~/Dev/zhen-core`, branch `contrast-helper`,
[zhen-swift/zhen-core#5](https://github.com/zhen-swift/zhen-core/pull/5). Not merged, not
tagged. `main` untouched.

- `Sources/ZhenCore/Accessibility/SRGBColor.swift`, `Contrast.swift`: `Contrast.ratio`,
  `Level` (`.nonText` 3, `.aa` 4.5, `.aaa` 7), `meets`, and
  `foreground(on:preferring:level:)`. That last one returns the first candidate that meets
  the level, or else the best one with `meetsLevel == false`.
- `Tests/ZhenCoreTests/ContrastTests.swift`: 10 tests; **the 100 pairs** of
  `DESIGN-FINDINGS.md` generated from the old palette (not retyped), each checked for its
  ratio (±0.005) and its floor; plus the artboard's failing greys, one preference list
  across all three dark surfaces, the `#767676`/`#777777` boundary, and falling short.
- Generated values: `Float` (old app) vs `Double` (Core) changes 0 of 100 at two decimals.

**Gate, locally (macOS 26.6.2, Swift 6.3.3):** `swift test` → 632 tests in 139 suites pass;
`main` without the change → 622 in 138. `check-docs.sh` PASS. **Shown failing**, each by an
exactly-once replacement, diff printed, file restored by `trap` and `cmp`'d identical:

| Mutation | Issues |
|---|---|
| A — AA floor 4.5 → 4.6 | 5 (the three pairs at 4.53, 4.54, 4.56, plus two selection tests) |
| B — linearisation 0.04045 → 0.03928 | **0, correctly**: no 8-bit value lies between them |
| C — linearisation → 0.5 | 105 |
| D — ratio without the 0.05 flare | 113 |

**A slip, caught:** the first run of A used a script with `set -o pipefail`, so the failing
`swift test` aborted it before its restore line. The mutated `4.6` stayed in the source until
I saw the file-change notice. Restored by exact replacement, re-verified green, script
rewritten to restore in a `trap`. Nothing was committed in between. Also corrected before
committing: the test header said "eleven" pairs sit within 0.1 of their floor; counted, it is
nineteen.

## P1.6 — the ratchet · script done and shown failing; CI written, not yet pushed

Ahead of P1.1–P1.5 because it needs no project, and because a ratchet written after the
work tends to be fitted to it.

`Scripts/check-tokens.sh`, in check-docs.sh's shape: twelve POSIX-ERE rules (spacing,
frame width/height incl. `min`/`max`/`ideal`, corner radius, line/border width, font size,
colour from components / string name / AppKit-UIKit / hex, and `var x: some View` except
`body`). `Utilities/` is excluded because that's where the token definitions live. A line
ending `// tokens: allow — <reason>` is skipped and counted. **Exits 2 on a missing or
empty source directory**: a pass on zero files is not a pass.

`--self-test` runs `Scripts/check-tokens.fixture.swift` (not compiled; outside the app's
folders) and compares the **exact line numbers** reported with the 20 lines marked
`expect:`, not just the count, plus exactly one allowed line and every rule firing.

**Run, 2026-10-07, macOS BSD grep:**

    $ Scripts/check-tokens.sh --self-test
    check-tokens self-test: 20 of 20 planted violations found, 1 allowed line skipped, every rule fired — PASS

**Shown failing** (each an exactly-once mutation, restored by `trap`, `cmp` identical):

| Mutation | Result |
|---|---|
| frame rule made case-sensitive (`width`, not `[wW]idth`): the old inventory's bug | FAIL, lines 13 and 14 (`minWidth`, `maxHeight`) missing |
| an unmarked `.padding(2)` added to the clean block | FAIL, line 34 reported but not expected |
| `computed-view` rule renamed, so the `body` exemption no longer applies | FAIL, line 8 (`var body`) reported |
| empty directory; `Zhen/` before the project exists | exit 2, "nothing was checked" |
| a one-file view with `.padding(8)`, then with `.padding(.spacing.small)` | exit 1 then exit 0 |

Two of my own rules were wrong before the first run and fixed before it: `Color(.sRGB, …)`
has a comma, not a colon, after `.sRGB`, and `Color(NSColor.red)` has no `(` after
`NSColor`. Both are fixture lines now.

`.github/workflows/ci.yml`: job `tokens` on `ubuntu-latest`, the self-test first (it proves
GNU grep reads the rules as BSD grep does), then the check. It parses (`ruby -ryaml`:
one job, three steps); `actionlint` is not installed. **Not pushed:** with no `Zhen/` the
check exits 2 and `main` would go red, so it goes up with the project. The gate ("has run
green on GitHub") is open.

### P1.4 — CI on the PR (run 37710570289)

- **macOS — the tool: pass.** Log: `✔ Suite "Contrast" passed`, `✔ Test run with 632 tests in
  139 suites passed`. So it ran my suite and did not skip it.
- **Linux: `Suite "Contrast" passed`**, then the job failed on
  `zhenTests/PipelineTests.swift:547: Fatal error: 'try!' … unsupportedPlatform`, signal 4.
  **Not mine:** `main`'s last run (37407410412, `ae0fc58`) fails Linux on the same line with
  the same error. It is AUDIT M2 ("Five `zhenTests` fail on Linux").
- Docs: pass.

## P1.2 — colour · sampling (see below), then colorsets: done

All six artboards sampled into `DESIGN-FINDINGS.md` section 4: 31 boxes on 01 and 02, 45
more on 03–06, every box saved under `evidence/artboard-boxes/` and re-run from there. **Cross-check against
the old palette:** surface, raised, selection, accent, primary text, online, warning and info
come out the same to the byte, which shows the sampler reads what the old app read. The
artboard's `65656C` / `ADADB0` reproduce A1's two known failures.

**New:** the artboards use six text greys on dark below primary, and four of them fail AA
on every surface. The light secondary grey `7B7B7F` fails too. The old app had two text
tokens. Choosing the corrected hierarchy is P1.2's work, and it is logged in the report as
not reconciled with the house rules as drawn.

**Not started, and why:** P1.1 tokens, P1.2 colorsets, P1.3 type and P1.5 components all
live in the Xcode project, which only JC can create (P0.5). Writing them into `Zhen/` first
would collide with the folder Xcode creates.

### P0.1 — how it was actually done

**The button route failed.** I scripted Settings → Remove with UI scripting, launching the
old app each time with `ZHEN_HISTORY` on a scratch file. The real store hashed the same
before and after every launch (`d735909a…`), and a backup is in the session scratchpad. It
could not work: ⌘3 did not switch rooms, and the old app's buttons expose no accessible
name (the AX tree shows `AXButton | missing value` throughout). That is the plan's
"identifiers: 0", measured. Its launch scan did use the helper (`active count = 2`, then
`state = running`).

**What worked:** `Docs/process/evidence/remove-old-helper.sh`, run by JC with sudo:
`launchctl bootout system/com.jctec.zhen.helper`, then `launchctl disable` so launchd
won't load it again if Background Task Management resubmits it. JC's output:

    == before
    	type = Submitted
    	state = running
    	BTM uuid = 4FCC3863-71C1-48A7-A520-3F92BCDFC896
    == after
    Bad request.
    		"com.jctec.zhen.helper" => disabled

**Gate**, re-checked by me without sudo: `launchctl print system/com.jctec.zhen.helper` →
`Could not find service "com.jctec.zhen.helper" in domain for system`, exit 113;
`pgrep -fl zhen-helper` → nothing. "Bad request." is launchctl's first line for any missing
service: a made-up label prints the same, so it does not mean the request failed.

**What remains:** the Background Task Management record (`4FCC3863…`) was never
unregistered through `SMAppService`, so Login Items may still list Zhen. The `disable`
override keeps it from loading. `~/Dev/InfinityCastle/build/` can now be deleted.

### P0.5 — how it was done

JC asked for scripts in place of hand-offs, so the project was written by a one-shot
generator (session scratchpad, not committed) that reproduces Xcode 26.6's macOS App
template: objectVersion 77, three `PBXFileSystemSynchronizedRootGroup`s (`Zhen`,
`ZhenTests`, `ZhenUITests`), a shared `Zhen` scheme, and zhen-core as an
`XCRemoteSwiftPackageReference`. Unlike `generate-xcodeproj.py`, it is not kept: Xcode owns
the file from here, and folder sync means adding a source file never touches it.

The app's root is a placeholder `ContentUnavailableView`, the minimum an `App` needs to
compile. It is not a screen. Template sources: `ZhenApp.swift`, `Assets.xcassets` (empty
AccentColor, AppIcon), one unit test (`ZhenVersion` links), one UI launch test. App Sandbox
and Hardened Runtime are on, with no entitlement beyond them because nothing else is wired.

**Verified from `xcodebuild -showBuildSettings -target Zhen`, not from the generator:**
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_VERSION = 6.0`,
`SWIFT_STRICT_CONCURRENCY = complete`, `MACOSX_DEPLOYMENT_TARGET = 26.0`,
`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`, `GCC_TREAT_WARNINGS_AS_ERRORS = YES`,
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`,
`PRODUCT_BUNDLE_IDENTIFIER = com.jctec.zhen`, `ENABLE_APP_SANDBOX = YES`,
`ENABLE_HARDENED_RUNTIME = YES`. Package reference: `kind = upToNextMajorVersion`,
`minimumVersion = 0.5.0`; `XCLocalSwiftPackageReference` count 0.

- `xcodebuild -scheme Zhen -destination 'platform=macOS' test -only-testing:ZhenTests` →
  zhen-core resolved **0.6.0** from GitHub, `** TEST SUCCEEDED **`, 1 test, no warnings.
- **Warnings really are errors:** a planted `let unused = 1` → `error: initialization of
  immutable value 'unused' was never used`, `** BUILD FAILED **`, exit 65. Removed.
- `Scripts/check-tokens.sh` → `1 files checked, 0 allowed by comment — PASS`.
- `.gitignore` now commits `Package.resolved` (it pins 0.6.0) and the project's own
  workspace. A first edit cut the old comment mid-sentence and left the ignore rule in
  place; `git check-ignore` caught it before the commit.

### P1.6 — CI gate

Pushed with the project (`fb69e48`); run 37713232116 on `ubuntu-latest`, GNU grep:
`check-tokens self-test: 20 of 20 planted violations found, 1 allowed line skipped, every
rule fired — PASS`, then `check-tokens: 1 files checked, 0 allowed by comment — PASS`.
P1.6 done.

## P1.1 — tokens · done

`Zhen/Utilities/`: `Spacing`, `CornerRadius`, `BorderWidth`, `IconSize`, four `nonisolated`
enums with `CGFloat` extensions so a view reads `.padding(.spacing.medium)`. `nonisolated`
because the target is MainActor by default and a `Shape` or `ButtonStyle` reads tokens off
the main actor.

**Measured from the artboards, not taken from A1 or the old `Metrics`.** The tools are in
`Docs/process/evidence/`: `runs-artboard.swift` (colour runs along a line) and
`corner-artboard.swift` (bounding box of a colour, then where the top row and left column
reach full strength). Artboards are 2x (2364 px = 1182 pt).

| Measured | pt | Where | A1 said |
|---|---|---|---|
| row pitch, separator | 51–52, 1 | 01, x=1300 | 52 |
| sidebar incl. divider `313136` | 228 | 01, y=900 | 228 |
| content inset | 20 | 03 | 20 |
| card padding / gap between cards / header rule to first card | 16 / 16 / 16 | 03 | 16 (card padding) |
| card radius | 8 (15–16 px, five cards in 03, 05, 06) | | **10** |
| field, button, selection, popup | 6 (11–13 px) | 01, 06 | 6 |
| chip radius | 4 (7 px; `private`, `GATEWAY`, `WINNER`) | 01, 03 | **5** |
| device tile radius | 10 (19 px) | 03 | — |
| filter pill, toggle | capsule | 04, 06 | — |
| status dot / footer dot / meter / stage check / tile | 8 / 6 / 12 / 15–16 / ~40 | 01, 03, 05 | — |

**A wrong control, caught:** the first corner tool walked outward from a point and stopped
on text and inner separators, reporting 0 for half the elements, including the card I had
measured by hand at 8. Rewritten to use the bounding box; the same card then measures 8.

Row height and sidebar width are `Table`'s and `NavigationSplitView`'s, not tokens.

**Gate:** `xcodebuild … test -only-testing:ZhenTests` → `** TEST SUCCEEDED **`, 4 tests
(call sites compile, including the Optional `spacing:` form; scales ascend); no compiler
warnings. `check-tokens.sh` passes (`Utilities/` is where the numbers live, and is excluded).

### P1.2 — colorsets

JC, 2026-10-07: "stick as best to design, creative liberty on the rest". So the rule in
`Docs/process/evidence/derive-palette.py` is: keep an artboard value wherever it reads; where
it doesn't, move it toward white (dark) or black (light) by the smallest step that clears its
floor on **every** background it is drawn on, so the hue survives. Increase Contrast comes
from the same rule at 7:1 for text and 3:1 for lines and marks.

**20 colorsets, four variants each** (light, dark, light high-contrast, dark high-contrast),
used through generated symbols (`.surface`, `.textTertiary`, `.accent`, …). Names avoid
SwiftUI's own `ShapeStyle` statics: `Divider`, not `separator`; `SelectionFill`, not
`selection`.

Kept exactly as drawn: surfaces, selection, accent fill, accent, label on accent, primary
text, every line and mark at standard contrast, and the dark status colours.

**Corrected** (artboard → standard; increased):

| | dark | light |
|---|---|---|
| secondary | `97979F` → `9F9FA6`; `C7C7CB` | `7B7B7F` → `5F5F63`; `434346` |
| tertiary | `65656C` → `939398`; `B8B8BB` | `ADADB0` → `6C6C6E`; `4F4F51` |

The artboards' six sub-primary greys fold into secondary and tertiary: the sidebar labels
into secondary; chip, section-header, offline-row and queued greys into tertiary. The
order survives the correction: secondary stays louder than tertiary in all four variants.
Secondary dark moved although `97979F` passes on the surfaces, because the sidebar's selected
row puts it on `373548`.

**Creative liberty, marked "derived" in the script:** light values for the dark-only screens:
`CardBorder` `E2E2E6`, status marks `A88243` / `5890AB`, status text `2C7B3D` / `866735` /
`457186`. Every increased variant is derived too. **Left as drawn although it is under 3:1:**
the light online dot `23A844` on the raised sidebar (2.67). It is never the only signal
(the row says "now"; the dot also changes filled vs ring); Increase Contrast lifts it to
`219D40`.

**Checking, two ways, because one of them cannot see everything:**

- `ZhenTests/PaletteContrastTests.swift`: resolves the compiled catalogue through AppKit
  (`NSColor(resource:)` in `performAsCurrentDrawingAppearance`), light and dark: every text
  pair ≥ 4.5 on each surface it lands on, themes differ, and surfaces equal the artboards.
- **A test process cannot build Increase Contrast:** `NSAppearance(named:
  .accessibilityHighContrastDarkAqua)` returns `darkAqua` (measured, macOS 26.6.2). My first
  version of the suite tried, and failed with the standard values (accent 5.06 at
  "increased"). Pinned as a test, so if AppKit changes, the increased tier moves back in.
- `Scripts/check-palette.py <Zhen.app>`: reads the shipped `Assets.car` with
  `xcrun assetutil --info`, so it sees all four variants, and checks every pair at its floor.
  It fails on a missing variant rather than falling back.

**Gate:** tests `** TEST SUCCEEDED **` (8 tests, 3 suites); `check-palette: 142 pairs across 4
appearances, 20 colours — PASS`; `check-tokens` PASS. **Shown failing:** TextTertiary's dark
high-contrast entry set to its standard → 3 pairs under 7 (5.67 / 4.54 / 5.24); Divider
without high-contrast entries → "no darkIncreased variant" ×2; TextTertiary light back to
the artboard's `ADADB0` → the unit test fails at 2.24 / 1.92 / 1.96, the same ratios
section 4 measured. Each restored and `cmp`'d.
