#!/usr/bin/env bash
#
# dmg.sh — Zhen.app in a disk image a person drags to Applications, signed.
#
# ship.sh calls it after release.sh; it also runs on its own for a quick look.
#
#   Scripts/dmg.sh build/release/Zhen.app Releases/1.0/Zhen-1.0.dmg "Developer ID Application: <Name> (S8662L649U)"
#   Scripts/dmg.sh build/release/Zhen.app build/Zhen.dmg -        # ad hoc
#
# The image is read-only and compressed (ULFO), and holds the app and a link to
# /Applications. It is signed so Gatekeeper checks who made it before it mounts;
# notarising and stapling it are ship.sh's steps, since they need the notary profile.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP=${1:?usage: dmg.sh <Zhen.app> <out.dmg> <identity | ->}
DMG=${2:?usage: dmg.sh <Zhen.app> <out.dmg> <identity | ->}
IDENTITY=${3:?usage: dmg.sh <Zhen.app> <out.dmg> <identity | ->}

fail() { printf 'dmg: %s — FAIL\n' "$*" >&2; exit 1; }

[ -d "$APP" ] || fail "no app at $APP"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Zhen.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"
hdiutil create -quiet -volname Zhen -srcfolder "$STAGE" -format ULFO "$DMG"

TIMESTAMP=--timestamp
[ "$IDENTITY" = - ] && TIMESTAMP=--timestamp=none
codesign --force "$TIMESTAMP" --sign "$IDENTITY" "$DMG"

hdiutil verify -quiet "$DMG" || fail "hdiutil verify"
codesign --verify --strict "$DMG" || fail "the image's signature"
echo "dmg: $DMG — signed, verified"
