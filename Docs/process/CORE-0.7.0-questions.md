# zhen-app on zhen-core 0.7.0 — questions for JC

Append-only. Each says what it blocks and what was done instead; nothing here stopped the
run. Read once, at the end. zhen-core's own questions are in
`zhen-core/Docs/process/0.7.0-questions.md`.

## Q1 — Merge the core PR with a merge commit, or re-resolve the app

`Package.resolved` pins zhen-core 0.7.0 at `9a2310a`, the commit tagged locally. 0.6.0 was
squash-merged and tagged on the squash commit; doing that again gives 0.7.0 a different hash,
and this pin no longer exists on GitHub. **Blocks:** nothing now. **Instead:** both PR bodies
say so. Either push the tag as it is and merge with a merge commit, or after tagging on
`main` run `xcodebuild -resolvePackageDependencies -project Zhen.xcodeproj -scheme Zhen` here
and amend `Package.resolved`.

## Q2 — The UI suite has not run against 0.7.0

The screen locked during the run, and XCUITest cannot activate an app on a locked session.
**Blocks:** the full `test` lane gate and the behavioural harness. **Instead:** the unit lane
is green, the UI target builds, and the UI tests that read the changed copy
(`DeviceDetailUITests.testPortScanLeavesTheRestOnline`, `LiveSmokeUITests`) were updated for
"Checked …". Verification step 1.

## Q3 — A port probe's time is not kept

History stores ports, not when a probe checked them, so after a relaunch the ports card says
"From an earlier scan that checked ports" instead of "Checked 22 min ago" (A3's caption).
**Blocks:** nothing. **Instead:** a Known rough edge. A timestamp per observation, or per
record's last port check, would be a zhen-core change — `PortObservation` is in `Model/`, so
adding to it is the kind of change the schema rule weighs.

## Q4 — Should Scan Ports be offered on an offline device?

It still is, and a finished probe of one now says the device is offline, so what answers at
its old address may be another device and is neither shown nor saved. **Blocks:** nothing.
**Instead:** kept the button, because a person may know the device is back before a scan
does. Disabling it is one line if you prefer.

## Q5 — Core's record key on `StoredDevice`

`NetworkModel.carryAcrossNewIDs` still matches devices whose row ID changed by MAC, and its
comment names the durable fix: core exposing the ledger's record key on `StoredDevice`. Not
in this brief's nine changes, so not done. A small 0.8.0 item.
