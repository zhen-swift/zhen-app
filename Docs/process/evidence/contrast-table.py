"""Recompute ContrastTests' table from Palette.swift at a commit.

Usage: python3 -I contrast_table.py <repo> <sha>

Mirrors ZhenTests/Design/ContrastTests.swift at that commit:
  components()  lines 59-64  (Color.Resolved red/green/blue, Float -> Double)
  luminance()   lines 67-72
  ratio()       lines 75-83
  and PaletteColor.resolved(scheme:contrast:) in Palette.swift for the tier lookup.
"""
import re
import struct
import subprocess
import sys

repo, sha = sys.argv[1], sys.argv[2]
src = subprocess.run(
    ["git", "-C", repo, "show", f"{sha}:Zhen/Design/Tokens/Palette.swift"],
    check=True, capture_output=True, text=True,
).stdout
lines = src.splitlines()

# token(name) -> {dark, light, darkIncreased, lightIncreased}, plus the line it is declared on.
tokens = {}
decl = re.compile(r"public static let (\w+) = token\(")
i = 0
while i < len(lines):
    m = decl.search(lines[i])
    if m:
        start = i
        body = lines[i]
        while body.count("(") > body.count(")"):
            i += 1
            body += lines[i]
        args = dict(re.findall(r"(\w+): (0x[0-9A-Fa-f]{6})", body))
        dark, light = int(args["dark"], 16), int(args["light"], 16)
        tokens[m.group(1)] = {
            "dark": dark, "light": light,
            "darkIncreased": int(args.get("darkIncreased", hex(dark)), 16),
            "lightIncreased": int(args.get("lightIncreased", hex(light)), 16),
            "line": start + 1,
        }
    i += 1


def f32(x):
    return struct.unpack("f", struct.pack("f", x))[0]


def components(name, scheme, contrast):
    t = tokens[name]
    key = {("dark", "standard"): "dark", ("dark", "increased"): "darkIncreased",
           ("light", "standard"): "light", ("light", "increased"): "lightIncreased"}[(scheme, contrast)]
    p = t[key]
    return tuple(f32(f32(float(c)) / f32(255.0)) for c in ((p >> 16) & 0xFF, (p >> 8) & 0xFF, p & 0xFF))


def luminance(c):
    def ch(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])


def ratio(fg, bg, scheme, contrast):
    a = luminance(components(fg, scheme, contrast))
    b = luminance(components(bg, scheme, contrast))
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)


surfaces = ["surface", "surfaceRaised", "surfaceField"]
text = ["textPrimary", "textSecondary", "textTertiary"]
status = ["onlineText", "warningText", "infoText"]
nontext = ["separator", "offlineRing"]
FLOOR = {"AA": 4.5, "AAA": 7.0, "nonText": 3.0}

if "--tokens" in sys.argv:
    for n, t in tokens.items():
        print(f"{n:15} L{t['line']:<4} dark {t['dark']:06X}  light {t['light']:06X}  "
              f"darkInc {t['darkIncreased']:06X}  lightInc {t['lightIncreased']:06X}")
    sys.exit(0)

floor_aa = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] != "--tokens" else FLOOR["AA"]
fails = []
for contrast in ("standard", "increased"):
    for scheme in ("dark", "light"):
        print(f"\n{scheme} · {contrast}")
        print("  token             surface   raised    field   floor")
        for name in text + ["accent"] + status + nontext:
            cells = [ratio(name, s, scheme, contrast) for s in surfaces]
            if name in nontext:
                floor = FLOOR["nonText"] if contrast == "increased" else None
            else:
                floor = floor_aa if contrast == "standard" else FLOOR["AAA"]
            marks = ""
            for s, r in zip(surfaces, cells):
                if floor is not None and r < floor:
                    fails.append((name, s, scheme, contrast, r, floor))
                    marks += " ✗"
            print(f"  {name:16}" + "".join(f"{r:9.2f}" for r in cells)
                  + f"   {floor if floor else '—'}{marks}")
        oa = ratio("onAccent", "accent", scheme, contrast)
        floor = floor_aa if contrast == "standard" else FLOOR["AAA"]
        if oa < floor:
            fails.append(("onAccent", "accent", scheme, contrast, oa, floor))
        print(f"  {'onAccent/accent':16}{oa:9.2f}            {floor}{' ✗' if oa < floor else ''}")

print(f"\npairs below floor: {len(fails)}")
for f in fails:
    print("  ", f)
