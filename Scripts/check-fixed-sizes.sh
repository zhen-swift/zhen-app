#!/usr/bin/env bash
#
# check-fixed-sizes.sh — the ratchet. The count of fixed sizes may fall, never rise.
#
# ── The grep, and why it is not the one in the plan ────────────────────────────
#
# `Docs/plans/RESPONSIVE-plan.md` defines the inventory as:
#
#     grep -rnE '\.frame\(' $APP --include=*.swift \
#       | grep -E 'width:|height:' | grep -v 'maxWidth: \.infinity)'
#
# That pattern is case-sensitive, so `width:` does not match `minWidth:` or `maxWidth:`
# — the capital W is not the lowercase one. Every frame expressed as a RANGE is
# therefore invisible to it, and a range with numbers in it is exactly as fixed as a
# single width. The device table's nine column constants were all ranges; deleting them
# in stage 2 did not move the plan's number by one.
#
# Measured on the same tree: the plan's grep reports 84 and the real count is 96.
#
# So this matches any frame dimension case-insensitively, then subtracts the frames
# whose only dimensions are `.infinity` — those are how a view says "take what is
# there", which is the opposite of a fixed size.
#
# ── Survivors ─────────────────────────────────────────────────────────────────
#
# The plan names the only acceptable categories: a glyph with no content to size to
# (`dotSize`, `progressTrackHeight`, `barWidth`) and a typographic measure limit
# (`proseMaxWidth`, `contentMaxWidth`). Each survivor carries a comment at its call site
# saying which it is. This script does not check for the comment — a human does — but
# the baseline is what stops the number drifting upward while nobody looks.

set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="$REPO/zhen-app"
BASELINE_FILE="$REPO/Scripts/fixed-sizes-baseline.txt"

# Delegated to count-fixed-sizes.py, which separates the two things the plan's grep
# conflates. See its docstring: the grep is case-sensitive on `width:` so it never saw a
# `minWidth:`/`maxWidth:` range, and it counts `#Preview` canvases, which have no content
# to size to and no window to fill. Two thirds of the plan's 84 are previews.
count() {
    python3 "$REPO/Scripts/count-fixed-sizes.py" | awk '/^layout/ { print $2 }'
}

CURRENT="$(count)"

if [ "${1:-}" = "--write-baseline" ]; then
    printf '%s\n' "$CURRENT" > "$BASELINE_FILE"
    echo "check-fixed-sizes: baseline written as $CURRENT"
    exit 0
fi

if [ ! -f "$BASELINE_FILE" ]; then
    echo "check-fixed-sizes: no baseline at $BASELINE_FILE" >&2
    echo "  Write one with: $0 --write-baseline" >&2
    exit 1
fi

BASELINE="$(tr -d '[:space:]' < "$BASELINE_FILE")"

PREVIEW="$(python3 "$REPO/Scripts/count-fixed-sizes.py" | awk '/^preview/ { print $2 }')"
echo "check-fixed-sizes: $CURRENT fixed-size frames in layout, baseline $BASELINE"
echo "                   $PREVIEW more in #Preview canvases, which are not ratcheted"

if [ "$CURRENT" -gt "$BASELINE" ]; then
    echo "" >&2
    echo "  The count ROSE by $((CURRENT - BASELINE))." >&2
    echo "" >&2
    echo "  A new fixed size needs one of the two reasons in RESPONSIVE-plan.md's" >&2
    echo "  section on what goes and what stays: a glyph with no content to size to," >&2
    echo "  or a typographic measure limit. If it is one of those, say so at the call" >&2
    echo "  site and move the baseline deliberately:" >&2
    echo "" >&2
    echo "      $0 --write-baseline" >&2
    echo "" >&2
    echo "  The layout frames:" >&2
    python3 "$REPO/Scripts/count-fixed-sizes.py" --list | sed "s|$REPO/||" | sed 's/^/    /' >&2
    exit 1
fi

if [ "$CURRENT" -lt "$BASELINE" ]; then
    echo "  Down $((BASELINE - CURRENT)) from the baseline. Lower it:"
    echo "      $0 --write-baseline"
fi
exit 0
