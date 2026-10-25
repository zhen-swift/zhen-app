# Changelog

## Unreleased

### Changed
- The App Store and README captures show an invented home network, mostly named and with
  vendors, instead of the anonymised capture of a real one (`-ShowcaseData`,
  `Scripts/make-showcase-fixture.py`). Tests still run on the anonymised capture.

### Fixed
- On a screen narrower than the window's measured minimum, such as a 13-inch Mac at
  "Larger Text", the window fits the screen and the device table scrolls sideways.
  Previously the window's right edge, including Show Details, was off screen.
- Empty states and Settings' toggle descriptions use the palette's secondary text colour.
  On macOS 26 the system's measured 3.9:1, below the 4.5:1 the palette is held to.

## 1.0.0 — 2026-10-17

### Added
- Devices, device detail, live scan and Activity, rebuilt on `Table`, `NavigationSplitView`
  and a `Settings` scene (phase 2).
- A port scan of one device that shows its result on the device and leaves the rest of
  the network as it was.
- Every name each source offered, in Known by; dates on older events; MAC, vendor and known-device matches while scanning;
  stage times.
- Export History… (File, ⇧⌘S, and Settings) as JSON.
- Settings: scan length, the app's version, the history file's size and Show in Finder.
- The app icon, from the design mark.
- `Localizable.xcstrings` with plural forms.
- fastlane lanes, the App Store screenshot pipeline and `Marketing/copy.json`.
- `Scripts/ship.sh`: a release tag to a notarised, stapled disk image on the maintainer's
  Mac, kept in the git-ignored `Releases/`.
- Shortcuts: Scan Network and Count Online Devices, with Siri phrases.
- Every string a symbol key in `Localizable.xcstrings`.
- Spanish, including the Local Network permission prompt.
- Optional notifications when a device Zhen has never seen joins the network.
- Optional menu bar presence: automatic scans and notices continue with the window
  closed.
- On zhen-core 0.7.0: a port scan of one device is kept in history and survives a
  relaunch; Activity's Ports segment shows ports opening and closing; "Deep-scan new
  devices" checks only devices seen for the first time; identity history is one row per
  hardware address, with how it joined and when; an Xcode build embeds the privileged
  helper.

### Changed
- Ready to be public. The build record (phase ledgers, agent prompts, verification lists)
  and the design artboards left the repository; they described a real home network. The
  docs index, README, CONTRIBUTING (set-up, signing without a team, licence), NOTICE and
  SECURITY say what is true now, and issue and pull-request templates are new.
- CI runs with a read-only token, every job has a timeout, and a run on `main` is never
  cancelled by a newer one. The screenshots workflow says so when there are no captures
  instead of uploading empty artifacts. A `docs` job checks that every path the
  documents name exists (`Scripts/check-docs.sh`, zhen-core's check, adapted).

### Fixed
- Scan Now no longer blanks the window when the scan reports a missing source: the
  partial-results banner made the window's minimum height thousands of points tall.
- fastlane refused the whole Fastfile because a lane was named `docs`; it is `docc`.
- CI's token check failed on a computed view in the Ports card; it is a view of its own.
- The Local Network advice no longer tells the app its grant may be under the terminal.
- Scan Ports recorded a run of one address, after which every other device showed as
  offline.
- Installing the helper had no effect until the app was relaunched.
- A scan run in a terminal did not appear in the open window.
- Settings, under test fixtures, wrote the real app's preferences. The settings the app
  read were never the ones it wrote.
- ⌘N opened a second window that ran every scan again.
- Show in Activity kept whatever filter was selected.
- Status that differed only by colour; "1 identity changes"; "Last scan in 0 sec.".
- VoiceOver: combined elements had no role, two lists had no name, and the footer called a
  running scan "Merged".
- White text on the app's accent measured 2.61:1 in dark mode, where macOS draws
  selections and switches; the system controls now use a darker accent.
