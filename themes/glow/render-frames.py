#!/usr/bin/env python3
"""Render the logomark "chasing light" animation as PNG frames.

The six lambdas sit dimmed while a light moves clockwise around them at a
constant speed. Each lambda lights up as a whole, with a glowing halo, then
fades out behind the light like a comet tail. Neighbouring lambdas cross-fade
so the total amount of light stays constant: no pulsing between steps.

Usage: render-frames.py LOGOMARK_SVG OUT_DIR
"""

import math
import re
import sys

from frames import LOGO_RADIUS, read_logomark, render, ticks

STEP_SECONDS = 0.25  # time for the light to move on to the next lambda
LEAD_STEPS = 0.3  # softness of the light's leading edge, in lambdas
TRAIL_STEPS = 0.9  # fade length of the tail behind the light, in lambdas

DIM = 0.22  # opacity of an unlit lambda
GLOW_COLOR = "#8fd0ff"
GLOW_OPACITY = 1.0  # halo strength at full intensity
SPILL_OPACITY = 0.25  # halo light drawn over the lambdas, lighting up neighbours
CORE_OPACITY = 0.3  # white tint over a fully lit lambda
WIDE_BLUR = 150  # halo blur radii, in logomark units (circumradius 1152)
TIGHT_BLUR = 45

# Room for the halo around the logo.
CANVAS_RADIUS = LOGO_RADIUS * 1.35


def comet(u):
    """Light at `u` lambdas behind the head (negative = ahead): soft front, long tail."""
    if u < 0:
        return math.exp(-((u / LEAD_STEPS) ** 2))
    return math.exp(-u / TRAIL_STEPS)


def make_intensity(samples=400):
    """Brightness 0..1 of a lambda `x` lambdas behind the head (periodic over 6).

    Each lambda collects the comet's light over a one-lambda-wide window. The
    six windows tile the circle, so the lambdas' brightness always sums to the
    same total and the light hands over smoothly from one lambda to the next.
    """

    def raw(x):
        total = 0.0
        for k in range(samples):
            u = x - 0.5 + (k + 0.5) / samples
            # Wrap around the six lambdas so the tail joins the leading edge.
            total += sum(comet(u + 6 * w) for w in (-1, 0, 1))
        return total / samples

    peak = max(raw(i / 50) for i in range(-50, 50))

    def intensity(x):
        return min(1.0, raw((x + 3) % 6 - 3) / peak)

    return intensity


def timeline():
    """Yield the six lambda intensities for each tick of one lap."""
    intensity = make_intensity()
    n = 6 * ticks(STEP_SECONDS)
    for t in range(n):
        head = 6 * t / n
        yield tuple(round(intensity(head - i), 3) for i in range(6))


def main(logomark_path, out_dir):
    defs, polygons = read_logomark(logomark_path)
    glow_shapes = [re.sub(r'fill="[^"]*"', f'fill="{GLOW_COLOR}"', p) for p in polygons]
    core_shapes = [re.sub(r'fill="[^"]*"', 'fill="#ffffff"', p) for p in polygons]
    r = CANVAS_RADIUS
    bloom = (
        f'<filter id="bloom" filterUnits="userSpaceOnUse" '
        f'x="{-r}" y="{-r}" width="{2 * r}" height="{2 * r}">'
        f'<feGaussianBlur in="SourceGraphic" stdDeviation="{WIDE_BLUR}" result="wide"/>'
        f'<feGaussianBlur in="SourceGraphic" stdDeviation="{TIGHT_BLUR}" result="tight"/>'
        f'<feMerge><feMergeNode in="wide"/><feMergeNode in="wide"/>'
        f'<feMergeNode in="tight"/></feMerge>'
        f"</filter>"
    )

    def svg_for(levels):
        # Halos under everything, then the lambdas, then the white "hot" tint and
        # a fainter copy of the halos over the top so light spills onto neighbours.
        def halos(strength):
            return "".join(
                f'<g filter="url(#bloom)" opacity="{strength * level:.3f}">{shape}</g>'
                for shape, level in zip(glow_shapes, levels)
                if level > 0.01
            )

        bodies = "".join(
            f'<g opacity="{DIM + (1 - DIM) * level:.3f}">{shape}</g>'
            for shape, level in zip(polygons, levels)
        )
        cores = "".join(
            f'<g opacity="{CORE_OPACITY * level * level:.3f}">{shape}</g>'
            for shape, level in zip(core_shapes, levels)
            if level > 0.01
        )
        return (
            f"<defs>{bloom}</defs>{defs}"
            f"{halos(GLOW_OPACITY)}{bodies}{cores}{halos(SPILL_OPACITY)}"
        )

    render(out_dir, timeline(), svg_for, canvas_radius=CANVAS_RADIUS)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
