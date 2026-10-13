#!/usr/bin/env python3
"""check-palette.py — every colour pair, in all four appearances, from the compiled catalogue.

Usage: Scripts/check-palette.py <path/to/Zhen.app or Assets.car>

The app's unit tests check light and dark by resolving colours through AppKit, but a test
process cannot build an Increase Contrast appearance (PaletteContrastTests pins why). So
this reads what actually ships: the compiled Assets.car, dumped by `xcrun assetutil --info`,
and checks each pair at its floor under aqua, darkAqua and both accessibility appearances.
It fails if a variant is missing, so a colorset without high-contrast entries cannot pass by
falling back to its standard colour.
"""
import json
import pathlib
import subprocess
import sys

APPEARANCES = {
    "light": None,
    "dark": "NSAppearanceNameDarkAqua",
    "lightIncreased": "NSAppearanceNameAccessibilitySystem",
    "darkIncreased": "NSAppearanceNameAccessibilityDarkAqua",
}

TEXT = ["Surface", "SurfaceRaised", "SurfaceField"]
# foreground, backgrounds, standard floor (None: not asserted), increased floor
PAIRS = [
    ("TextPrimary", TEXT + ["SelectionFill"], 4.5, 7),
    ("TextSecondary", TEXT + ["SelectionFill"], 4.5, 7),
    ("TextTertiary", TEXT, 4.5, 7),
    ("AccentColor", TEXT + ["AccentFill"], 4.5, 7),
    ("OnAccent", ["AccentColor"], 4.5, 7),
    ("StatusOnlineText", TEXT, 4.5, 7),
    ("StatusWarningText", TEXT, 4.5, 7),
    ("StatusInfoText", TEXT, 4.5, 7),
    ("Divider", TEXT, None, 3),
    ("CardBorder", TEXT, None, 3),
    ("OfflineRing", TEXT, None, 3),
    ("SignalWeak", TEXT, None, 3),
    ("StatusOnline", TEXT, None, 3),
    ("StatusWarning", TEXT, None, 3),
    ("StatusInfo", TEXT, None, 3),
]


def luminance(rgb):
    f = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(rgb[0]) + 0.7152 * f(rgb[1]) + 0.0722 * f(rgb[2])


def ratio(a, b):
    x, y = luminance(a), luminance(b)
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    path = pathlib.Path(sys.argv[1])
    car = path / "Contents/Resources/Assets.car" if path.suffix == ".app" else path
    if not car.is_file():
        print(f"check-palette: no compiled catalogue at {car}")
        return 2
    dump = json.loads(subprocess.run(["xcrun", "assetutil", "--info", str(car)],
                                     check=True, capture_output=True, text=True).stdout)
    colours = {}
    for entry in dump:
        if entry.get("AssetType") == "Color" or "Color components" in entry:
            comps = entry.get("Color components")
            if comps and entry.get("Colorspace") == "srgb":
                colours[(entry["Name"], entry.get("Appearance"))] = comps[:3]
    names = {name for name, _ in colours}
    if not names:
        print("check-palette: assetutil listed no sRGB colours — nothing was checked")
        return 2

    failures, checked = [], 0
    for look, appearance in APPEARANCES.items():
        increased = look.endswith("Increased")
        for fg, bgs, standard, inc in PAIRS:
            floor = inc if increased else standard
            if floor is None:
                continue
            for bg in [fg] + bgs:
                if (bg, appearance) not in colours:
                    failures.append(f"{bg}: no {look} variant in the catalogue")
            if any((n, appearance) not in colours for n in [fg] + bgs):
                continue
            for bg in bgs:
                r = ratio(colours[(fg, appearance)], colours[(bg, appearance)])
                checked += 1
                if r < floor:
                    failures.append(f"{fg} on {bg}, {look}: {r:.2f} < {floor}")
    for f in sorted(set(failures)):
        print(f)
    if failures:
        print(f"check-palette: {len(set(failures))} failures in {checked} pairs — FAIL")
        return 1
    print(f"check-palette: {checked} pairs across 4 appearances, {len(names)} colours — PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
