#!/usr/bin/env bash
#
# release.sh — a Developer ID build of Zhen with its privileged helper, notarised.
#
# The maintainer's to run: it signs with the project's Developer ID and submits to Apple's
# notary under that account. Nothing here holds a credential — the identity is named, the notary password
# lives in the keychain profile `notarytool store-credentials` made.
#
#   Scripts/release.sh "Developer ID Application: <Name> (S8662L649U)" zhen-notary
#   Scripts/release.sh - --no-notarize          # ad-hoc dry run: build, embed, sign, verify
#
# Steps, each checked before the next:
#   1. Resolve the pinned zhen-core into build/spm (Package.resolved decides the revision).
#   2. Release build of the app, signed with the identity, hardened runtime, timestamped.
#   3. Check the helper is in the bundle. Xcode builds it from zhen-core's `zhen-helper`
#      product and embeds it as Contents/MacOS/zhen-helper (the Embed Helper phase), from
#      the same pinned checkout as everything else. Until zhen-core 0.7.0 declared that
#      product this step built it by hand with SwiftPM — defect E1.
#   4. Sign inside-out: the helper first, as com.jctec.zhen.helper (ZhenPrivilege's
#      HelperIdentity.label) — Xcode signs it on copy under a derived identifier the
#      app's code requirement would refuse — then the app again so its seal covers it.
#   5. Verify: signatures, hardened runtime, team, the daemon plist, the helper in place.
#   6. Notarise, staple, and ask Gatekeeper.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

IDENTITY=${1:?usage: release.sh "<Developer ID Application identity>" <keychain-profile> | release.sh - --no-notarize}
PROFILE=${2:?usage: release.sh "<Developer ID Application identity>" <keychain-profile> | release.sh - --no-notarize}
TEAM=S8662L649U
HELPER_ID=com.jctec.zhen.helper
OUT=build/release
SPM=build/spm
DD=build/dd

say() { printf '\n== %s\n' "$*"; }
fail() { printf 'release: %s — FAIL\n' "$*" >&2; exit 1; }

say "1. resolving the pinned zhen-core"
xcodebuild -resolvePackageDependencies -project Zhen.xcodeproj -scheme Zhen \
  -clonedSourcePackagesDirPath "$SPM" > /dev/null
CORE="$SPM/checkouts/zhen-core"
[ -d "$CORE" ] || fail "no zhen-core checkout at $CORE"
echo "zhen-core at $(git -C "$CORE" rev-parse --short HEAD) ($(git -C "$CORE" describe --tags 2>/dev/null || echo untagged))"

say "2. building the app (Release)"
SIGNING=(CODE_SIGN_IDENTITY="$IDENTITY" CODE_SIGN_STYLE=Manual OTHER_CODE_SIGN_FLAGS=--timestamp)
if [ "$IDENTITY" = - ]; then SIGNING=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=); fi
xcodebuild build -project Zhen.xcodeproj -scheme Zhen -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$DD" -clonedSourcePackagesDirPath "$SPM" \
  "${SIGNING[@]}" > "$DD.log" 2>&1 || { tail -20 "$DD.log"; fail "xcodebuild"; }
rm -rf "$OUT" && mkdir -p "$OUT"
ditto "$DD/Build/Products/Release/Zhen.app" "$OUT/Zhen.app"
APP="$OUT/Zhen.app"

say "3. the helper Xcode embedded"
[ -x "$APP/Contents/MacOS/zhen-helper" ] || fail "no helper at Contents/MacOS/zhen-helper — is the Embed Helper phase there?"

say "4. signing inside-out"
TIMESTAMP=--timestamp
[ "$IDENTITY" = - ] && TIMESTAMP=--timestamp=none
codesign --force --options runtime "$TIMESTAMP" --identifier "$HELPER_ID" --sign "$IDENTITY" \
  "$APP/Contents/MacOS/zhen-helper"
codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" \
  --preserve-metadata=entitlements,requirements,flags "$APP"

say "5. verifying"
codesign --verify --strict --deep --verbose=2 "$APP" 2>&1 | tail -2
# Captured, then matched: under pipefail, `codesign … | grep -q` fails whenever grep
# matches early and codesign takes a SIGPIPE — a check that fails because it passed.
for bin in "$APP" "$APP/Contents/MacOS/zhen-helper"; do
  info=$(codesign -dv "$bin" 2>&1)
  [[ "$info" == *"flags="*"runtime"* ]] || fail "$bin lacks the hardened runtime"
  if [ "$IDENTITY" != - ]; then
    [[ "$info" == *"TeamIdentifier=$TEAM"* ]] || fail "$bin is not signed by team $TEAM"
  fi
done
[ "$(codesign -dv "$APP/Contents/MacOS/zhen-helper" 2>&1 | sed -n 's/^Identifier=//p')" = "$HELPER_ID" ] \
  || fail "the helper is not signed as $HELPER_ID"
PLIST="$APP/Contents/Library/LaunchDaemons/$HELPER_ID.plist"
[ "$(plutil -extract AssociatedBundleIdentifiers.0 raw -o - "$PLIST")" = com.jctec.zhen ] || fail "AssociatedBundleIdentifiers"
[ "$(plutil -extract BundleProgram raw -o - "$PLIST")" = Contents/MacOS/zhen-helper ] || fail "BundleProgram"
entitlements=$(codesign -d --entitlements - "$APP" 2>/dev/null || true)
[[ "$entitlements" == *app-sandbox* ]] && fail "the app is sandboxed"
echo "signatures, runtime, team, helper identity, daemon plist — PASS"

if [ "$PROFILE" = --no-notarize ] || [ "$IDENTITY" = - ]; then
  echo "dry run: not notarised. $APP"
  exit 0
fi

say "6. notarising"
ditto -c -k --keepParent "$APP" "$OUT/Zhen.zip"
xcrun notarytool submit "$OUT/Zhen.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=4 "$APP"
echo "release: $APP — notarised, stapled, accepted by Gatekeeper"
