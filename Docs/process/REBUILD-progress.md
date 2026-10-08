**Liveness:** 2026-10-07 — step 0 (delete all the code) in progress. Next: P0.1 hand-back, P0.2.

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
