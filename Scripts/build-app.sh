#!/usr/bin/env bash
#
# build-app.sh — assemble Zhen.app around the compiled binary.
#
# The app's sources live in `zhen-app/Zhen`, compiled by an Xcode target, because a
# design system is edited with a live canvas and a SwiftPM target makes that awkward.
# Xcode produces a `.app` of its own; this script does not use it. It takes the compiled
# executable out and assembles the bundle by hand, because three things in the layout
# below are not Xcode's to decide: the Info.plist is generated from the scanner's own
# Bonjour vocabulary, the daemon plist has to be exactly where SMAppService looks, and
# the signing is inside-out with a team check that fails loudly at build time instead of
# quietly at a user's first launch.
#
# The bundle identity is the whole point: the Local Network permission attaches to a
# bundle, and a bare executable's grant attaches to whatever terminal launched it and
# never appears under the tool's own name in System Settings.
#
# The Info.plist is GENERATED, not copied. `NSBonjourServices` must list every service
# type the discovery layer browses, and a type that is browsed but undeclared returns
# nothing, silently, with no error anywhere — so the array comes from
# `BonjourVocabulary.browsedTypes` by asking the binary for it. Two lists that must agree
# are one list.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The helper is a SwiftPM executable in the tool's package; the app is an Xcode target.
PACKAGE="$REPO/zhen"
PROJECT="$REPO/zhen-app/Zhen.xcodeproj"
CONFIG="${1:-release}"
# xcodebuild wants Release/Debug; this script has always taken release/debug.
XCCONFIG="$(printf '%s' "${CONFIG:0:1}" | tr '[:lower:]' '[:upper:]')${CONFIG:1}"
DERIVED="$REPO/build/DerivedData"
APP_NAME="Zhen"
# Declared once here and once in ZhenPrivilege's HelperIdentity. A test pins them
# together, because a label that disagrees between the plist and the Mach service name
# fails as error 108 and names the wrong thing.
APP_BUNDLE_ID="com.jctec.zhen"
HELPER_LABEL="com.jctec.zhen.helper"
EXPECTED_TEAM="S8662L649U"
OUT="$REPO/build/$APP_NAME.app"

say() { printf '%s\n' "$*"; }
rule() { printf '%s\n' "────────────────────────────────────────────────────────────"; }

say "build-app: compiling $APP_NAME ($CONFIG)"
rule
xcodebuild -project "$PROJECT" -scheme "$APP_NAME" -configuration "$XCCONFIG" \
    -derivedDataPath "$DERIVED" build \
    CODE_SIGNING_ALLOWED=NO | sed 's/^/  /'
BIN="$DERIVED/Build/Products/$XCCONFIG/$APP_NAME.app/Contents/MacOS/$APP_NAME"
[ -x "$BIN" ] || { say "build-app: no binary at $BIN"; exit 1; }

say "build-app: assembling the bundle"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$APP_NAME"

# Generated from the same array the scanner browses. See the header.
"$BIN" --print-info-plist > "$OUT/Contents/Info.plist"
plutil -lint "$OUT/Contents/Info.plist" >/dev/null || {
    say "build-app: the generated Info.plist is not valid"; exit 1;
}
printf 'APPL????' > "$OUT/Contents/PkgInfo"

# The icon, rendered fresh from the vector rather than copied from a checked-in raster.
# Contents/Resources is where CFBundleIconFile looks, and it is what gives the Login
# Items row the app's own mark — the row that carries the whole argument for letting
# somebody trust a root daemon.
say "build-app: rendering the icon"
if "$REPO/Scripts/make-icon.sh" "$REPO/Design/icon/icon-colour.svg" "$OUT/Contents/Resources/Zhen.icns" >/dev/null 2>&1; then
    say "  Contents/Resources/Zhen.icns"
else
    say "  no SVG renderer, so the bundle has no icon and Login Items will show a"
    say "  generic one. brew install librsvg. See Scripts/make-icon.sh."
fi

# ── The privileged helper ──────────────────────────────────────────────────────
#
# A launch daemon lives inside the app bundle and is registered with SMAppService. The
# layout is not a convention this script invented: `SMAppService.daemon(plistName:)`
# looks for exactly Contents/Library/LaunchDaemons/<plistName>, and BundleProgram is
# resolved relative to the bundle root.
say "build-app: embedding the privileged helper"
swift build --package-path "$PACKAGE" -c "$CONFIG" --product zhen-helper >/dev/null
HELPER_BIN="$(swift build --package-path "$PACKAGE" -c "$CONFIG" --show-bin-path)/zhen-helper"
[ -x "$HELPER_BIN" ] || { say "build-app: no helper binary at $HELPER_BIN"; exit 1; }
mkdir -p "$OUT/Contents/Library/LaunchDaemons"
cp "$HELPER_BIN" "$OUT/Contents/MacOS/zhen-helper"

