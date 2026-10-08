"""derive-palette.py — the app's colours, from the artboards, made legible where they are not.

Usage: python3 -I Docs/process/evidence/derive-palette.py [--write <Assets.xcassets>]

Rule: keep an artboard value wherever it reads. Where it does not, move it toward white
(dark theme) or black (light theme) by the smallest step that clears its floor on every
background it is drawn on, so the hue the designer chose survives. Increase Contrast
variants come from the same rule with stricter floors: 7:1 for text, 3:1 for lines and
marks. Sampled values are DESIGN-FINDINGS.md section 4; a value marked "derived" had no
artboard (light-only or dark-only screens) and is this file's choice.
"""
import json
import pathlib
import sys

def lum(h):
    f = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = ((h >> 16) & 255) / 255, ((h >> 8) & 255) / 255, (h & 255) / 255
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def ratio(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)

def mix(h, toward, t):
    out = 0
    for s in (16, 8, 0):
        c = (h >> s) & 255
        out |= round(c + (toward - c) * t) << s
    return out

def lift(h, backgrounds, floor, toward):
    """The smallest move toward `toward` (0 or 255) that clears `floor` on every background."""
    for i in range(0, 1001):
        c = mix(h, toward, i / 1000)
        if min(ratio(c, b) for b in backgrounds) >= floor:
            return c
    raise SystemExit(f"cannot reach {floor} for {h:06X}")

# ── Backgrounds, sampled. They do not change under Increase Contrast. ──────────────
SURFACE = (0x1A1A1F, 0xFFFFFF)
RAISED = (0x212127, 0xEEEDF3)
FIELD = (0x2C2C32, 0xF0F0F0)        # dark: 06's text fields; light: 02's chip / field
SELECTION = (0x373548, 0xDBD8ED)
ACCENT_FILL = (0x302E3F, 0xECE9F8)  # 01/02 gateway chip; the winner chip and tile are near it

def bg(*pairs, theme):
    return [p[theme] for p in pairs]

TEXT_BGS = (SURFACE, RAISED, FIELD)
DARK, LIGHT = 0, 1

# name: (dark, light, kind, backgrounds, note)
#   kind "fixed"  — a surface; same in every variant
#   kind "text"   — 4.5 standard, 7 increased, on `backgrounds`
#   kind "line"   — standard as drawn, 3 increased (a hairline at 3:1 is no longer a hairline)
#   kind "mark"   — standard as drawn, 3 increased
COLOURS = {
    "Surface":        (0x1A1A1F, 0xFFFFFF, "fixed", None, "01/02 content"),
    "SurfaceRaised":  (0x212127, 0xEEEDF3, "fixed", None, "01/02 sidebar; 03/05/06 cards"),
    "SurfaceField":   (0x2C2C32, 0xF0F0F0, "fixed", None, "06 text field; 02 chip"),
    "SelectionFill":  (0x373548, 0xDBD8ED, "fixed", None, "01/02 sidebar selection"),
    "AccentFill":     (0x302E3F, 0xECE9F8, "fixed", None, "01/02 gateway chip"),
    "AccentColor":    (0xA495E8, 0x6A58C9, "text", TEXT_BGS + (ACCENT_FILL,), "accent: buttons, links, chip text"),
    "OnAccent":       (0x17141F, 0xFFFFFF, "onAccent", None, "01/04 label on the accent"),
    "TextPrimary":    (0xEBEBF0, 0x1D1D1F, "text", TEXT_BGS + (SELECTION,), "01/02"),
    "TextSecondary":  (0x97979F, 0x7B7B7F, "text", TEXT_BGS + (SELECTION,), "04 prose, 01 IP, sidebar 9A9AA3/75757C folded in"),
    "TextTertiary":   (0x65656C, 0xADADB0, "text", TEXT_BGS, "01 descriptors, headers, MAC; chip, section, offline and queued greys folded in"),
    "Divider":        (0x2A2A2F, 0xE8E8E8, "line", TEXT_BGS, "01/02 row and header rules; 05 progress track"),
    "CardBorder":     (0x313136, 0xE2E2E6, "line", TEXT_BGS, "03 card outline, 01 sidebar divider; light derived"),
    "OfflineRing":    (0x49494F, 0xCECED0, "line", TEXT_BGS, "01/02 offline dot"),
    "SignalWeak":     (0x3A3A3F, 0xE0E0E0, "line", TEXT_BGS, "01/02 unlit meter bars"),
    "StatusOnline":   (0x4CD268, 0x23A844, "mark", TEXT_BGS, "01/02 dot, 05 progress, 06 toggle"),
    "StatusWarning":  (0xD9A856, None, "mark", TEXT_BGS, "04/05; light derived"),
    "StatusInfo":     (0x6DB3D4, None, "mark", TEXT_BGS, "04; light derived"),
    "StatusOnlineText":  (0x4CD268, None, "text", TEXT_BGS, "04 APPEARED; light derived"),
    "StatusWarningText": (0xD9A856, None, "text", TEXT_BGS, "04 PORT OPENED; light derived"),
    "StatusInfoText":    (0x6DB3D4, None, "text", TEXT_BGS, "04 IP CHANGED; light derived"),
}

