# zhen-app

The macOS app for [Zhen](https://github.com/zhen-swift/zhen-core), a fast, native network
scanner.

**The app is being rebuilt from zero.** The old app's code was deleted on 2026-10-07; it is
readable at `fdb7eaf`, the last commit that had it. Read
[`Docs/plans/REBUILD-plan.md`](Docs/plans/REBUILD-plan.md) for why — measured, rule by rule
— and for what replaces it, in what order.

## What is here

| | |
|---|---|
| `Docs/plans/REBUILD-plan.md` | **Start here.** The decision to demolish and rebuild, the phases, and the open decisions |
| `Design/` | The design source: `artboards-2026-10-01.pdf` (the six screens as one export) and `marks/03-z/`, the layered mark |
| `Docs/Design/` | The same six artboards as PNGs, `01-devices-dark.png` through `06-settings.png` — the canonical copy |
| `Docs/A1`–`A3`, `Docs/03-zhen-app.md`, `Docs/REVIEW-ui-architecture.md` | The old app's design system, brief and review. Record, not instruction |
| `Docs/plans/RESPONSIVE-plan.md`, `Docs/process/APP-CATCHUP.md` | The old app's responsive plan and migration list. Record |
| `Docs/process/prompts/rebuild-phase-0-1.md` | The brief for rebuild phases 0 and 1, rewritten for this repository on 2026-10-04 |

**There is no code here yet.** Phase 0 deleted the old app — `Zhen/`, `ZhenTests/`,
`Resources/`, `Zhen.xcodeproj` and `Scripts/` — so that phase 1 starts from an empty Xcode
project. Progress is in `Docs/process/REBUILD-progress.md`.

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
