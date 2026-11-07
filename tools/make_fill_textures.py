"""Generates the fill textures of Core/Looks.lua into Core/Textures/Fill/*.tga.

    python tools/make_fill_textures.py        (the extra generators live in tools/fill_patterns_extra.py)

Pure standard library (uncompressed 32-bit TGA, top-left origin). Every file is white (or grey, where the shading is
the point) with the pattern in the alpha channel and/or the luminance, so a vertex colour tints it. Tiled patterns
repeat seamlessly in both directions; the "soft" ones are meant to be stretched over a bar. Sizes are powers of two.
"""
import math
import os
import random
import struct

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Core", "Textures", "Fill")


def save(name, w, h, fn):
    os.makedirs(OUT, exist_ok=True)
    data = bytearray()
    for y in range(h):
        for x in range(w):
            out = fn(x, y, w, h)
            if len(out) == 4:
                rr, gg, bb, alpha = out
            else:
                rr = gg = bb = out[0]
                alpha = out[1]
            c = lambda v: max(0, min(255, int(round(v * 255))))
            data += bytes((c(bb), c(gg), c(rr), c(alpha)))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
    with open(os.path.join(OUT, "Fill_%s.tga" % name), "wb") as f:
        f.write(header + bytes(data))


def smooth(d, edge=0.75):
    """1 inside, 0 outside, a soft edge of `edge` px (d = signed distance, negative inside)."""
    return max(0.0, min(1.0, 0.5 - d / (2 * edge)))


def wrapd(a, b, period):
    d = abs(a - b) % period
    return min(d, period - d)


# ---------------------------------------------------------------- tiled patterns
def stripes_back(x, y, w, h):          # the other diagonal than DoTInfo's Stripes
    return 1, 1.0 if ((x + y) % 8) < 4 else 0.0


def stripes_wide(x, y, w, h):
    return 1, 1.0 if ((x - y) % 16) < 8 else 0.0


def crosshatch(x, y, w, h):
    on = ((x - y) % 8) < 2 or ((x + y) % 8) < 2
    return 1, 1.0 if on else 0.0


def dots(x, y, w, h):
    d = math.hypot(wrapd(x + .5, w / 2, w), wrapd(y + .5, h / 2, h)) - 1.7
    return 1, smooth(d)


def dots_big(x, y, w, h):
    d = math.hypot(wrapd(x + .5, w / 2, w), wrapd(y + .5, h / 2, h)) - 4.5
    return 1, smooth(d)


