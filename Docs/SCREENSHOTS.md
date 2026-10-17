# Screenshots and artwork

Every App Store image and README picture is generated. Nothing is cropped by hand.

```
AppStoreScreenshotUITests          -ShowcaseData, -WindowSize 1440x900, appearance pinned
  capture "<id>"                   the main window, 2880 × 1800 on a Retina display
        │
        ▼  Scripts/export-screenshots.sh
fastlane/screenshots/macOS/<id>.png
        │
        ▼  swift Scripts/generate_appstore_assets.swift      (reads Marketing/copy.json)
        ├──► AppStoreAssets/macOS/<id>.png, <id>-captioned.png
        └──► Docs/assets/hero.png, feature-NN.png, app-icon.png
```

| Command | Does |
|---|---|
| `bundle exec fastlane screenshots` | capture, export, render |
| `bundle exec fastlane marketing` | render only, from `fastlane/screenshots/macOS/` or the committed `AppStoreSimulatorCaptures/macOS/` |

## What the captures show

`-ShowcaseData` loads `Zhen/Fixtures/showcase-network.json`, an invented home network:
sixteen devices, most named by Bonjour, UPnP or NetBIOS and carrying a vendor, and a few
honestly unnamed. It was never scanned. `Scripts/make-showcase-fixture.py` writes it from a
table and computes each device's identification by zhen-core's rules; `--check` fails if
the committed file is not its output, and `ShowcaseFixtureTests` checks the rules against
core itself. Every MAC is documentation-range or synthetic, and every name is generic.

The anonymised home network the tests use is not shown in any capture: it is a real
network's shape, and most of its devices are unnamed. `05-unidentified` is the invented
network with every name, vendor and model stripped (`-Fixture unidentified`).
To change what the captures show, edit the table and regenerate:

```
Scripts/make-showcase-fixture.py > Zhen/Fixtures/showcase-network.json
```

## The contract

- `Marketing/copy.json` lists each screenshot's `id`, title, subtitle and palette.
  `AppStoreScreenshotUITests` attaches a capture under each id. A new screenshot is a
  new capture **and** a new entry.
- Captures must be exactly 2880 × 1800. Only a Retina display produces that. The export
  script and the renderer both refuse anything else; the renderer never upscales.
- A missing capture makes the renderer print every path it tried and exit 1.

## Taking captures

An XCUITest window screenshot is the screen's pixels, so whatever is drawn over the window
is in the capture. Before `fastlane screenshots`:

1. Turn on Do Not Disturb, so no notification banner lands on the window.
2. Hide the Dock (System Settings › Desktop & Dock › Automatically hide), or use a display
   taller than 1000 points. A 1440 × 900 window does not fit above the Dock on a
   1512 × 949 display.
3. Close or hide other apps' windows.

Then check every capture, and copy them to `AppStoreSimulatorCaptures/macOS/` to commit.
`AppStoreAssets/` and `Docs/assets/` are generated: regenerate them, never edit them.

**Status (2026-10-11):** the pipeline runs end to end. No captures are committed yet. The
first captures, taken on a desktop in use, showed the Dock and a notification banner
(phase 3, Q5).