# AssociatedBundleIdentifiers is the whole reason Login Items shows "Zhen" with the
# app's icon instead of a bare reverse-DNS label. Without it a person who just installed
# a background root process sees a string they have to search for before they can decide
# whether to trust it, which is the exact failure the requirement exists to prevent.
cat > "$OUT/Contents/Library/LaunchDaemons/$HELPER_LABEL.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$HELPER_LABEL</string>
    <key>BundleProgram</key>
    <string>Contents/MacOS/zhen-helper</string>
    <key>MachServices</key>
    <dict>
        <key>$HELPER_LABEL</key>
        <true/>
    </dict>
    <key>AssociatedBundleIdentifiers</key>
    <array>
        <string>$APP_BUNDLE_ID</string>
    </array>
</dict>
</plist>
PLIST
plutil -lint "$OUT/Contents/Library/LaunchDaemons/$HELPER_LABEL.plist" >/dev/null || {
    say "build-app: the generated daemon plist is not valid"; exit 1;
}

# ── Signing ────────────────────────────────────────────────────────────────────
#
# SMAppService requires the app and its daemon to be signed by the same team, and the
# helper's XPC listener requires the client to be this app signed by this team. Both of
# those fail at a user's first launch rather than at build time unless something checks
# here, and the failure they produce is error 108, "unable to read plist", which names
# the wrong thing entirely and sends people to inspect XML that is fine.
IDENTITY="${ZHEN_SIGN_IDENTITY:-Developer ID Application}"
FOUND="$(security find-identity -v -p codesigning 2>/dev/null | grep "$IDENTITY" | head -1)"

if [ -n "$FOUND" ]; then
    TEAM="$(printf '%s' "$FOUND" | sed -n 's/.*(\([A-Z0-9]\{10\}\))".*/\1/p')"
    if [ "$TEAM" != "$EXPECTED_TEAM" ]; then
        say "build-app: signing identity is team '$TEAM' but the helper's code requirement"
        say "           demands '$EXPECTED_TEAM'. They must match or SMAppService will"
        say "           refuse the daemon at registration, and the XPC client check will"
        say "           refuse every connection."
        say "           Fix CodeRequirement.teamIdentifier in ZhenPrivilege, or sign"
        say "           with the matching certificate."
        exit 1
    fi
    say "build-app: signing with Developer ID, team $TEAM"
    # Inside out. A bundle is sealed by its signature, so anything signed after the
    # enclosing bundle invalidates it.
    codesign --force --timestamp --options runtime \
        --sign "$IDENTITY" --identifier "$HELPER_LABEL" \
        "$OUT/Contents/MacOS/zhen-helper"
    codesign --force --timestamp --options runtime \
        --sign "$IDENTITY" --identifier "$APP_BUNDLE_ID" "$OUT"
    say "build-app: verifying the seal"
    codesign --verify --deep --strict --verbose=1 "$OUT" 2>&1 | sed 's/^/  /'
else
    # Ad-hoc. Enough for the system to treat this as a stable identity across launches,
    # which is what TCC keys the Local Network grant on. NOT enough for SMAppService:
    # an ad-hoc daemon is refused at registration with error 108.
    say "build-app: no '$IDENTITY' certificate found — signing ad-hoc"
    say "           The app will run and scan. Installing the privileged helper will"
    say "           fail with error 108, which reads as a plist problem and is not one."
    codesign --force --sign - --identifier "$HELPER_LABEL" \
        "$OUT/Contents/MacOS/zhen-helper" 2>/dev/null || true
    codesign --force --sign - --identifier "$APP_BUNDLE_ID" "$OUT" 2>/dev/null \
        || say "build-app: codesign unavailable — the bundle will still run locally"
fi

rule
say "build-app: $OUT"
say "  bundle id   $(plutil -extract CFBundleIdentifier raw "$OUT/Contents/Info.plist")"
say "  version     $(plutil -extract CFBundleShortVersionString raw "$OUT/Contents/Info.plist")"
say "  bonjour     $(plutil -extract NSBonjourServices xml1 -o - "$OUT/Contents/Info.plist" | grep -c '<string>') service types declared"
say "  helper      $HELPER_LABEL"
say "  login items shows '$(plutil -extract CFBundleName raw "$OUT/Contents/Info.plist")' via AssociatedBundleIdentifiers"
say ""
say "  open $OUT"
