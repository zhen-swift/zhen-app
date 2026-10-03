# Agent prompt — demolish the app, then build its design system

Paste into a fresh agent on the Mac, in the repo root. Resumable: re-paste verbatim and it
resumes from the ledger.

---

You are a senior Swift engineer working in `~/Dev/InfinityCastle`. **zhen** is a network
analysis CLI for macOS; its app is being rebuilt from nothing.

## Read first, in this order

1. **`AGENTS.md`** — the house rules. **This is the authority on HOW.** Every rule in it
   applies. Where it and anything else disagree, it wins.
2. `Docs/plans/REBUILD-plan.md` — what and in what order. You are executing phases 0 and 1.
3. `Design/artboards-2026-10-01.pdf` — the six screens. Open it and look at it.
4. `Design/marks/03-z/` — the mark, layered as plate and glyph.

## Scope: phases 0 and 1 only

Phase 0 demolishes. Phase 1 builds the design system. **You do not build any screen** —
that is phase 2, and it starts only after JC has looked at your previews.

**`zhen/` is out of scope and must not change**, with one exception named in P1.4. If you
find yourself editing a scanner, stop.

## Decisions already made. Do not re-litigate, do not ask.

1. **Bundle identifiers stay `com.jctec.zhen` / `com.jctec.zhen.helper`**, against the
   rules' `dev.jc.<app>`. They are baked into the helper's code-signing requirement, the
   installed launchd plist and `Scripts/verify-identifiers.sh`. Record the deviation in
   one line in `docs/ARCHITECTURE.md` when phase 3 creates it; for now, a comment.
2. **No SwiftData.** The rules require it; `SPEC.md` withdrew it because the app reads the
   same NDJSON history the command line writes — one store, two front ends. Use
   `LogHistoryStore` through the `HistoryStore` protocol in Core. Record as a deviation.
3. **`ZhenScan` survives.** It is a target inside `zhen/`, not an intermediate package, and
   it is the only boundary between a MainActor-by-default app target and `DarwinScanner`.
4. **No intermediate packages.** One Xcode project, one app target, referencing the `zhen`
   package by path. The design system lives in the app target.
5. **Omada is dropped.** The artboards draw it in eighteen places; it is not in the product.
   Subtract it. The sidebar is four items: Devices, Activity, Events, Settings.
6. **No password, ever.** If a step needs root, stop and hand back the command.

---

## Phase 0 — demolish

Branch `v2` off `main` first. Everything below is on `v2`.

**P0.1 — unregister the helper, before anything is deleted.**

`BundleProgram` resolves relative to the bundle root, so deleting the bundle while the
daemon is registered leaves a registered *system* daemon pointing at nothing — and
`SMAppService` unregisters by identity, which lives in the code about to be deleted.
`unregister()` is wired, unit-tested, and **has never actually run**.

```
sudo launchctl print system/com.jctec.zhen.helper     # before
```

Needs root, so **it is JC's command, not yours.** Print it, and the "after" check, and
wait for him to paste both. Do not proceed to P0.3 until he confirms it is gone.

*Gate:* the "after" print says the service is not found, pasted into the ledger.

**P0.2 — extract the findings before the code that holds them dies.**

Three test files hold measured knowledge, not code. Write it into
`Docs/process/DESIGN-FINDINGS.md` so phase 1 can use it:

| From | What |
|---|---|
| `ContrastTests.swift` (313 lines) | the contrast table — every pair and its measured ratio |
| `SymbolTests.swift` | the SF Symbol names, and which are known to exist |
| `KeyboardTests.swift` (238 lines) | tab-stop counts per screen and the traversal order |

*Gate:* every number in that file traceable to a line in a test that still exists at the
time you write it.

**P0.3 — move the documents that describe the dead app.**

`git mv` to `Docs/process/`: `A1-design-system-foundations.md`,
`A2-design-system-components.md`, `A3-design-system-patterns.md`, `03-zhen-app.md`,
`REVIEW-ui-architecture.md`, `plans/RESPONSIVE-plan.md`, `process/APP-CATCHUP.md` (already
there). Update `Docs/README.md`.

**P0.4 — delete.**

`git rm -r zhen-app Scripts/generate-xcodeproj.py Scripts/make-icon.sh`, and remove the
project-regeneration step and the `app-macos` job from `.github/workflows/ci.yml`.
Update `Scripts/check-docs.sh` and `Scripts/check-fixed-sizes.sh` if they name what is gone.

*Gate:* `swift build && swift test` green in `zhen/`; `Scripts/check-docs.sh` passes; CI
config valid; `grep -r zhen-app` returns only `Docs/process/` and this plan.

