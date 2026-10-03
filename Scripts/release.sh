#!/usr/bin/env bash
#
# release.sh — sign, notarize, staple and verify Zhen.app.
#
# ── Why this is a script and not a wiki page ───────────────────────────────────
#
# A release nobody can reproduce is a release that happens once. Every step below has a
# failure mode whose error message points somewhere other than the cause, and all of
# them were hit getting the first one through; the comments are what those cost.
#
# ── Credentials ───────────────────────────────────────────────────────────────
#
# This script never sees one. `notarytool` reads an App Store Connect key or an
# app-specific password from a keychain profile created ONCE by a person:
#
#     xcrun notarytool store-credentials "zhen-notary" \
#         --apple-id <apple id> --team-id <team> --password <app-specific password>
#
# The profile is referenced by name here and the secret stays in the keychain. Nothing
# in this repository should ever contain one, and no step below prompts for one.
#
# ── Usage ─────────────────────────────────────────────────────────────────────
#
#     ./Scripts/release.sh                 # build, sign, notarize, staple, verify
#     ./Scripts/release.sh --verify-only   # re-run the checks against build/Zhen.app
#
# Needs no privilege. It never uses sudo and has nothing to escalate for.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$REPO/build/Zhen.app"
ZIP="$REPO/build/Zhen.zip"
PROFILE="${ZHEN_NOTARY_PROFILE:-zhen-notary}"
EXPECTED_TEAM="S8662L649U"
VERIFY_ONLY=0
[ "${1:-}" = "--verify-only" ] && VERIFY_ONLY=1

say()  { printf '%s\n' "$*"; }
rule() { printf '%s\n' "────────────────────────────────────────────────────────────"; }
die()  { printf 'release: %s\n' "$*" >&2; exit 1; }

# ── 1. Build ───────────────────────────────────────────────────────────────────
if [ "$VERIFY_ONLY" = 0 ]; then
    say "[1/6] building and signing the bundle"
    "$REPO/Scripts/build-app.sh" >/dev/null || die "build-app.sh failed"
fi
[ -d "$APP" ] || die "no app at $APP"
rule

# ── 2. The signing checks, before anything is uploaded ─────────────────────────
#
# Notarization rejects for signing reasons far more often than for content, and the
# round trip is minutes. Every one of these is cheap and local.
say "[2/6] signing"
check_binary() {
    local path="$1" label="$2" expect_id="$3"
    local info
    info="$(codesign -dvvv "$path" 2>&1)"

    # Hardened runtime. Without it the submission is rejected with "The executable does
    # not have the hardened runtime enabled", which at least names itself honestly.
    printf '%s' "$info" | grep -q "flags=.*runtime" \
        || die "$label has no hardened runtime. Sign with --options runtime."

    # A SECURE timestamp, from Apple's server. `--timestamp=none`, or signing with no
    # network, produces a signature that notarization refuses — and `codesign -dvvv`
    # simply omits the line rather than saying anything is wrong.
    printf '%s' "$info" | grep -q "^Timestamp=" \
        || die "$label has no secure timestamp. Sign with --timestamp, online."

    local team
    team="$(printf '%s' "$info" | sed -n 's/^TeamIdentifier=//p')"
    [ "$team" = "$EXPECTED_TEAM" ] \
        || die "$label is team '$team', expected '$EXPECTED_TEAM'"

    local ident
    ident="$(printf '%s' "$info" | sed -n 's/^Identifier=//p')"
    [ "$ident" = "$expect_id" ] \
        || die "$label identifier is '$ident', expected '$expect_id'"

    say "  $label: hardened runtime, secure timestamp, team $team, id $ident"
}
check_binary "$APP" "app   " "com.jctec.zhen"
check_binary "$APP/Contents/MacOS/zhen-helper" "helper" "com.jctec.zhen.helper"

# Inside-out. A bundle is sealed by its signature, so anything signed AFTER the outer
# bundle invalidates it; --deep --strict is what notices.
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | sed 's/^/  /' \
    || die "the bundle does not verify; it will not notarize"

