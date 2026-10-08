**Liveness:** 2026-10-07 — P0.4 gate passed; P0.1 waiting on JC; P0.5 hand-back next.

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

## P0.1 — unregister the helper · waiting on JC

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
