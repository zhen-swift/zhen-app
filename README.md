# zhen-app

The macOS app for [Zhen](https://github.com/zhen-swift/zhen-core), a fast, native network
scanner.

**The app is being rebuilt.** The code in this repository is the old app, and it is about
to be deleted. Read [`Docs/plans/REBUILD-plan.md`](Docs/plans/REBUILD-plan.md) for why —
measured, rule by rule — and for what replaces it, in what order.

## What is here

| | |
|---|---|
| `Docs/plans/REBUILD-plan.md` | **Start here.** The decision to demolish and rebuild, the phases, and the open decisions |
| `Design/` | The design source: `artboards-2026-10-01.pdf` (the six screens as one export) and `marks/03-z/`, the layered mark |
| `Docs/Design/` | The same six artboards as PNGs, `01-devices-dark.png` through `06-settings.png` — the canonical copy |
| `Docs/A1`–`A3`, `Docs/03-zhen-app.md`, `Docs/REVIEW-ui-architecture.md` | The old app's design system, brief and review. Record, not instruction |
| `Docs/plans/RESPONSIVE-plan.md`, `Docs/process/APP-CATCHUP.md` | The old app's responsive plan and migration list. Record |
| `Docs/process/prompts/rebuild-phase-0-1.md` | The brief for rebuild phases 0 and 1, rewritten for this repository on 2026-10-04 |
| `Zhen/`, `ZhenTests/`, `Resources/`, `Zhen.xcodeproj` | The old app. Phase 0 deletes it |
| `Scripts/` | How the old app was built, signed and checked. They name monorepo paths (`zhen-app/`, `zhen/`) and **do not run here**; they are kept as the record until phase 0 decides which survive |

**The old app does not build in this repository.** Its project references the package at
`../zhen`, which was a sibling directory in the monorepo this was split from. That is not
fixed, because the project is the first thing the rebuild deletes.

**`AGENTS.md` is the house rules** — the authority on how Swift and SwiftUI are written
here. Where it and the rebuild plan disagree, `AGENTS.md` wins.

## The engine

The rebuilt app is an Xcode project that depends on the engine by version, never by path:

```swift
.package(url: "https://github.com/zhen-swift/zhen-core.git", from: "0.5.0")
```

A path dependency is what let a schema change in the engine break the app without anything
failing. A version is a promise the engine has to keep on purpose.

## History

The app moved to its own repository on 2026-10-03. Its history here begins on 2026-09-26,
when it was given its own directory and project in the monorepo; everything before that is
in the archived monorepo this repository was split from.

## Licence

Apache License 2.0. See `LICENSE` and `NOTICE`.
