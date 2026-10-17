#!/usr/bin/env bash
#
# ship.sh — one release on this Mac: from a tag to a notarised, stapled disk image.
#
# The maintainer's to run, like release.sh: it signs with the Developer ID in the login
# keychain and submits to Apple's notary. No CI job signs anything.
#
#   git tag -a v1.0 -m "Zhen 1.0" && Scripts/ship.sh v1.0
#   Scripts/ship.sh v1.0 --dry-run      # ad hoc, not notarised; the tag checks only warn
#
# Settings and results live in Releases/, which git ignores:
#   Releases/release.env    IDENTITY and NOTARY_PROFILE — copy Scripts/release.env.example
#   Releases/<version>/     Zhen-<version>.dmg, its SHA-256, and notes.md, the CHANGELOG
#                           section, ready for a GitHub release
# Neither holds a credential: IDENTITY names a certificate in the keychain, and the notary
# password lives in the keychain profile `notarytool store-credentials` made.
#
# Steps, each checked before the next:
#   1. Settings: the identity is in the keychain, the notary profile answers.
#   2. The tag: it names HEAD, the tree is clean, the app's MARKETING_VERSION and a
#      CHANGELOG heading both say its version.
#   3. release.sh: build, embed the helper, sign, verify, notarise and staple the app.
#   4. dmg.sh: the app and an Applications link in a signed image.
#   5. Notarise and staple the image, and ask Gatekeeper.
#   6. The checksum and the release notes beside the image.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TAG=${1:?usage: ship.sh v<version> [--dry-run]}
DRY=false
case "${2:-}" in
  --dry-run) DRY=true ;;
  "") ;;
  *) echo "usage: ship.sh v<version> [--dry-run]" >&2; exit 2 ;;
esac
[[ "$TAG" == v?* ]] || { echo "ship: the tag is v<version>, e.g. v1.0 — got $TAG" >&2; exit 2; }
VERSION=${TAG#v}
ENV=Releases/release.env
OUT=Releases/$VERSION
$DRY && OUT=Releases/$VERSION-dry-run
APP=build/release/Zhen.app
DMG=$OUT/Zhen-$VERSION.dmg

say() { printf '\n== %s\n' "$*"; }
fail() { printf 'ship: %s — FAIL\n' "$*" >&2; exit 1; }
# A tag check that fails a release and only warns a dry run.
check() { if $DRY; then printf 'ship: warning: %s\n' "$*" >&2; else fail "$*"; fi; }

say "1. settings"
if $DRY; then
  IDENTITY=- NOTARY_PROFILE=--no-notarize
  echo "dry run: signed ad hoc, not notarised"
else
  [ -f "$ENV" ] || fail "no $ENV — cp Scripts/release.env.example $ENV and fill it in"
  # shellcheck source=/dev/null
  source "$ENV"
  : "${IDENTITY:?$ENV sets no IDENTITY}" "${NOTARY_PROFILE:?$ENV sets no NOTARY_PROFILE}"
  [[ "$(security find-identity -v -p codesigning)" == *"\"$IDENTITY\""* ]] \
    || fail "\"$IDENTITY\" is not a valid signing identity in the keychain"
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" > /dev/null \
    || fail "notary profile $NOTARY_PROFILE — xcrun notarytool store-credentials $NOTARY_PROFILE --team-id S8662L649U"
  echo "$IDENTITY, notary profile $NOTARY_PROFILE"
fi

say "2. the tag"
[ -z "$(git status --porcelain)" ] || check "the working tree has changes; a release is built from the tag alone"
if git rev-parse -q --verify "refs/tags/$TAG" > /dev/null; then
  [ "$(git rev-parse "$TAG^{commit}")" = "$(git rev-parse HEAD)" ] || check "$TAG is not HEAD — git switch --detach $TAG"
else
  check "no tag $TAG — git tag -a $TAG -m \"Zhen $VERSION\""
fi
MARKETING=$(xcodebuild -showBuildSettings -project Zhen.xcodeproj -scheme Zhen -configuration Release \
  -clonedSourcePackagesDirPath build/spm 2>/dev/null | sed -n 's/^ *MARKETING_VERSION = //p' | head -1)
[ "$MARKETING" = "$VERSION" ] || check "MARKETING_VERSION is $MARKETING, the tag says $VERSION"
grep -qE "^## \[?${VERSION//./\\.}\]?( |$)" CHANGELOG.md || check "CHANGELOG.md has no \"## $VERSION\" section"
echo "$TAG at $(git rev-parse --short HEAD), MARKETING_VERSION $MARKETING"

say "3. the app (release.sh)"
Scripts/release.sh "$IDENTITY" "$NOTARY_PROFILE"
BUILT=$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")
[ "$BUILT" = "$VERSION" ] || check "the built app says $BUILT, the tag says $VERSION"

say "4. the disk image"
mkdir -p "$OUT"
Scripts/dmg.sh "$APP" "$DMG" "$IDENTITY"

if ! $DRY; then
  say "5. notarising the image"
  result=$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)
  status=$(plutil -extract status raw -o - - <<< "$result" 2>/dev/null || echo unknown)
  if [ "$status" != Accepted ]; then
    id=$(plutil -extract id raw -o - - <<< "$result" 2>/dev/null || echo "<id>")
    fail "notary status $status — xcrun notarytool log $id --keychain-profile $NOTARY_PROFILE"
  fi
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi

say "6. checksum and notes"
(cd "$OUT" && shasum -a 256 "Zhen-$VERSION.dmg" > "Zhen-$VERSION.dmg.sha256")
# The CHANGELOG section under "## <version>", without its heading.
awk -v v="$VERSION" '
  /^## / { if (on) exit; h = $2; gsub(/[][]/, "", h); on = (h == v); next }
  on' CHANGELOG.md > "$OUT/notes.md"
[ -s "$OUT/notes.md" ] || check "no release notes for $VERSION in CHANGELOG.md"

if $DRY; then
  echo
  echo "ship: dry run — $DMG, ad hoc, not notarised. Not for anyone else's Mac."
else
  echo
  echo "ship: $DMG — notarised, stapled, accepted by Gatekeeper"
  echo "To publish it (a draft until you release it on GitHub):"
  echo "  git push origin $TAG"
  echo "  gh release create $TAG \"$DMG\" \"$DMG.sha256\" --draft --title \"Zhen $VERSION\" --notes-file \"$OUT/notes.md\""
fi
