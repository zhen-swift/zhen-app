# Phase 2 — what only JC can verify

Each item: why it is yours, the exact commands, and what a pass looks like. Everything
here was prepared and, where it could be without your identity or privileges, run in this
session; what was run is said. Nothing below has been run with your Developer ID, your
keychain, `sudo`, or a registered helper.

Run them in this order: 0 → 1 → 2 → 3 → 4, then 5 and 6 in any order.

---

## 0 · The UI suite on a quiet desktop

**Why yours:** the suite drives the real keyboard. During this run a second suite
(`xcodebuild -scheme Perch … test`) was driving the same screen and the two typed into
each other's windows (ledger, stage F), so the last UI gates were not run.

    # close other apps that might take focus; no other UI test runs
    cd ~/Dev/InfinityCastle/zhen-app
    xcodebuild -project Zhen.xcodeproj -scheme Zhen -destination 'platform=macOS' test

**Pass:** `** TEST SUCCEEDED **`. Then the three gates still owed a deliberate break —
apply each, run its test, see it fail, revert:

| Gate | Break | Test |
|---|---|---|
| menu bar has every action | delete the `Copy MAC Address` button in `Zhen/App/ZhenCommands.swift` | `-only-testing:ZhenUITests/CommandsUITests` |
| accessibility audit | delete `.accessibilityLabel("Keep events for")` in `SettingsView.swift` | `-only-testing:ZhenUITests/AccessibilityAuditUITests` |
| detail and takeover fit at both sizes | in `ColumnWidths.minimumTable`, drop the `+ Dimension.tableIntercell` terms | `-only-testing:ZhenUITests/WindowSizeUITests` |

## 1 · Developer ID signing and notarisation

**Why yours:** your certificate, your notary account.

One-time, the keychain profile the script uses — **name it `zhen-notary`**:

    xcrun notarytool store-credentials zhen-notary \
      --apple-id <your Apple ID> --team-id S8662L649U
    # it prompts for an app-specific password; it is stored in your keychain, never in the repo

Find the exact identity string:

    security find-identity -v -p codesigning | grep "Developer ID Application"

Build, embed the helper, sign inside-out, notarise, staple:

    Scripts/release.sh "Developer ID Application: <as printed above> (S8662L649U)" zhen-notary

**Pass:** the script ends `release: build/release/Zhen.app — notarised, stapled, accepted by
Gatekeeper`, and on the way prints `signatures, runtime, team, helper identity, daemon
plist — PASS`. Independently:

    spctl --assess --type execute --verbose=4 build/release/Zhen.app
    #  → accepted, source=Notarized Developer ID
    codesign -dv build/release/Zhen.app/Contents/MacOS/zhen-helper 2>&1 | grep -E 'Identifier|TeamIdentifier|flags'
    #  → Identifier=com.jctec.zhen.helper, TeamIdentifier=S8662L649U, flags=…(runtime)

**Run here:** the same script ad hoc (`Scripts/release.sh - --no-notarize`): app built,
helper built from the pinned zhen-core 0.6.0 checkout and embedded, both signed with the
hardened runtime, plist checked — PASS. With the plist's `BundleProgram` broken it stops at
`release: BundleProgram — FAIL`. This is also the route around defect E1: the Xcode build
alone has no helper executable.

## 2 · The helper registers, and Login Items shows "Zhen" with the icon

**Why yours:** registration needs the notarised Developer ID build and an administrator's
approval. Do it on a **clean machine or a fresh macOS user** that has never had Zhen, so an
old registration cannot answer for this one.

1. Copy `build/release/Zhen.app` to `/Applications`, open it.
2. ⌘, → Privileged engine → **Install Helper…**. The state line reads
   "Installed · waiting for your approval" with an amber dot.
3. **Open Login Items…** → allow "Zhen".
4. Back in Settings the state line reads **"Installed · Zhen Scan Engine <version>"** — the
   version is the helper's own answer over its connection, not the registration status.

Check from the OS, not the app:

    launchctl print system/com.jctec.zhen.helper | grep -E 'state|program identifier|parent bundle identifier'
    #  → parent bundle identifier = com.jctec.zhen, program identifier = Contents/MacOS/zhen-helper

**Pass:** System Settings › General › Login Items › "Allow in the Background" lists
**Zhen with the app's icon**, not `com.jctec.zhen.helper`. **Screenshot for the PR:** that
Login Items row, and Zhen's Settings showing the installed state with the version.

## 3 · The helper refuses a mis-signed caller

**Why yours:** it needs the helper from step 2 installed and answering.