def checker(x, y, w, h):
    return 1, 1.0 if ((x // 8) + (y // 8)) % 2 == 0 else 0.0


def grid(x, y, w, h):
    return 1, 1.0 if (x % 8) < 1 or (y % 8) < 1 else 0.0


def scanlines(x, y, w, h):
    return 1, 1.0 if y % 4 == 0 else 0.0


def zigzag(x, y, w, h):
    center = abs((x % 16) - 8) + 4
    return 1, 1.0 if abs(y - center) < 2 else 0.0


def chevron(x, y, w, h):
    center = abs((x % 16) - 8)
    d = min(wrapd(y, center, h), wrapd(y, center + 8, h))
    return 1, smooth(d - 2.2)


def carbon(x, y, w, h):
    cell = ((x // 4) + (y // 4)) % 2
    fx, fy = (x % 4) / 3.0, (y % 4) / 3.0
    shade = fx if cell == 0 else fy
    return 0.38 + 0.4 * shade, 1.0


def diamonds(x, y, w, h):
    d = abs(wrapd(x + .5, w / 2, w)) + abs(wrapd(y + .5, h / 2, h)) - 6.0
    return 1, smooth(d)


def waves(x, y, w, h):
    center = h / 2 + 4 * math.sin(2 * math.pi * x / w)
    return 1, smooth(abs(y + .5 - center) - 1.5)


def bricks(x, y, w, h):
    row = y // 8
    shift = 0 if row % 2 == 0 else 8
    line = (y % 8) < 1 or ((x + shift) % 16) < 1
    return 1, 1.0 if line else 0.0


def make_noise():
    random.seed(7)
    n = 64
    grid_ = [[random.random() for _ in range(n)] for _ in range(n)]
    for _ in range(2):
        grid_ = [[sum(grid_[(y + dy) % n][(x + dx) % n] for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9
                  for x in range(n)] for y in range(n)]
    lo = min(min(r) for r in grid_)
    hi = max(max(r) for r in grid_)

    def noise(x, y, w, h):
        v = (grid_[y][x] - lo) / (hi - lo)
        return 1, 0.15 + 0.85 * v
    return noise


def make_brushed():
    random.seed(11)
    w, h = 64, 8
    rows = []
    for _ in range(h):
        row = [random.random() for _ in range(w)]
        for _ in range(3):
            row = [(row[(x - 1) % w] + row[x] + row[(x + 1) % w]) / 3 for x in range(w)]
        rows.append(row)
    lo = min(min(r) for r in rows)
    hi = max(max(r) for r in rows)

    def brushed(x, y, ww, hh):
        v = (rows[y][x] - lo) / (hi - lo)
        return 0.55 + 0.45 * v, 1.0
    return brushed


# ---------------------------------------------------------------- soft shading (stretched over the bar)
def vert(fn):
    return lambda x, y, w, h: fn(y / float(h - 1))


def gloss(v):          # glass: a light top half, a darker bottom half
    return (1.0 - 0.18 * v / 0.5, 1.0) if v < 0.5 else (0.62 - 0.22 * (v - 0.5) / 0.5, 1.0)


def bevel(v):          # light top edge fading to a darker bottom
    return 1.0 - 0.5 * v, 1.0


def cylinder(v):       # bright through the middle, dark at both edges
    return 0.4 + 0.6 * math.sin(math.pi * v), 1.0


def inset(v):          # dark top, light bottom
    return 0.5 + 0.5 * v, 1.0


def edge_glow(v):      # bright rim top and bottom, clear in the middle
    return 1.0, 0.18 + 0.82 * abs(2 * v - 1) ** 3


def top_shine(v):      # a hard highlight on the upper third
    return 1.0, 0.85 if v < 0.38 else 0.3


def fade_right(x, y, w, h):     # opaque on the left, clear at the right edge
    return 1, 1.0 - x / float(w - 1)


def fade_left(x, y, w, h):      # clear on the left, opaque at the right edge
    return 1, x / float(w - 1)


def fade_both(x, y, w, h):
    return 1, math.sin(math.pi * x / float(w - 1))


TILED = [
    ("stripes_back", 16, 16, stripes_back), ("stripes_wide", 32, 32, stripes_wide), ("crosshatch", 16, 16, crosshatch),
    ("dots", 8, 8, dots), ("dots_big", 16, 16, dots_big), ("checker", 16, 16, checker), ("grid", 16, 16, grid),
    ("scanlines", 4, 4, scanlines), ("zigzag", 16, 16, zigzag), ("chevron", 16, 16, chevron),
    ("carbon", 8, 8, carbon), ("diamonds", 16, 16, diamonds), ("waves", 32, 16, waves), ("bricks", 32, 16, bricks),
    ("noise", 64, 64, make_noise()), ("brushed", 64, 8, make_brushed()),
]
SOFT = [
    ("gloss", 4, 64, vert(gloss)), ("bevel", 4, 64, vert(bevel)), ("cylinder", 4, 64, vert(cylinder)),
    ("inset", 4, 64, vert(inset)), ("edge_glow", 4, 64, vert(edge_glow)), ("top_shine", 4, 64, vert(top_shine)),
    ("fade_right", 64, 4, fade_right), ("fade_left", 64, 4, fade_left), ("fade_both", 64, 4, fade_both),
]

from fill_patterns_extra import TILED_EXTRA, SOFT_EXTRA, COLOR_EXTRA  # noqa: E402

if __name__ == "__main__":
    for name, w, h, fn in TILED + SOFT + TILED_EXTRA + SOFT_EXTRA + COLOR_EXTRA:
        save(name, w, h, fn)
    print("wrote %d textures to %s" % (len(TILED + SOFT + TILED_EXTRA + SOFT_EXTRA + COLOR_EXTRA), os.path.normpath(OUT)))
