# Agent prompt — demolish the app, then build its design system

Paste into a fresh agent on the Mac, in a clone of `zhen-swift/zhen-app`. Resumable:
re-paste verbatim and it resumes from the ledger.

> Rewritten 2026-10-04 for the repository it now runs in. The original was written for the
> monorepo, `InfinityCastle`, before the split; it is in that repository's history.

---

You are a senior Swift engineer working in a clone of
[`zhen-swift/zhen-app`](https://github.com/zhen-swift/zhen-app). **zhen** is a network
analysis CLI for macOS; its app is being rebuilt from nothing. The engine is a separate
repository, [`zhen-swift/zhen-core`](https://github.com/zhen-swift/zhen-core), and this app
depends on it **by version**.

## Read first, in this order

1. **`AGENTS.md`** — the house rules. **This is the authority on HOW.** Every rule in it
   applies. Where it and anything else disagree, it wins.
2. `Docs/plans/REBUILD-plan.md` — what and in what order. You are executing phases 0 and 1.
   Its phase 1 carries a dated amendment about the remote package; it supersedes the
   sentence above it.
3. `Docs/Design/` — the six screens, `01-devices-dark.png` to `06-settings.png`, the
   canonical copy. `Design/artboards-2026-10-01.pdf` is the same six as one export. Open
   them and look at them.
4. `Design/marks/03-z/` — the mark, layered as plate and glyph.

## Scope: phases 0 and 1 only

Phase 0 demolishes. Phase 1 builds the design system. **You do not build any screen** —
that is phase 2, and it starts only after JC has looked at your previews.

**`zhen-core` is a separate repository and out of scope.** You do not edit it, with one
exception: P1.4 opens a pull request against it, which you do not merge. If you find
yourself editing a scanner, stop.

## Decisions already made. Do not re-litigate, do not ask.

1. **Bundle identifiers stay `com.jctec.zhen` / `com.jctec.zhen.helper`**, against the
   rules' `dev.jc.<app>`. They are baked into the helper's code-signing requirement, the
   installed launchd plist and zhen-core's `verify-identifiers.sh`. Record the deviation in
   one line in the architecture document when phase 3 creates it; for now, a comment.
2. **No SwiftData.** The rules require it; zhen-core's `SPEC.md` withdrew it because the
   app reads the same NDJSON history the command line writes — one store, two front ends.
   Use `LogHistoryStore` through the `HistoryStore` protocol in `ZhenCore`. Record as a
   deviation.
3. **`ZhenScan` survives.** It is a target in zhen-core, not an intermediate package, and
   it is the only boundary between a MainActor-by-default app target and `DarwinScanner`.
4. **No intermediate packages.** One Xcode project, one app target, referencing zhen-core
   as a **remote package by version**:

   ```swift
   .package(url: "https://github.com/zhen-swift/zhen-core.git", from: "0.5.0")
   ```

   Never by path. A path dependency is what let a schema change in the engine break the
   app without anything failing. The design system lives in the app target.
5. **Omada is dropped.** The artboards draw it in eighteen places; it is not in the product.
   Subtract it. The sidebar is four items: Devices, Activity, Events, Settings.
6. **Work on `main`.** There is no `v2` branch: this repository's `main` is already the
   starting point, and nothing on it needs protecting from the rebuild.
7. **No password, ever.** If a step needs root, stop and hand back the command.

---

## Phase 0 — demolish

**P0.1 — unregister the helper, before anything is deleted.**

`BundleProgram` resolves relative to the bundle root, so deleting the bundle while the
daemon is registered leaves a registered *system* daemon pointing at nothing — and
`SMAppService` unregisters by identity, which lives in the code about to be deleted.
`unregister()` is wired, unit-tested, and **has never actually run**.

```
sudo launchctl print system/com.jctec.zhen.helper     # before
```

Needs root, so **it is JC's command, not yours.** Print it, and the "after" check, and
wait for him to paste both. Do not proceed to P0.4 until he confirms it is gone.

*Gate:* the "after" print says the service is not found, pasted into the ledger.

**P0.2 — extract the findings before the code that holds them dies.**

Three test files hold measured knowledge, not code. Write it into a new
`DESIGN-FINDINGS.md` in `Docs/process/` so phase 1 can use it:

| From | What |
|---|---|
| `ZhenTests/Design/ContrastTests.swift` (313 lines) | the contrast table — every pair and its measured ratio |
| `ZhenTests/Design/SymbolTests.swift` (62 lines) | the SF Symbol names, and which are known to exist |
| `ZhenTests/Design/KeyboardTests.swift` (238 lines) | tab-stop counts per screen and the traversal order |

Record the commit SHA you read them at. After P0.4 they exist only in history, and
`git show <sha>:<path>` is how phase 1 gets back to them.

*Gate:* every number in that file traceable to a line in a test that still exists at the
time you write it.

**P0.3 — move the documents that describe the dead app.**

`git mv` to `Docs/process/`: `Docs/A1-design-system-foundations.md`,
`Docs/A2-design-system-components.md`, `Docs/A3-design-system-patterns.md`,
`Docs/03-zhen-app.md`, `Docs/REVIEW-ui-architecture.md`, `Docs/plans/RESPONSIVE-plan.md`.
`Docs/process/APP-CATCHUP.md` is already there. Update `Docs/README.md` and the README's
table.

**P0.4 — delete.**

The old app is this repository's root, not a directory in it:

```
git rm -r Zhen ZhenTests Resources Zhen.xcodeproj Scripts/generate-xcodeproj.py Scripts/make-icon.sh
```

There is no CI in this repository yet, so there is no app job to remove. The other scripts
in `Scripts/` — `build-app.sh`, `release.sh`, `verify-helper.sh`, `check-fixed-sizes.sh`,
`count-fixed-sizes.py`, `fixed-sizes-baseline.txt` — name monorepo paths and do not run
here. Do not fix them and do not delete them: list each in the report with what the new
app will need from it (bundling, signing, the helper's proof from the wire, the ratchet).
`check-fixed-sizes.sh` in particular measures views that no longer exist after this step.

*Gate:* `git ls-files Zhen ZhenTests Resources Zhen.xcodeproj` is empty; nothing outside
`Docs/process/` and `Docs/plans/` names a path P0.4 deleted (`git grep` for each, no
limit, and paste what you ran).

**P0.5 — hand back to JC for the empty project.**

You cannot create an Xcode project from a terminal, and hand-writing a `.pbxproj` is the
thing phase 0 just deleted a generator to stop doing. First check the version exists:

```
git ls-remote --tags https://github.com/zhen-swift/zhen-core.git 0.5.0
```

If that prints nothing, `0.5.0` is not tagged yet: stop, and say so — tagging zhen-core is
JC's. Otherwise give JC exact instructions:

- Xcode → File → New → Project → macOS → App
- Product Name `Zhen`, Organization Identifier `com.jctec`, Interface SwiftUI, Language
  Swift, **Testing System: Swift Testing with XCTest UI Tests**, Storage **None**
- Save into this repository's root
- File → Add Package Dependencies → `https://github.com/zhen-swift/zhen-core.git`,
  Dependency Rule *Up to Next Major Version* from `0.5.0`; link `ZhenCore`, `ZhenScan`,
  `ZhenPrivilege` to the app target
- Confirm the groups are folder-synchronised (Xcode 26 default for new projects)

Then wait. When he says it exists, verify it before building on it: the target's
`SWIFT_DEFAULT_ACTOR_ISOLATION` is `MainActor`, Swift 6 language mode, strict concurrency
complete, deployment target macOS 26, warnings-as-errors, and the package reference is
`XCRemoteSwiftPackageReference` with `minimumVersion = 0.5.0` — **not** an
`XCLocalSwiftPackageReference`, which is what the old project had.

---

## Phase 1 — the design system

Nothing in this phase is a screen. If you are laying out the Devices window, you have gone
too far.

**P1.1 — tokens.** `Utilities/` gets `Spacing`, `CornerRadius`, `BorderWidth`, `IconSize`
as enums with the call-site extensions the rules describe, so a view reads
`.padding(.spacing.medium)`. **Four enums. Not a `Metrics` with forty-five constants** —
that is what the last one was and it is the thing being deleted.

A value that is missing is added to the enum. Never inlined.

**P1.2 — colour.** Every colour becomes an asset-catalogue colorset with light and dark
variants, used through generated symbols
(`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`). Sample them from
the artboards. The old palette is a cross-check, not a source: after P0.4 it is
`git show <sha>:Zhen/Design/Tokens/Palette.swift`, at the SHA P0.2 recorded.

`Color(red:green:blue:)` in a view is banned and the check in P1.6 will catch it.

**P1.3 — type.** System font only, Dynamic Type, `@ScaledMetric`. No fixed sizes. Changing
numbers get `.monospacedDigit()` and `.contentTransition(.numericText())` — the artboards
are full of counts and round trips that tick.

**P1.4 — the contrast helper: a pull request against zhen-core.** The rules put it in
Core — `AGENTS.md`'s Core is the `<Name>Core` package, here `ZhenCore` — and Core is now
another repository. So: clone `zhen-swift/zhen-core` beside this one, branch, add the
helper to `ZhenCore` (foreground on a variable background computed from the WCAG ratio at
runtime, no dependency) with its tests, and **open a pull request. Do not merge it, and do
not tag.** The app cannot use the helper until JC merges it and zhen-core tags a release
containing it; then phase 2 raises `from:` to that version. Nothing in phase 1 consumes
the helper, so phase 1 does not wait for it.

`DESIGN-FINDINGS.md` has the table from the old implementation — which was already caught
being right against one background and wrong against two others, so treat it as a case
list to satisfy, not an answer to copy.

*Gate:* the helper's tests reproduce the whole table in zhen-core's `swift test`, you have
shown a deliberately wrong threshold failing them, and the PR's CI shows them passing on
macOS. (zhen-core's Linux job has known failures recorded as AUDIT M2 in its
`Docs/AUDIT.md`; a new Linux failure from the helper is yours, the known ones are not.)

**P1.5 — components.** `Components/` holds what crosses features: `PressButtonStyle`
(spring on press, content controls only — never toolbar or menu controls), status
indicators, chips, the signal-strength meter the artboards draw beside identity.

Each is a `struct ... : View`, never `var someView: some View`. Each has a `#Preview`.

**Before adding one, check it is not a platform control.** The artboards' Devices screen is
a `Table` with sortable columns, and its Settings is a `Form` — neither is a component you
build. The previous app hand-built both, and that single decision is why it is being
deleted. If you are writing a `PreferenceKey` to measure a column, stop.

**P1.6 — the ratchet.** A new `check-tokens.sh` in `Scripts/`, in the shape of zhen-core's
`check-docs.sh` and `verify-identifiers.sh` (read them there): fails on a literal spacing,
radius, border width, icon size or colour in any view file, and on `var ...: some View`.
Run it. **Show it failing before you trust it** — add a literal, watch it fail, remove it.

This repository has no CI. Create `.github/workflows/ci.yml` with this check as its first
job, on push to `main` and on every pull request.

*Gate:* passes on your own work, and the workflow has run green on GitHub. If the check
does not pass, the work is wrong, not the check.

---

## Phase 1 done means

1. Four token enums; `grep` finds no literal spacing, radius, border or colour in a view.
2. Every colour is a colorset with light and dark; zero `Color(red:…)`.
3. The contrast helper is in a zhen-core pull request, its table is a test, you have seen
   that test fail, and its macOS CI is green.
4. Every component has a `#Preview`, and you have rendered each in **light, dark and
   increased contrast** and looked at it.
5. `check-tokens.sh` exists, has been shown failing, and runs in this repository's CI.
6. zhen-core's `main` is untouched — your only change there is the open pull request.
7. No screen exists.

Then write `Docs/process/REBUILD-phase-1-report.md` and **stop**: what you built, the gates
with their measured numbers, what the artboards asked for that a platform control already
provides, and anything in them you could not reconcile with the house rules.

Phase 2 starts when JC has looked at the previews.

---

## How to work

**Build and verify.** The rules are explicit: if you cannot run `xcodebuild`, never claim a
build or test passed — write the code, hand back the exact command, fix from the pasted
output. You *can* run it here, so run it.

**When a gate fails:** revert that step, leave the tree clean, mark it `skipped` in the
ledger with the evidence, move to the next step that does not depend on it. Do not invent a
workaround.

**When a decision is genuinely JC's:** append it to a new `REBUILD-questions.md` in
`Docs/process/` with what it blocks and what you will do unanswered, then move on. He
monitors intermittently and sleeps. **You may ask, but you may never wait.**

**Ledger:** a new `REBUILD-progress.md` in `Docs/process/`, liveness line first, read
before each step.

**Commits:** one per step, imperative, on `main`, ending with
`Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Green before every commit.

## What has gone wrong on this project before

- **Verification that agrees with itself.** Seven times a check passed while measuring the
  wrong thing — a man-page checker that read a wrapped help line as a subcommand, an
  inventory grep case-sensitive on `width:` that silently missed every range, a
  hand-counted struct offset of 56 where `offsetof` said 48, a deep-scan test that passed
  only because the Mac it ran on had its gateway in the ARP cache. For every gate, write
  what would have made it fail and show that condition was present. Make it fail on
  purpose first where you can.
- **An edit that landed somewhere else.** A `perl -0pi` substitution without `/g` meant to
  change one test changed the first match in the file, in a different test, and the
  result was committed. When you mutate a file to prove a check, replace exactly once by
  assertion and look at the diff before running anything.
- **Scripts written and never run.** Twice. Run yours and paste the output.
- **A truncated search reported as an absence.** `find … | head -20` returned twenty
  unrelated files, the six artboards were below the cut, and "they exist nowhere in the
  repository" went into a commit and the plan. They had been in the repository for a
  month. Search without a limit, and say what you ran. If you derive a number from
  something, say which file and which page.

Begin by reading `AGENTS.md` and the plan, then report which step you are starting and why.
