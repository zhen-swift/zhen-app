# Changelog

## Unreleased

### Added
- Devices, device detail, live scan and Activity, rebuilt on `Table`, `NavigationSplitView`
  and a `Settings` scene (phase 2).
- A port scan of one device that shows its result on the device and leaves the rest of
  the network as it was.
- Every name each source offered, in Known by; identity history as merges, renames and
  moves; dates on older events; MAC, vendor and known-device matches while scanning;
  stage times.
- Export History… (File, ⇧⌘S, and Settings) as JSON.
- Settings: scan length, the app's version, the history file's size and Show in Finder.
- The app icon, from the design mark.
- `Localizable.xcstrings` with plural forms.
- fastlane lanes, the App Store screenshot pipeline and `Marketing/copy.json`.
- Shortcuts: Scan Network and Count Online Devices, with Siri phrases.
- Every string a symbol key in `Localizable.xcstrings`.
- Spanish, including the Local Network permission prompt.

### Fixed
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