Build the harness — it calls the helper through zhen-core's own `HelperClient`, at the
pinned 0.6.0, so it differs from the app only in its signature:

    swift build -c release --package-path Tools/MisSignedCaller
    H=Tools/MisSignedCaller/.build/release/MisSignedCaller

With Zhen's Settings showing "Installed · Zhen Scan Engine <version>" (the positive control):

    $H; echo "exit=$?"                       # ad-hoc signed, no team
    #  → REFUSED: no answer from com.jctec.zhen.helper    exit=0

    # Right team, wrong identity: signed by you, as something that is not the app
    codesign --force --options runtime --identifier com.jctec.zhen.impostor \
      --sign "Developer ID Application: <as in step 1> (S8662L649U)" "$H"
    $H; echo "exit=$?"
    #  → REFUSED …   exit=0

    # The helper's side of it, if you want to see the refusal itself
    log show --last 2m --predicate 'process == "zhen-helper"' --style compact

**Pass:** both runs print REFUSED and exit 0 **while** Settings still shows the version.
**Fail:** `ANSWERED: … the requirement is not enforced`, exit 1. A REFUSED with Settings
not answering proves nothing — the helper was simply not there.

**Run here:** built (ad-hoc, `Identifier=MisSignedCaller`, no team); not run, because no
helper is registered on this Mac and a refusal from nothing is not a refusal.

## 4 · Removing the helper leaves nothing behind

**Why yours:** follows step 2.

1. Zhen ⌘, → **Remove** → confirm. State line: "Not installed."
2. From the OS:

       launchctl print system/com.jctec.zhen.helper
       #  → Could not find service "com.jctec.zhen.helper" in domain for system

3. System Settings › General › Login Items: **no Zhen row** under "Allow in the
   Background" (quit and reopen System Settings — it caches the list).
4. Optional, the background-task database itself (needs `sudo`, so it is yours):

       sudo sfltool dumpbtm | grep -i -B2 -A8 'com.jctec.zhen'
       #  → nothing, or only the app's own entry with no daemon beneath it

**Pass:** all three show nothing.

## 5 · A real scan of 10.10.20.0/24

**Why yours:** the app's first scan asks for the Local Network permission, and the grant is
yours to give or refuse. Use a scratch history so the run does not touch your real one:

    mkdir -p /tmp/zhen-verify && cp ~/Library/Application\ Support/zhen/history.ndjson /tmp/zhen-verify/
    ZHEN_HISTORY=/tmp/zhen-verify/history.ndjson build/release/Zhen.app/Contents/MacOS/Zhen

1. **Scan Now** (⌘R). The first time, macOS asks for Local Network access **for "Zhen"**
   (not for a terminal). Allow.
2. **Pass** — what the fixture says a real run should look like (the fixture *is* this
   network, anonymised, 2026-10-10): the first host on screen within a moment; about a
   dozen devices; the **randomised, unnamed hosts present as normal rows** — "Unidentified
   device", "Randomized MAC · no vendor · responds to ping", a `private` chip, Minimal —
   five of them on 2026-10-10; the Apple TV and the Mac named over Bonjour with WINNER in
   Known by; the gateway with ports 53, 80, 443 after **Scan Ports** (⇧⌘R).
3. **Deny instead** (System Settings › Privacy & Security › Local Network › Zhen off,
   relaunch, scan): **Pass** is "Nothing answered" with **"Local Network access appears to
   be denied"** and an **Open System Settings…** button — a named, actionable degradation,
   not an empty list. The footer dot is amber.

## 6 · No scanning work on the main thread — the instrument trace

**Why yours:** it is a real scan on your LAN under Instruments.

    xcrun xctrace record --template 'Time Profiler' --output /tmp/zhen-scan.trace \
      --launch -- build/release/Zhen.app/Contents/MacOS/Zhen
    # in the app: Scan Now, and a Scan Ports on the gateway; wait for both to finish; quit

    Scripts/check-main-thread-trace.py /tmp/zhen-scan.trace

**Pass:** `every engine sample is off the main thread — PASS`, with a non-zero "with
engine frames" count. **Fail:** `n main-thread samples were scanning — FAIL` with the
offending frames named. The checker also fails a trace with no engine frames at all, so a
recording that missed the scan cannot pass.

**Run here:** the checker on a real Time Profiler export of a command-line process — as
recorded: `the engine never appears … — FAIL`; with an engine frame planted off the main
thread: `PASS`; planted on the main thread: `1 main-thread samples were scanning — FAIL`.
Not run against Zhen: recording it means launching the app's window, which this session
stopped doing (step 0). The compile-time and runtime gates in `ScanPipelineTests` hold the
same line in the test suite.
