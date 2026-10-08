# Rebuild — questions for JC

Append-only. Each says what it blocks and what happens unanswered.

## Q1 — `Docs/RULES.md` does not exist (2026-10-07)

The session prompt names `Docs/RULES.md` as "the product's decisions" and
`Docs/plans/PHASE-0-START.md` as superseding phase 0's opening. Neither exists in this
repository, zhen-core, or the archived monorepo (searches in `REBUILD-progress.md`).
`PHASE-0-START.md` was answered in conversation: delete all the code first.

**Blocks:** nothing outright. **Unanswered:** the brief's *Decisions already made* list
stands in for `RULES.md`. If `RULES.md` turns up and disagrees, it wins over the brief and
loses to `AGENTS.md`, and anything built against the brief is revisited.

## Q2 — Settings: a sidebar row, a scene, or both? (2026-10-07)

The brief's decision 5 says the sidebar is four items: Devices, Activity, Events, Settings.
`AGENTS.md` (macOS table) says Settings is a `Settings { }` scene opened with ⌘,, not a
screen inside navigation, and `AGENTS.md` wins disagreements.

**Blocks:** phase 2's sidebar and its ⌘-number shortcuts. Nothing in phases 0–1.
**Unanswered:** phase 2 builds Settings as a `Settings { }` scene (⌘,), and the sidebar row,
if kept, opens it with `openSettings`, so the sidebar still shows four items.
