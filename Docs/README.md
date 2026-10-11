# Documentation

| | |
|---|---|
| `../AGENTS.md` | The house rules: **how** the app is written. Wins over every document here |
| `plans/REBUILD-plan.md` | **Start here.** Why the app is being demolished and rebuilt, and in what order |
| `Design/` | The six artboards the design was measured from, `01-devices-dark.png` through `06-settings.png`. `../Design/artboards-2026-10-01.pdf` is the same six as one export |
| `process/PHASE-2-progress.md` | **Phase 2's ledger:** every stage, every gate with what it was shown failing on, every design bend with its measurement. `PHASE-2-questions.md` beside it is JC's to answer; `PHASE-2-verification.md` is JC's to run |
| `process/REBUILD-progress.md` | The rebuild's ledger: every step, its gate and its evidence. `REBUILD-questions.md` beside it holds what is JC's to decide |
| `process/REBUILD-phase-1-report.md` | **Phases 0 and 1, summarised:** what was built, the gates with their numbers, what platform controls cover, and what the artboards ask that the house rules do not allow |
| `process/DESIGN-FINDINGS.md` | What the old app's tests measured — contrast, symbols, keyboard — extracted before they were deleted. Phase 1's case list |
| `process/` | Record, not documentation. Also: the old app's brief (`03-zhen-app.md`), design system (`A1`–`A3`), review (`REVIEW-ui-architecture.md`), responsive plan (`RESPONSIVE-plan.md`, whose choice of `ScrollView` over `Table` the rebuild plan names as the root cause) and migration list (`APP-CATCHUP.md`); and the brief for rebuild phases 0 and 1 (`prompts/rebuild-phase-0-1.md`) |

The engine's documentation is in [`zhen-core`](https://github.com/zhen-swift/zhen-core).
These documents were written in the monorepo and name its paths — `zhen/` is now
`zhen-core`, and `zhen-app/` is this repository's root.
