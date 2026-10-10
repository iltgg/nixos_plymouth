"""Shared helpers for a theme's render-frames.py.

A theme describes its animation as one frame key per 50 Hz tick plus a function
that turns a key into SVG. Ticks with the same key share a single PNG.
"""

import re
import subprocess
from pathlib import Path

FPS = 50  # Plymouth calls the refresh function at 50 Hz
SIZE = 512  # rendered frame size in px; the script scales down to fit

# Logomark circumradius in SVG user units. The logomark SVG is centered on (0, 0).
LOGO_RADIUS = 1152
# Canvas radius used by a plain logo frame; pads slightly so antialiasing isn't clipped.
# The script sizes the logo so this canvas matches its logo_size.
BASE_CANVAS_RADIUS = LOGO_RADIUS * 1.02


def ticks(seconds):
    return round(seconds * FPS)


def read_logomark(path):
    """Return (defs, polygons) from the logomark SVG.

    polygons are the six lambda <polygon> elements in source order, which is
    clockwise starting from rotate(0).
    """
    source = Path(path).read_text()
    defs = re.search(r"<defs>.*?</defs>", source, re.S).group(0)
    polygons = re.findall(r"<polygon\b.*?(?:/>|</polygon>)", source, re.S)
    assert len(polygons) == 6, f"expected 6 lambdas, found {len(polygons)}"
    return defs, polygons


def render(out_dir, keys, svg_for, canvas_radius=BASE_CANVAS_RADIUS):
    """Render one PNG per unique key and write the tick sequence.

    keys: one hashable frame key per animation tick, in order.
    svg_for(key): SVG body (elements only) for that key, in logomark coordinates.

    Writes frame-N.png, frame-count.txt, sequence.txt, sequence.script and
    canvas-scale.txt (frame size relative to a plain logo frame) to out_dir.
    """
    out = Path(out_dir)
    r = canvas_radius
    frame_of_key = {}
    sequence = []
    for key in keys:
        if key not in frame_of_key:
            index = len(frame_of_key)
            frame_of_key[key] = index
            svg = (
                f'<svg xmlns="http://www.w3.org/2000/svg" '
                f'viewBox="{-r} {-r} {2 * r} {2 * r}">{svg_for(key)}</svg>'
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
        sequence.append(frame_of_key[key])

    (out / "frame-count.txt").write_text(f"{len(frame_of_key)}\n")
    (out / "canvas-scale.txt").write_text(f"{canvas_radius / BASE_CANVAS_RADIUS:.4f}\n")
    (out / "sequence.txt").write_text("".join(f"{i}\n" for i in sequence))
    (out / "sequence.script").write_text(
        "\n".join(f"sequence[{t}] = {i};" for t, i in enumerate(sequence))
    )
