#!/usr/bin/env python3
"""Render the logomark wind-up + spin animation as PNG frames.

Usage: render-frames.py LOGOMARK_SVG OUT_DIR
"""

import sys

from frames import read_logomark, render, ticks

WIND_ANGLE = -40.0  # negative = counter-clockwise
WIND_SECONDS = 0.7
SPIN_SECONDS = 1.1
SPIN_EASE_POWER = 3.5  # ease-out strength of the spin; 3 = cubic, higher = sharper


def ease_in_out_cubic(t):
    return 4 * t**3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def ease_out(t, power):
    return 1 - (1 - t) ** power


def timeline():
    """Yield the logo rotation angle (degrees) for each tick of one loop."""
    n = ticks(WIND_SECONDS)
    for i in range(n):
        yield WIND_ANGLE * ease_in_out_cubic(i / n)
    n = ticks(SPIN_SECONDS)
    for i in range(n):
        yield WIND_ANGLE + (360 - WIND_ANGLE) * ease_out(i / n, SPIN_EASE_POWER)


def main(logomark_path, out_dir):
    defs, polygons = read_logomark(logomark_path)
    logo = defs + "".join(polygons)
    render(
        out_dir,
        (round(angle % 360, 2) % 360 for angle in timeline()),
        lambda angle: f'<g transform="rotate({angle})">{logo}</g>',
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
