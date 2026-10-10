#!/usr/bin/env python3
"""Render the logomark wind-up + spin animation as PNG frames.

Usage: render-frames.py LOGOMARK_SVG OUT_DIR

Writes to OUT_DIR:
  frame-N.png       one image per unique rotation angle
  frame-count.txt   number of frame-N.png files
  sequence.txt      frame index per animation tick (one per line)
  sequence.script   the same sequence as Plymouth script assignments
"""

import math
import re
import subprocess
import sys
from pathlib import Path

FPS = 50  # Plymouth calls the refresh function at 50 Hz
SIZE = 512  # rendered frame size in px; the script scales down to fit

WIND_ANGLE = -40.0  # negative = counter-clockwise
WIND_SECONDS = 0.7
SPIN_SECONDS = 1.1
SPIN_EASE_POWER = 3.5  # ease-out strength of the spin; 3 = cubic, higher = sharper

# Logomark circumradius is 1152 user units; pad slightly so antialiasing isn't clipped.
CANVAS_RADIUS = 1152 * 1.02


def ease_in_out_cubic(t):
    return 4 * t**3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def ease_out(t, power):
    return 1 - (1 - t) ** power


def ticks(seconds):
    return round(seconds * FPS)


def timeline():
    """Yield the logo rotation angle (degrees) for each tick of one loop."""
    n = ticks(WIND_SECONDS)
    for i in range(n):
        yield WIND_ANGLE * ease_in_out_cubic(i / n)
    n = ticks(SPIN_SECONDS)
    for i in range(n):
        yield WIND_ANGLE + (360 - WIND_ANGLE) * ease_out(i / n, SPIN_EASE_POWER)


def main(logomark_path, out_dir):
    out = Path(out_dir)
    source = Path(logomark_path).read_text()
    inner = re.search(r"<svg[^>]*>(.*)</svg>", source, re.S).group(1)

    r = CANVAS_RADIUS
    frame_of_angle = {}
    sequence = []
    for angle in timeline():
        key = round(angle % 360, 2) % 360
        if key not in frame_of_angle:
            index = len(frame_of_angle)
            frame_of_angle[key] = index
            svg = (
                f'<svg xmlns="http://www.w3.org/2000/svg" '
                f'viewBox="{-r} {-r} {2 * r} {2 * r}">'
                f'<g transform="rotate({key})">{inner}</g></svg>'
            )
            subprocess.run(
                [
                    "rsvg-convert",
                    "-w",
                    str(SIZE),
                    "-h",
                    str(SIZE),
                    "-o",
                    str(out / f"frame-{index}.png"),
                ],
                input=svg.encode(),
                check=True,
            )
        sequence.append(frame_of_angle[key])

    (out / "frame-count.txt").write_text(f"{len(frame_of_angle)}\n")
    (out / "sequence.txt").write_text("".join(f"{i}\n" for i in sequence))
    (out / "sequence.script").write_text(
        "\n".join(f"sequence[{t}] = {i};" for t, i in enumerate(sequence))
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
