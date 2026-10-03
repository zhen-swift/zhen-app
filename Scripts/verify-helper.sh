#!/usr/bin/env bash
#
# verify-helper.sh — prove the helper from the wire, not from the app's description.
#
# ── The claim ──────────────────────────────────────────────────────────────────
#
# With the privileged helper installed, an app running as an ordinary user puts layer-2
# ARP requests on the wire that it built itself. Nothing about being an ordinary user
# makes the kernel do that, and no artifact saying "composite" is evidence of it — that
# exact claim is what cost study 1 a hypothesis, when a run labelled privileged turned
# out to be the kernel resolving next-hop for ICMP and not a sweep at all.
#
# ── Telling our ARP from the kernel's, which frame shape does NOT do ───────────
#
# The first version of this script claimed our frames were 42 bytes and the kernel's
# were padded to 60, and rested the whole verdict on it. That is false on this machine,
# and the script's own negative run said so: with the helper unregistered and the app
# unprivileged, 503 forty-two-byte ARP requests appeared. A control settled it — an
# unprivileged `zhen scan`, whose artifact reports `unprivileged` and cannot open a
# capture device at all, emitted 250 ARP requests, every one of them 42 bytes. The
# kernel does not pad on this interface, so frame length separates nothing.
#
# That is the third time this project has tried to identify its own packets by a
# property it had not checked: kernel SYNs counted as the fingerprint probe's until
# e4d3760, kernel ARP counted as the sweep's in measure-arp-pacing.sh, and now this.
# The lesson keeps being the same one, so this script stops trying to be clever about
# shape and uses the method `verify-privileged.sh` used from the start.
#
# VOLUME, measured against a baseline from the same binary on the same segment. The
# kernel ARPs once per address it must resolve for the ICMP sweep. The layer-2 sweep
# ARPs every address itself, several times, IN ADDITION to that. Measured on this
# machine with the command line:
#
#   unprivileged, no capture device     250 ARP requests
#   privileged, arp_sweep in the run   1001 ARP requests
#
# So the question is not "what do our frames look like" but "did roughly four times as
# much ARP appear when the sweep was allowed to run". `ZHEN_CAPTURE=direct` runs
# the app with the sweep off so the baseline comes from the same app, the same segment
# and the same minute, rather than from a number in a comment.
#
# ── Usage ──────────────────────────────────────────────────────────────────────
#
#     sudo ./Scripts/verify-helper.sh [interface]
#
# Root is for tcpdump only. The app under test is launched as the invoking user and is
# never given any privilege by this script — which is the entire point.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$REPO/build/Zhen.app"
LABEL="com.jctec.zhen.helper"
WORK="$(mktemp -d /tmp/zhen-helper.XXXXXX)"
SETTLE="${SETTLE:-14}"

say()  { printf '%s\n' "$*"; }
rule() { printf '%s\n' "────────────────────────────────────────────────────────────"; }
die()  { printf 'verify-helper: %s\n' "$*" >&2; exit 1; }
trap 'rm -rf "$WORK"' EXIT

[ "$(id -u)" = "0" ] || die "must run as root, for tcpdump. Run: sudo $0"
[ -n "${SUDO_USER:-}" ] || die "no SUDO_USER; the app has to be launched as an ordinary
user or this proves nothing at all. Invoke through sudo rather than as a root shell."
[ -d "$APP" ] || die "no app at $APP. Build it: ./Scripts/build-app.sh"

IFACE="${1:-$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')}"
[ -n "$IFACE" ] || die "could not determine the default interface; pass one as \$1"
MAC="$(ifconfig "$IFACE" | awk '/ether/{print $2; exit}')"

say "interface     $IFACE"
say "hardware      $MAC"
say "app           $APP"
say "launched as   $SUDO_USER (never root — that is the claim)"
rule

say "[signing] what the two sides demand of each other"
codesign -dv "$APP" 2>&1 | grep -E "^Identifier|^TeamIdentifier" | sed 's/^/  app     /'
codesign -dv "$APP/Contents/MacOS/zhen-helper" 2>&1 \
    | grep -E "^Identifier|^TeamIdentifier" | sed 's/^/  helper  /'
if codesign --verify -R='anchor apple generic and certificate leaf[subject.OU] = "S8662L649U"' \
        "$APP" >/dev/null 2>&1; then
    say "  both signed by team S8662L649U, which SMAppService requires and the XPC"
    say "  listener checks on every connection"
else
    say "  NOT Developer ID signed. Registration will fail with error 108, which reads"
    say "  as a plist problem and is not one."
fi
rule

registered() {
    launchctl print "system/$LABEL" >/dev/null 2>&1
}

