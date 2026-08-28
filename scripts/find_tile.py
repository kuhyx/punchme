#!/usr/bin/env python3
"""Prints the tap coordinates of the sync tile from a uiautomator dump.

Looked up rather than hardcoded because `adb shell screencap` on this device
returns a downscaled image: a tap aimed at a screenshot pixel lands at roughly
double the intended y, which is how a verification run once hit the punch
button and wrote a spurious day into the real timesheet.

Parsed as XML rather than matched with a regex. The label and the bounds are
separated by a dozen other attributes, so a pattern spanning them has to cross
quoted values it cannot see the end of -- which silently found nothing while
the tile was plainly on screen.
"""

from __future__ import annotations

import re
import sys
from xml.etree import ElementTree

# The tile's title, as the accessibility tree reports it.
TILE = "Connect Google account"

_BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")


def tile_centre(path: str) -> tuple[int, int] | None:
    """Returns the centre of the sync tile, or None when it is not on screen."""
    tree = ElementTree.parse(path)
    for node in tree.iter("node"):
        label = node.get("content-desc", "") or node.get("text", "")
        if TILE not in label:
            continue
        found = _BOUNDS.match(node.get("bounds", ""))
        if found is None:
            continue
        left, top, right, bottom = (int(value) for value in found.groups())
        return (left + right) // 2, (top + bottom) // 2
    return None


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("usage: find_tile.py <uiautomator-dump.xml>")
    centre = tile_centre(sys.argv[1])
    if centre is None:
        # Silent, non-zero: the caller falls back to asking for a manual tap.
        raise SystemExit(1)
    print(f"{centre[0]} {centre[1]}")


if __name__ == "__main__":
    main()
