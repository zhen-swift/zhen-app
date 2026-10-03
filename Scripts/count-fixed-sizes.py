#!/usr/bin/env python3
"""Count fixed-size frames in the app's views, separating layout from preview canvases.

The inventory in Docs/plans/RESPONSIVE-plan.md is a shell grep, and it is wrong twice.

It is case-sensitive on `width:`, so it never matched `minWidth:` or `maxWidth:` — every
frame expressed as a RANGE was invisible, and a range with numbers in it is exactly as
fixed as a single width. The device table's nine column constants were all ranges, which
is why deleting them in stage 2 did not move the plan's number by one.

And it counts `#Preview` canvases. A preview has to declare a size; there is no content
to size to and no window to fill. Fifty-four of the plan's eighty-four call sites are
preview canvases, so two thirds of the number it ratchets on cannot be improved and
should not be.

This reports both and ratchets on the layout count.
"""
import re
import sys
import pathlib

FRAME = re.compile(r"\.frame\([^)]*(?:width|height):", re.IGNORECASE)
ONLY_INFINITY = re.compile(
    r"\.frame\((?:max(?:Width|Height): \.infinity[, ]*)+(?:alignment: \.[a-zA-Z]+)?\)",
    re.IGNORECASE,
)
# A dimension computed from the container is the opposite of a fixed one: it is how a
# view says "a fraction of whatever I was given". `StageCard`'s progress fill is
# `geometry.size.width * fraction`, which the plan's grep counts as a fixed size.
DERIVED = re.compile(
    # A dimension read from the container, or from the measured-column table. The
    # second is the mechanism that removes fixed sizes; counting it as one would mean
    # the inventory never reaches its floor.
    r"(?:geometry|proxy)\.size\.|widths\[column\]|\.measuredColumn\(",
    re.IGNORECASE,
)


def scan(root: pathlib.Path):
    layout, preview = [], []
    for path in sorted(root.rglob("*.swift")):
        in_preview = False
        for number, line in enumerate(path.read_text().split("\n"), start=1):
            if line.startswith("#Preview"):
                in_preview = True
            elif line and not line[0].isspace() and not line.startswith("#"):
                # Any other top-level declaration ends the preview block.
                in_preview = False
            if not FRAME.search(line) or ONLY_INFINITY.search(line):
                continue
            if DERIVED.search(line):
                continue
            (preview if in_preview else layout).append(
                f"{path}:{number}: {line.strip()}"
            )
    return layout, preview


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent / "zhen-app"
    layout, preview = scan(root)
    if "--list" in sys.argv:
        for entry in layout:
            print(entry)
        return 0
    print(f"layout {len(layout)}")
    print(f"preview {len(preview)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