say "[registration] what launchd holds, not what the app says"
if registered; then
    say "  system/$LABEL is loaded"
    launchctl print "system/$LABEL" 2>/dev/null \
        | grep -E "^\s+(state|program|active count) " | sed 's/^/  /'
else
    say "  system/$LABEL is NOT loaded."
    say ""
    say "  Install it from the app: open the bundle, go to Settings, press"
    say "  \"Install Helper…\", then approve Zhen in System Settings under"
    say "  General then Login Items. Then run this again."
    say ""
    say "  Continuing anyway, so the negative half below still tells you something."
fi
rule

# One app launch under capture, as the ordinary user.
#
# Through `open --env`, not by running Contents/MacOS/Zhen directly. The bare
# executable starts, gets no window server session, never lays out a view, and therefore
# never runs the `.task` that scans — so it produced three ARP requests where a real
# launch produces around 250, and the comparison below silently measured nothing. A
# launch that does not scan makes both halves of this script agree for the wrong reason,
# which is worse than a failure.
#
# `--env` is what carries ZHEN_CAPTURE through a proper launch.
capture_scan() {
    local label="$1" policy="$2"
    local pcap="$WORK/$label.pcap"
    tcpdump -i "$IFACE" -n -e -s 96 -w "$pcap" arp >/dev/null 2>"$pcap.log" &
    local pid=$!
    sleep 2
    # Any instance left open from a previous run scans on ITS schedule, not this one's,
    # and a second instance launched beside it may never reach its device list. That is
    # how a baseline run came back with eight ARP requests across four addresses when a
    # real one makes about 250.
    sudo -u "$SUDO_USER" osascript -e 'tell application "Zhen" to quit' >/dev/null 2>&1
    sleep 2
    sudo -u "$SUDO_USER" open -n --env "ZHEN_CAPTURE=$policy" "$APP" >/dev/null 2>&1
    sleep "$SETTLE"
    sudo -u "$SUDO_USER" osascript -e 'tell application "Zhen" to quit' >/dev/null 2>&1
    sleep 2
    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
}

# Requests this machine SENT. `tcpdump -e` prints "<src> > <dst>", so the address has to
# be anchored to the start of the line: matching it anywhere also catches ARP the router
# sends TO us, and the first version of this printed one of those as its evidence line —
# somebody else's packet, offered as proof of ours.
ours() {
    tcpdump -r "$WORK/$1.pcap" -n -e arp 2>/dev/null \
        | grep Request | grep -i "^[0-9:.]* $MAC >"
}
requests() { ours "$1" | wc -l | tr -d ' '; }
targets() {
    ours "$1" | sed 's/.*who-has //;s/ tell.*//' | sort -u | wc -l | tr -d ' '
}

# ── A warm-up whose capture is thrown away ─────────────────────────────────────
#
# Not politeness. The kernel ARPs once per address it must resolve, and when an address
# never answers it RETRIES — so the first sweep of a /24 after a cold or expired ARP
# cache costs about two requests per address, and the second costs one, because by then
# the kernel holds negative entries for the 240-odd addresses that are not there.
#
# Measured, with no helper installed and therefore no sweep in either run:
#
#     first run    498 requests / 250 addresses = 1.99 per address
#     second run   247 / 247                    = 1.00
#
# Two identical runs, differing only in which went first, and the earlier one landed at
# 1.99 against a threshold of 2.0. That is a false positive one retransmission away, and
# it would have read as "something reached a capture device without the helper".
#
# So the first run is discarded. Both measured runs then start from the same warm cache
# and the comparison is between the sweep and its absence rather than between a cold
# cache and a warm one.
say "[warm-up] one scan discarded, so both measured runs start from a warm ARP cache"
capture_scan warmup direct
say "  discarded: $(requests warmup) requests across $(targets warmup) addresses"
rule

say "[baseline] the app with the sweep turned off (ZHEN_CAPTURE=direct)"
capture_scan baseline direct
BASE=$(requests baseline)
say "  ARP requests from $MAC: $BASE  across $(targets baseline) addresses"
say "  This is the kernel resolving next-hop for the ICMP sweep. No helper is involved"
say "  and none would help: the app asked for a direct open and did not get one."
rule

say "[helper] the same app, same segment, sweep allowed"
capture_scan helper default
WITH=$(requests helper)
say "  ARP requests from $MAC: $WITH  across $(targets helper) addresses"
if [ "$WITH" -gt 0 ]; then
    say "  first request on the wire:"
    # Through `ours`, like the counts above. Reading the capture directly here printed
    # the first ARP request in the file, which is routinely one the ROUTER sent TO this
    # machine — somebody else's packet, offered as evidence of ours, in the one line a
    # person is most likely to quote.
    ours helper | head -1 | sed 's/^/    /'
fi
rule

