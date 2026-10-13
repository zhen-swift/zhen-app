#!/usr/bin/env bash
#
# export-screenshots.sh RESULT.xcresult [OUT_DIR] — the marketing captures, by id.
#
# `AppStoreScreenshotUITests` attaches each capture under its Marketing/copy.json id. This
# exports the result bundle's attachments and copies each one to OUT_DIR/<id>.png
# (default fastlane/screenshots/macOS), refusing a capture that is not 2880 × 1800 — the
# 16:10 slot, which only a Retina display produces.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
RESULT=${1:?usage: export-screenshots.sh RESULT.xcresult [OUT_DIR]}
OUT=${2:-fastlane/screenshots/macOS}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$WORK" > /dev/null
mkdir -p "$OUT"
python3 -I - "$WORK" "$OUT" Marketing/copy.json <<'PY'
import json, shutil, subprocess, sys
work, out, copy = sys.argv[1:4]
ids = [s["id"] for s in json.load(open(copy))["screenshots"]]
found = {}
for test in json.load(open(f"{work}/manifest.json")):
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName", "")
        for i in ids:
            if name.startswith(i + "_") or name == i + ".png":
                found[i] = f"{work}/{a['exportedFileName']}"
missing = [i for i in ids if i not in found]
if missing:
    sys.exit(f"export-screenshots: no capture for {missing}")
for i, path in found.items():
    size = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path], capture_output=True, text=True).stdout.split()
    w, h = int(size[-3]), int(size[-1])
    if (w, h) != (2880, 1800):
        sys.exit(f"export-screenshots: {i} is {w} × {h}, not 2880 × 1800 — capture on a Retina display")
    shutil.copy(path, f"{out}/{i}.png")
    print(f"  {i}.png  {w} × {h}")
PY
echo "export-screenshots: $OUT"
