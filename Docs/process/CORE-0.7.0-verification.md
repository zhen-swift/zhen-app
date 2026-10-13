# zhen-core 0.7.0 and the app — what only JC can run

Nothing here was run by the agent. Each step says why it is JC's.

| # | Step | Why it is JC's |
|---|---|---|
| 1 | **The UI suite.** With the screen unlocked and the desktop quiet: `bundle exec fastlane test` in `zhen-app` (until 0.7.0 is on GitHub, with the environment in `CORE-0.7.0-progress.md` › Building against an unpushed core). Expect the unit count from the ledger and every UI test green — the phase-2 harness across both rooms, the detail, the takeover and the scene | The screen locked mid-run; unlocking is a password |
| 2 | **The stale helper registration.** `sfltool dumpbtm` lists `com.jctec.zhen.helper` from `~/Dev/InfinityCastle/build/Zhen.app`, which no longer exists. Remove it from Zhen's Settings (Remove beside the helper controls), or `sudo sfltool resetbtm` (resets every app's background items) | Your Login Items; `sudo` |
| 3 | **Developer ID signing, notarisation, stapling.** `Scripts/release.sh "Developer ID Application: <Name> (S8662L649U)" zhen-notary` — the profile name is `zhen-notary`; the credential stays in your keychain. The helper now comes from the Xcode build, so step 3 of the script only checks it is there | Your identity and notary account |
| 4 | **Register the helper; Login Items shows "Zhen" with the icon;** uninstall leaves nothing | Needs the signed build from step 3 and your approval in System Settings |
| 5 | **The mis-signed caller is refused.** `Tools/MisSignedCaller` is built; run it against the registered helper | Needs step 4 |
| 6 | **The instrument trace for main-actor cleanliness**: a Time Profiler trace of a scan and of a port probe from a device's card, main thread free of socket work | Instruments, interactively |
| 7 | **A live port probe that survives a relaunch, on the home LAN.** `TEST_RUNNER_ZHEN_LIVE_HISTORY=<scratch file> xcodebuild test -only-testing:ZhenUITests/LiveSmokeUITests …`, then relaunch Zhen on the same `ZHEN_HISTORY` and open the device: its ports are there | A real network, and a scratch history so your real one is not touched |
| 8 | **Push and open the two pull requests,** core first. Bodies are in each repo's `Docs/process/PR-BODY.md`. Keep the `0.7.0` tag on `9a2310a` (merge commit), or re-resolve the app afterwards (questions Q1) | Both repositories are public |
| 9 | **Marketing captures** in a quiet session, per `Docs/SCREENSHOTS.md`. The detail's identity card and Activity's Ports segment look different now | Needs a clean desktop |