**P0.5 — hand back to JC for the empty project.**

You cannot create an Xcode project from a terminal, and hand-writing a `.pbxproj` is the
thing phase 0 just deleted a generator to stop doing. So stop here and give JC exact
instructions:

- Xcode → File → New → Project → macOS → App
- Product Name `Zhen`, Organization Identifier `com.jctec`, Interface SwiftUI, Language
  Swift, **Testing System: Swift Testing with XCTest UI Tests**, Storage **None**
- Save into `zhen-app/`
- Add the local package: File → Add Package Dependencies → Add Local → `../zhen`, and link
  `ZhenCore`, `ZhenScan`, `ZhenPrivilege` to the app target
- Confirm the groups are folder-synchronised (Xcode 26 default for new projects)

Then wait. When he says it exists, verify it before building on it: the target's
`SWIFT_DEFAULT_ACTOR_ISOLATION` is `MainActor`, Swift 6 language mode, strict concurrency
complete, deployment target macOS 26, and warnings-as-errors.

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
the artboards; the old `Palette.swift` is in `Docs/process/` as a cross-check, not a source.

`Color(red:green:blue:)` in a view is banned and the check in P1.6 will catch it.

**P1.3 — type.** System font only, Dynamic Type, `@ScaledMetric`. No fixed sizes. Changing
numbers get `.monospacedDigit()` and `.contentTransition(.numericText())` — the artboards
are full of counts and round trips that tick.

**P1.4 — the contrast helper, in Core.** The one place this phase touches `zhen/`. The
rules put it there: foreground on a variable background computed from the WCAG ratio at
runtime, no dependency. `Docs/process/DESIGN-FINDINGS.md` has the table from the old
implementation — which was already caught being right against one background and wrong
against two others, so treat it as a case list to satisfy, not an answer to copy.

*Gate:* the helper's tests reproduce the whole table, and you have shown a deliberately
wrong threshold failing it.

**P1.5 — components.** `Components/` holds what crosses features: `PressButtonStyle`
(spring on press, content controls only — never toolbar or menu controls), status
indicators, chips, the signal-strength meter the artboards draw beside identity.

Each is a `struct ... : View`, never `var someView: some View`. Each has a `#Preview`.

**Before adding one, check it is not a platform control.** The artboards' Devices screen is
a `Table` with sortable columns, and its Settings is a `Form` — neither is a component you
build. The previous app hand-built both, and that single decision is why it is being
deleted. If you are writing a `PreferenceKey` to measure a column, stop.

**P1.6 — the ratchet.** `Scripts/check-tokens.sh`, in the shape of the existing
`Scripts/check-docs.sh` and `verify-identifiers.sh`: fails on a literal spacing, radius,
border width, icon size or colour in any view file, and on `var ...: some View`. Run it.
**Show it failing before you trust it** — add a literal, watch it fail, remove it.

Wire it into `ci.yml`.

*Gate:* passes on your own work. If it does not, the work is wrong, not the check.

---

## Phase 1 done means

1. Four token enums; `grep` finds no literal spacing, radius, border or colour in a view.
2. Every colour is a colorset with light and dark; zero `Color(red:…)`.
3. The contrast helper is in Core, its table is a test, and you have seen that test fail.
4. Every component has a `#Preview`, and you have rendered each in **light, dark and
   increased contrast** and looked at it.
5. `check-tokens.sh` exists, has been shown failing, and is in CI.
6. `swift test` in `zhen/` still green — you changed one file there and nothing else.
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

**When a decision is genuinely JC's:** append to `Docs/process/V6-questions.md` with what it
blocks and what you will do unanswered, then move on. He monitors intermittently and
sleeps. **You may ask, but you may never wait.**

**Ledger:** `Docs/process/REBUILD-progress.md`, liveness line first, read before each step.

**Commits:** one per step, imperative, on `v2`, ending with
`Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Green before every commit.

## What has gone wrong on this project before

- **Verification that agrees with itself.** Six times a check passed while measuring the
  wrong thing — a man-page checker that read a wrapped help line as a subcommand, an
  inventory grep case-sensitive on `width:` that silently missed every range, a
  hand-counted struct offset of 56 where `offsetof` said 48. For every gate, write what
  would have made it fail and show that condition was present. Make it fail on purpose
  first where you can.
- **Scripts written and never run.** Twice. Run yours and paste the output.
- **A design document that outlived its source.** `A1`–`A3` claimed to be measured from six
  artboards that were not in the repository until yesterday. If you derive a number from
  something, say which file and which page.

Begin by reading `AGENTS.md` and the plan, then report which step you are starting and why.