def derive():
    out = {}
    for name, (dark, light, kind, pairs, note) in COLOURS.items():
        row = {}
        for theme, value in ((DARK, dark), (LIGHT, light)):
            toward = 255 if theme == DARK else 0
            bgs = [p[theme] for p in pairs] if pairs else None
            if value is None:
                # No light artboard. A light mark must clear 3:1 on the light surfaces;
                # light text 4.5. Start from the dark hue.
                floor = 4.5 if kind == "text" else 3.0
                value = lift(dark, bgs, floor, 0)
            if kind == "fixed":
                std = inc = value
            elif kind == "text":
                std = lift(value, bgs, 4.5, toward)
                inc = lift(std, bgs, 7.0, toward)
            elif kind in ("line", "mark"):
                std = value
                inc = lift(value, bgs, 3.0, toward)
            elif kind == "onAccent":
                std = value
                inc = value  # checked against the increased accent below
            row[theme] = (value, std, inc)
        out[name] = row
    # The label on the accent must still read when the accent moves.
    for theme in (DARK, LIGHT):
        accent_inc = out["AccentColor"][theme][2]
        on = out["OnAccent"][theme][1]
        assert ratio(on, accent_inc) >= 7.0, f"onAccent on increased accent: {ratio(on, accent_inc):.2f}"
        assert ratio(on, out["AccentColor"][theme][1]) >= 4.5
    return out

def report(out):
    print(f"{'name':18} {'theme':5} {'artboard':8} {'standard':8} {'increased':9}  worst std / inc")
    for name, row in out.items():
        _, _, kind, pairs, note = COLOURS[name]
        for theme in (DARK, LIGHT):
            a, s, i = row[theme]
            worst = ""
            if pairs:
                bgs = [p[theme] for p in pairs]
                worst = f"{min(ratio(s, b) for b in bgs):5.2f} / {min(ratio(i, b) for b in bgs):5.2f}"
            mark = "" if a == s else "  ← corrected"
            print(f"{name:18} {'dark' if theme == DARK else 'light':5} {a:06X}   {s:06X}   {i:06X}    {worst}{mark}")

def colorset(row):
    def comp(h):
        return {"color-space": "srgb", "components": {
            "alpha": "1.000", "red": f"0x{(h >> 16) & 255:02X}",
            "green": f"0x{(h >> 8) & 255:02X}", "blue": f"0x{h & 255:02X}"}}
    dark_a, dark_s, dark_i = row[DARK]
    light_a, light_s, light_i = row[LIGHT]
    high = {"appearance": "contrast", "value": "high"}
    dark = {"appearance": "luminosity", "value": "dark"}
    return {"colors": [
        {"color": comp(light_s), "idiom": "universal"},
        {"appearances": [dark], "color": comp(dark_s), "idiom": "universal"},
        {"appearances": [high], "color": comp(light_i), "idiom": "universal"},
        {"appearances": [dark, high], "color": comp(dark_i), "idiom": "universal"},
    ], "info": {"author": "xcode", "version": 1}}

if __name__ == "__main__":
    out = derive()
    report(out)
    if len(sys.argv) == 3 and sys.argv[1] == "--write":
        assets = pathlib.Path(sys.argv[2])
        for name, row in out.items():
            d = assets / f"{name}.colorset"
            d.mkdir(exist_ok=True)
            (d / "Contents.json").write_text(json.dumps(colorset(row), indent=2) + "\n")
        print(f"wrote {len(out)} colorsets to {assets}")
