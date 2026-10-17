#!/usr/bin/env bash
#
# check-docs.sh — every repository path the documentation names must exist.
#
# The same check zhen-core runs, for the same reason: prose has no compiler. Before this
# repository went public its documents still pointed at a build record and artboards that
# had moved out, and nothing noticed, because nothing looks at prose.
#
# It checks paths and nothing else — a document can still be wrong about what a file
# CONTAINS, and no script fixes that.
#
# Usage: Scripts/check-docs.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
checked=0

# The documents a reader is pointed at. Not AGENTS.md: it is a byte-copy of house rules
# shared with other projects, and names their layout, not this one's.
FILES=(README.md CONTRIBUTING.md SECURITY.md Docs/*.md)

# Paths the documents name as OUTPUTS: made by a lane or a script, ignored by git, and
# absent from a fresh clone by design. A document naming one is describing where a
# result lands, not claiming a committed file.
GENERATED='^(fastlane/(test_output|screenshots|report\.xml)|Docs/assets|AppStoreAssets|AppStoreSimulatorCaptures|build|vendor|Releases)(/|$)'

# The anchors include the old monorepo's top-level `zhen/` and `zhen-app/`, which do not
# exist here, so a document still naming `zhen-app/Docs/…` fails rather than passing on
# the `Docs/…` inside it. The boundary before an anchor keeps prose such as
# `Application Support/zhen/history.ndjson` from being read as a repository path.
ANCHORS='(Docs|Scripts|Zhen|ZhenTests|ZhenUITests|Tools|Design|Helper|Marketing|fastlane|zhen|zhen-app)'

for doc in "${FILES[@]}"; do
    [ -f "$doc" ] || { echo "MISSING DOCUMENT: $doc"; fail=1; continue; }

    paths=$(grep -ohE "(^|[\`( |\"])${ANCHORS}/[A-Za-z0-9_./+-]*[A-Za-z0-9_+-]" "$doc" \
            | sed -E 's/^[`( "]//; s/[.,:;)]*$//' | sort -u)

    while IFS= read -r p; do
        [ -z "$p" ] && continue
        if printf '%s' "$p" | grep -qE "$GENERATED"; then continue; fi
        checked=$((checked + 1))
        [ -e "$p" ] || { echo "$doc: names a path that does not exist: $p"; fail=1; }
    done <<< "$paths"
done

[ "$checked" = 0 ] && { echo "no paths found — the check measures nothing"; exit 2; }

if [ "$fail" = 0 ]; then
    echo "check-docs: $checked paths checked across ${#FILES[@]} documents — PASS"
else
    echo "check-docs: FAIL"
fi
exit $fail