# Entitlements are an inventory, not a wish list. A daemon carrying one it does not use
# is the kind of thing a reviewer asks about, and this project's whole posture is that
# a person can check what they installed.
for target in "$APP" "$APP/Contents/MacOS/zhen-helper"; do
    ents="$(codesign -d --entitlements - --xml "$target" 2>/dev/null)"
    say "  entitlements on $(basename "$target"): ${ents:-none}"
done
rule

if [ "$VERIFY_ONLY" = 1 ]; then
    say "[verify-only] skipping submission"
else
    # ── 3. Package ─────────────────────────────────────────────────────────────
    #
    # `ditto`, not `zip`. zip does not preserve symlinks or the bundle's structure, and
    # the submission fails with an error that talks about the package rather than about
    # the archiver that mangled it.
    say "[3/6] packaging with ditto"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP" || die "ditto failed"
    say "  $ZIP ($(du -h "$ZIP" | cut -f1))"
    rule

    # ── 4. Submit ──────────────────────────────────────────────────────────────
    say "[4/6] submitting to Apple, by profile name — no credential passes through here"
    if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
        say ""
        say "  No keychain profile named '$PROFILE'."
        say ""
        say "  Create it once, yourself. This script must not see the password:"
        say ""
        say "      xcrun notarytool store-credentials \"$PROFILE\" \\"
        say "          --apple-id <your apple id> --team-id $EXPECTED_TEAM \\"
        say "          --password <app-specific password>"
        say ""
        say "  App-specific passwords come from appleid.apple.com, under Sign-In and"
        say "  Security. Your ordinary Apple ID password will not work."
        exit 1
    fi

    SUBMIT_LOG="$REPO/build/notarize.txt"
    xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait \
        2>&1 | tee "$SUBMIT_LOG" | sed 's/^/  /'
    ID="$(sed -n 's/ *id: *//p' "$SUBMIT_LOG" | head -1)"
    STATUS="$(sed -n 's/ *status: *//p' "$SUBMIT_LOG" | tail -1)"

    if [ "$STATUS" != "Accepted" ]; then
        say ""
        say "  Rejected. The submission log says why; the summary above does not."
        say ""
        [ -n "$ID" ] && xcrun notarytool log "$ID" --keychain-profile "$PROFILE" \
            2>&1 | sed 's/^/  /'
        die "notarization failed"
    fi
    rule

    # ── 5. Staple ──────────────────────────────────────────────────────────────
    #
    # The point of stapling is a machine with no internet. Without a stapled ticket
    # Gatekeeper asks Apple at first launch, which works until it does not.
    say "[5/6] stapling the ticket to the bundle"
    xcrun stapler staple "$APP" 2>&1 | sed 's/^/  /' || die "stapling failed"
    rule
fi

# ── 6. Verify the way a stranger's Mac will ────────────────────────────────────
#
# `spctl` on the local build is a weak test: a bundle built here carries no quarantine
# attribute, so Gatekeeper takes a different path through the assessment than it does
# for anything downloaded. The only honest check writes the attribute a browser would.
say "[6/6] assessing a QUARANTINED copy, which is what a download looks like"
QT="$(mktemp -d /tmp/zhen-qtest.XXXXXX)"
trap 'rm -rf "$QT"' EXIT
cp -R "$APP" "$QT/" || die "could not copy the bundle"
xattr -w com.apple.quarantine "0081;00000000;Safari;" "$QT/Zhen.app"
say "  quarantine attribute: $(xattr -p com.apple.quarantine "$QT/Zhen.app")"

ASSESS="$(spctl -a -vvv -t exec "$QT/Zhen.app" 2>&1)"
printf '%s\n' "$ASSESS" | sed 's/^/  /'

say ""
say "  stapled ticket, on the quarantined copy:"
xcrun stapler validate "$QT/Zhen.app" 2>&1 | sed 's/^/    /'
rule

if printf '%s' "$ASSESS" | grep -q "source=Notarized Developer ID"; then
    say "RESULT: accepted as a Notarized Developer ID. This opens on a Mac that has"
    say "        never seen it, with no network, because the ticket is stapled."
    exit 0
fi

say "RESULT: NOT accepted. A person downloading this would be blocked on first open,"
say "        and would never reach the button that installs the helper."
say "        The assessment above says which of signing, notarization or stapling"
say "        is missing."
exit 1
