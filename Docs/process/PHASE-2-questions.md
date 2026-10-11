# Phase 2 — questions for JC

Append-only. Read once, at the end of the run. Each says what it blocks and what was done
instead, so nothing here stopped the run.

## Q1 — Push `phase-2` so CI runs? (stage A)

The branch is committed locally and not pushed: the brief says commit at the end of each
stage and says nothing about pushing, and a push to a public repository is outward-facing.
**Blocks:** the macOS CI job has never run on GitHub, so "CI green" is unverified.
**Instead:** the job's exact command (ad-hoc signing included) was run locally and passed.
`macos-26` as a runner label is an assumption about GitHub's image names; if it does not
exist the job fails at scheduling, which the first run will show.

## Q2 — `Docs/plans/APP-PLAN.md` is untracked (stage A)

It was untracked when the run started. The brief names it as required reading, so it was
read; it was not committed, because a file left out of git may be left out on purpose.
**Blocks:** nothing. **Instead:** left as found.

## Q3 — The Ports segment can never show anything with zhen-core 0.6.0 (stage A, D)

`DerivedEvent.Kind` has appeared, disappeared, ipChanged, renamed, merged — no port
events. The frozen copy keeps a Ports segment. **Instead:** the segment stays (decision 6
froze it) and says "No port events in this window", which is true. Either core derives port
events, or the segment goes — a design call, and the first is a zhen-core change.

## Q4 — Amending the house rules for `Docs/` (stage A)

Decision 8 says "amend the rule, record the deviation". The rule lives in
`zhen-agents/rules/house-rules.md`, and `AGENTS.md` here must stay a byte-identical copy
(zhen-agents/README). Editing either reaches outside `zhen-app` or makes the copy drift —
both are things this run must not do. **Instead:** the deviation is recorded in one line in
`PHASE-2-progress.md` (and in `Docs/ARCHITECTURE.md` at stage H if that stage runs). The
amendment itself is yours, in zhen-agents first.

## Q5 — No `merged` event in the fixture (stage A)

The ledger emits `merged` when reconciliation joins two records, which needs a device that
first appears under one key and later presents a stronger one. Staging that convincingly
in a synthetic history risked teaching the fixture something core does not do.
**Instead:** Activity, the Identity filter and the identity card all handle `merged`; the
fixture just never produces one. A real capture with a merge would make it visible.
