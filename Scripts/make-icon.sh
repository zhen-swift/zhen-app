#!/bin/bash
# make-icon.sh — build the app icon from vector source.
#
# The SVGs in Design/icon are the source of truth. Every size below is a fresh
# render of that vector, never a downsample of a larger PNG: a resized bitmap of
# a resized bitmap is how an icon ends up soft at exactly the size people see it
# most, which for a Finder list and the Login Items row is 16 and 20 points.
#
# The .icns is a build product. It is not committed; this script is.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/Design/icon/icon-colour.svg}"
OUT="${2:-$ROOT/build/Zhen.icns}"
SET="$(mktemp -d)/Zhen.iconset"
mkdir -p "$SET" "$(dirname "$OUT")"

# A renderer that takes a vector and a target size. rsvg-convert and resvg both
# do; sips does NOT read SVG, which is the trap on macOS — it will fail in a way
# that sounds like a file problem rather than a format one.
if command -v rsvg-convert >/dev/null; then
    render() { rsvg-convert -w "$1" -h "$1" "$SRC" -o "$2"; }
elif command -v resvg >/dev/null; then
    render() { resvg -w "$1" -h "$1" "$SRC" "$2"; }
else
    echo "No SVG renderer found. brew install librsvg (rsvg-convert) or resvg." >&2
    echo "Do not substitute sips: it cannot read SVG." >&2
    exit 1
fi

# The sizes iconutil expects, each rendered from the vector at its own scale.
for s in 16 32 64 128 256 512 1024; do
    render "$s" "$SET/icon_${s}x${s}.png"
done
# Retina variants are the doubled pixel sizes under the halved logical names.
for pair in "32 16" "64 32" "256 128" "512 256" "1024 512"; do
    set -- $pair
    cp "$SET/icon_${1}x${1}.png" "$SET/icon_${2}x${2}@2x.png"
done

iconutil -c icns "$SET" -o "$OUT"
echo "wrote $OUT"
echo
echo "Now look at it at 16. Not at 1024."
