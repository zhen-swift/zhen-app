#!/usr/bin/env bash
#
# check-tokens.sh — no literal sizes or colours in a view, and no `var x: some View`.
#
# AGENTS.md: "A missing value is added to the enum, never inlined", "Never
# `Color(red:green:blue:)` in a view", and inner views are `struct TopView: View`, never
# `var topView: some View`. The previous app had 351 lines of colour in code, 4
# `Color(red:…)`, 18 computed-view properties and a 45-constant `Metrics`, and each of those
# was a rule nobody checked. This is the check.
#
# The same shape as zhen-core's check-docs.sh: read the files, compare against the rule,
# fail on a difference, and say how much was checked so a pass on nothing is visible.
#
# What counts as a literal: a number where a spacing, radius, border width, frame size or
# font size goes, and any colour built from components, a hex value or a string name. A
# token is `.spacing.medium`, `.cornerRadius.large`, `.borderWidth.hairline`,
# `.iconSize.small`, or a generated asset symbol such as `.accent`.
#
# ── Two lessons from the checks before this one ───────────────────────────────────
#
# The old fixed-size inventory grepped `width:` case-sensitively and so never saw
# `minWidth:` or `maxWidth:` — every range was invisible. The frame rule here matches
# `width`, `minWidth`, `maxWidth`, `idealWidth` and the heights explicitly.
#
# A check that passes on zero files is not a pass. If the source directory is missing or
# empty this exits 2, and every run prints how many files it read.
#
# ── The escape hatch ──────────────────────────────────────────────────────────────
#
# A line ending in `// tokens: allow — <reason>` is skipped and counted. Use it for a
# `#Preview` canvas size or a window's minimum, which are not spacing; never for a value a
# token should hold. The reason is required, and the count is printed.
#
# Usage:
#   Scripts/check-tokens.sh               check the app's sources (default: Zhen/)
#   Scripts/check-tokens.sh <dir>         check another directory
#   Scripts/check-tokens.sh --self-test   prove every rule still fires, on this machine's grep

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Rules: name, then an extended regex. POSIX ERE only, no \b: BSD grep on a Mac and GNU grep
# on the CI runner must agree, and --self-test is what proves they do.
NUM='-?[0-9]+(\.[0-9]+)?'
RULES=(
  "spacing-literal|\.padding\([^)]*[0-9]"
  "spacing-literal|[sS]pacing:[[:space:]]*${NUM}"
  "frame-literal|\.frame\([^)]*([wW]idth|[hH]eight):[[:space:]]*${NUM}"
  "radius-literal|[cC]ornerRadius(:|\()[[:space:]]*${NUM}"
  "border-literal|[lL]ineWidth:[[:space:]]*${NUM}"
  "border-literal|\.border\([^)]*width:[[:space:]]*${NUM}"
  "font-size-literal|\.system\([[:space:]]*size:[[:space:]]*${NUM}"
  "colour-literal|Color\([[:space:]]*(red:|white:|hue:|\.sRGB|\.displayP3|\.linearSRGB)"
  "colour-literal|Color\([[:space:]]*\""
  "colour-literal|#colorLiteral|(NS|UI)Color[.(]"
  "colour-literal|0x[0-9A-Fa-f]{6}"
  "computed-view|(^|[^A-Za-z0-9_])var[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[[:space:]]*some[[:space:]]+View"
)
ALLOW='// tokens: allow — [^[:space:]]'

# check <file>... — prints each violation, sets the globals below.
violations=0
allowed=0
checked=0
fired=""
reported=""
check() {
  local file rule name regex hits line
  for file in "$@"; do
    checked=$((checked + 1))
    for rule in "${RULES[@]}"; do
      name=${rule%%|*}
      regex=${rule#*|}
      hits=$(grep -nE -- "$regex" "$file") || continue
      while IFS= read -r line; do
        local text=${line#*:}
        # Whole-line comments are prose, not code.
        case "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')" in //*) continue ;; esac
        # `var body: some View` is the one computed view the rules want.
        if [ "$name" = computed-view ] \
          && printf '%s' "$text" | grep -qE 'var[[:space:]]+body[[:space:]]*:'; then
          continue
        fi
        if printf '%s' "$text" | grep -qE -- "$ALLOW"; then
          allowed=$((allowed + 1))
          continue
        fi
        echo "$file:${line%%:*}: $name: $(printf '%s' "$text" | sed 's/^[[:space:]]*//')"
        violations=$((violations + 1))
        reported="$reported ${line%%:*}"
        case " $fired " in *" $name "*) ;; *) fired="$fired $name" ;; esac
      done <<< "$hits"
    done
  done
}

swift_files() {
  # Utilities/ holds the token enums, which are numbers by definition.
  find "$1" -name '*.swift' -not -path '*/Utilities/*' | sort
}

if [ "${1:-}" = --self-test ]; then
  fixture=Scripts/check-tokens.fixture.swift
  [ -f "$fixture" ] || { echo "check-tokens: self-test fixture missing: $fixture"; exit 2; }
  expected=$(grep -c '// expect: ' "$fixture")
  # Lines, not just a count: a missed violation and a false one would cancel in a count.
  want_lines=$(grep -n '// expect: ' "$fixture" | cut -d: -f1 | sort -n | tr '\n' ' ')
  check "$fixture" > /dev/null
  got_lines=$(printf '%s\n' $reported | sort -n | tr '\n' ' ')
  want_rules=$(printf '%s\n' "${RULES[@]}" | cut -d'|' -f1 | sort -u | tr '\n' ' ')
  missing=""
  for r in $want_rules; do
    case " $fired " in *" $r "*) ;; *) missing="$missing $r" ;; esac
  done
  if [ "$got_lines" = "$want_lines" ] && [ "$allowed" = 1 ] && [ -z "$missing" ]; then
    echo "check-tokens self-test: $violations of $expected planted violations found," \
      "1 allowed line skipped, every rule fired — PASS"
    exit 0
  fi
  echo "check-tokens self-test: FAIL — found $violations of $expected planted," \
    "$allowed allowed (want 1), rules that never fired:${missing:- none}"
  echo "  want lines: $want_lines"
  echo "  got lines:  $got_lines"
  exit 1
fi

root=${1:-Zhen}
[ -d "$root" ] || { echo "check-tokens: no source directory '$root' — nothing was checked"; exit 2; }
files=()
while IFS= read -r f; do files+=("$f"); done < <(swift_files "$root")
[ "${#files[@]}" -gt 0 ] || { echo "check-tokens: no Swift files under '$root' — nothing was checked"; exit 2; }

check "${files[@]}"
if [ "$violations" = 0 ]; then
  echo "check-tokens: $checked files checked, $allowed allowed by comment — PASS"
  exit 0
fi
echo "check-tokens: $violations violations in $checked files — FAIL"
exit 1
