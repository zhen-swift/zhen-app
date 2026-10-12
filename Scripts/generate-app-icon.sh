#!/usr/bin/env bash
#
# generate-app-icon.sh — the app icon set, from the design source.
#
# Design/marks/03-z/png/icon-colour-1024.png is the mark, drawn on Apple's macOS icon grid
# (the plate inset from the canvas). Every size the asset catalogue asks for is resized from
# it, so the icon has one source and cannot drift from it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
SRC=Design/marks/03-z/png/icon-colour-1024.png
SET=Zhen/Assets.xcassets/AppIcon.appiconset
for px in 16 32 64 128 256 512 1024; do
  sips -z "$px" "$px" "$SRC" --out "$SET/icon-$px.png" > /dev/null
done
echo "generate-app-icon: $SET from $SRC"
