# Phase 3 — questions for JC

Append-only. Each says what it blocks and what was done instead, so nothing here stopped
the run.

## Q1 — zhen-core 0.7.0: what the app works around with core frozen (stage 1)

You chose app-only for this run. These are the places where the app works around core
instead of fixing it, each recorded as a bend in `PHASE-3-progress.md`. Together they make
a sensible 0.7.0:

| Core change | What it would remove from the app |
|---|---|
| A port-scan call that is not a run, or presence judged within the scanned subnet | `ProbeOnlyStore`; port results lost at relaunch |
| A port-stage option for new devices only | the relabelled "Check ports on every scan" |
| A `zhen-helper` product | `release.sh` building it separately (phase 2, E1, Q8) |
| Port events (`DerivedEvent.Kind` for ports) | the always-empty Ports segment (phase 2, Q3) |
| A shorter or cached helper check when the registration does not answer | the 3.2 s engine build on a stale registration |

**Blocks:** nothing in this run. **Instead:** each workaround is named in
`Docs/ARCHITECTURE.md`'s Known rough edges (stage 5).

## Q2 — The stale helper registration on this Mac (stage 1)

`sfltool dumpbtm` shows `com.jctec.zhen.helper` registered by
`/Users/jc/Dev/InfinityCastle/build/Zhen.app/`, the monorepo-era build, which no longer
exists. launchd's spawn fails, so every engine build waits out the helper's 3 s timeout.
**Blocks:** the first scan of each launch is 3 s slower on this Mac. **Instead:** the engine
is reused while the helper's state is unchanged. Remove the registration from Zhen's
Settings, using Remove beside the helper controls: the installed app has the same bundle
ID and team. If that fails, `sudo sfltool resetbtm`, which resets every app's background
items.
