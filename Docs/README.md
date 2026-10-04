# Documentation

| | |
|---|---|
| `../AGENTS.md` | The house rules: **how** the app is written. Wins over every document here |
| `plans/REBUILD-plan.md` | **Start here.** Why the app is being demolished and rebuilt, and in what order |
| `Design/` | The six artboards the design was measured from, `01-devices-dark.png` through `06-settings.png`. `../Design/artboards-2026-10-01.pdf` is the same six as one export |
| `03-zhen-app.md` | The old app's brief: bundle identity, screens, isolation, the privileged helper |
| `A1-design-system-foundations.md` | The old design system's foundations — colour, type, metrics, symbols, motion, the accessibility floor — revised after implementation, each revision marked |
| `A2-design-system-components.md` | Its components, their anatomy and states |
| `A3-design-system-patterns.md` | How they assembled into the five screens, and every empty, partial and error state |
| `REVIEW-ui-architecture.md` | An architectural review of the old app, with the outcome of each finding |
| `plans/RESPONSIVE-plan.md` | The old app's responsive and accessibility plan. Its choice of `ScrollView` over `Table` is the one the rebuild plan names as the root cause |
| `process/` | Record, not documentation: the old app's migration list, and the brief for rebuild phases 0 and 1 |

The engine's documentation is in [`zhen-core`](https://github.com/zhen-swift/zhen-core).
These documents were written in the monorepo and name its paths — `zhen/` is now
`zhen-core`, and `zhen-app/` is this repository's root.