# ── Reading the wire ───────────────────────────────────────────────────────────
#
# The primary signal is REQUESTS PER UNIQUE TARGET, not the difference between the two
# runs. The kernel resolves each address once, so a run without the sweep sits at about
# 1.0; the sweep asks each address up to `attempts` times, which is three, so a run with
# it sits near 3. Measured on this machine:
#
#   app, no helper            253 requests / 250 targets = 1.01
#   app, no helper            248 / 248                  = 1.00
#   privileged command line  1001 / 253                  = 3.96
#
# The ratio is used because the difference is only as trustworthy as the baseline, and a
# baseline that failed to scan inflates the difference into a pass. That is a false
# positive this script could produce and did nearly produce: a baseline of 8 requests
# across 4 addresses against 753 across 255 gave a difference of 745 and a confident
# verdict, when what it had actually measured was one broken run and one good one.
ratio() {
    awk -v r="$1" -v tg="$2" 'BEGIN { if (tg == 0) print "0.00"; else printf "%.2f", r/tg }'
}
BASE_T=$(targets baseline)
WITH_T=$(targets helper)
BASE_R=$(ratio "$BASE" "$BASE_T")
WITH_R=$(ratio "$WITH" "$WITH_T")

say "[wire] requests / unique targets"
say "      baseline     $BASE / $BASE_T = $BASE_R per address"
say "      sweep on     $WITH / $WITH_T = $WITH_R per address"
say ""

# Each run has to have scanned. Checked separately, because a floor that only fires when
# BOTH runs are empty lets a dead baseline manufacture a pass.
FLOOR=50
if [ "$WITH" -lt "$FLOOR" ]; then
    say "VERDICT: the run with the sweep allowed put only $WITH ARP requests on the wire."
    say "         A /24 sweep costs about 250. That run did not scan, so nothing here"
    say "         was measured. Check that the app opens and reaches its device list,"
    say "         and that Local Network access is granted under Privacy and Security."
    exit 1
fi
if [ "$BASE" -lt "$FLOOR" ]; then
    say "NOTE:    the baseline run put only $BASE requests across $BASE_T addresses, which"
    say "         is not a sweep. The difference against it means nothing and is ignored"
    say "         below; the verdict rests on the per-address ratio, which does not need"
    say "         the baseline to be sound. Re-run for a clean comparison."
    say ""
fi

# The baseline is the control and it has to look like one. With the sweep off and a warm
# cache it should sit at about 1.00 — one resolution per address, the kernel and nothing
# else. A baseline that is itself above the threshold means the control is not a control,
# and comparing against it would be reading a number that has already gone wrong.
BASE_HIGH=$(awk -v r="$BASE_R" 'BEGIN { print (r >= 1.6) ? "yes" : "no" }')
if [ "$BASE_HIGH" = "yes" ]; then
    say "VERDICT: the baseline asked each address $BASE_R times with the sweep switched"
    say "         off, where the kernel alone asks about once. The control is not a"
    say "         control, so nothing is concluded from comparing against it."
    say ""
    say "         The usual cause is an ARP cache that was still cold despite the"
    say "         warm-up — a /24 whose dead addresses have expired from the negative"
    say "         cache costs roughly two requests each rather than one. Run it again."
    exit 1
fi

SWEPT=$(awk -v r="$WITH_R" 'BEGIN { print (r >= 2.0) ? "yes" : "no" }')

if ! registered; then
    if [ "$SWEPT" = "no" ]; then
        say "VERDICT: the helper is not registered, and the app asked each address $WITH_R"
        say "         times — one resolution per address, which is the kernel and nothing"
        say "         else. That is the negative half and it passes. The app still"
        say "         scanned: an unprivileged scan finds every host that answers ICMP"
        say "         and reports that the layer-2 sweep did not run."
        say ""
        say "         Install the helper from the app's Settings and approve it, then"
        say "         run this again for the positive half."
        exit 0
    fi
    say "VERDICT: the helper is NOT registered and the app still asked each address"
    say "         $WITH_R times. Something reached a capture device without the helper."
    say "         That wants explaining before anything here is believed."
    exit 1
fi

if [ "$SWEPT" = "yes" ]; then
    say "VERDICT: an app running as $SUDO_USER, with no privilege of its own, asked each"
    say "         of $WITH_T addresses $WITH_R times. One ask per address is the kernel"
    say "         resolving next-hop; repeating it is a layer-2 sweep retransmitting, and"
    say "         writing those frames needs a capture device. The only route to one for"
    say "         an unprivileged process is the helper."
    exit 0
fi

say "VERDICT: the helper IS registered and the app asked each address $WITH_R times,"
say "         which is the kernel alone. Registration is not the same as a daemon that"
say "         runs: check it was approved in Login Items, and read the app's"
say "         degradations, which name the refusal the helper gave."
exit 1
