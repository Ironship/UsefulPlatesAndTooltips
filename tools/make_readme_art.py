"""Generates 16-bit pixel-art banners, section header plaques, and art-style showcase
graphics for README.md and CURSEFORGE.md inside docs/images/.

Draws scenes on exact 16-bit native pixel grids alongside downsampled real
*_px.tga textures from the addon, upscales nearest-neighbor 3x, and composites
smooth Stylized 2D TGAs where appropriate (art-styles-showcase.png).

    python tools/make_readme_art.py
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "docs" / "images"

# ---------------------------------------------------------------------------
# Color Palette (Deep Obsidian, Antique Gold, Forged Steel, Arcane/Combat Accents)
# ---------------------------------------------------------------------------
TRANSPARENT = (0, 0, 0, 0)
OBSIDIAN = (14, 10, 18, 255)
OBSIDIAN_PANEL = (18, 14, 28, 255)
OBSIDIAN_RECESS = (12, 9, 20, 255)
NIGHT_BOT = (11, 8, 19, 255)
NIGHT_MID = (20, 15, 34, 255)
NIGHT_TOP = (30, 21, 50, 255)

GOLD_SPEC = (255, 244, 194, 255)
GOLD_LIGHT = (248, 208, 92, 255)
GOLD_MID = (206, 152, 42, 255)
GOLD_DARK = (138, 92, 22, 255)
GOLD_SHADOW = (86, 52, 14, 255)

STEEL_LIGHT = (196, 206, 224, 255)
STEEL_MID = (132, 142, 166, 255)
STEEL_DARK = (74, 80, 102, 255)
STEEL_SHADOW = (42, 44, 62, 255)

SILVER_LIGHT = (232, 238, 252, 255)
SILVER_MID = (176, 186, 212, 255)
SILVER_DARK = (116, 124, 152, 255)

CRIMSON_HI = (255, 118, 104, 255)
CRIMSON = (224, 48, 52, 255)
CRIMSON_DK = (142, 22, 28, 255)

PURPLE_HI = (230, 156, 255, 255)
PURPLE = (176, 66, 238, 255)
PURPLE_DK = (108, 28, 164, 255)

GREEN_HI = (144, 255, 168, 255)
GREEN = (48, 218, 98, 255)
GREEN_DK = (20, 134, 54, 255)

CYAN_HI = (164, 244, 255, 255)
CYAN = (64, 206, 248, 255)
CYAN_DK = (26, 122, 174, 255)

AMBER_HI = (255, 218, 108, 255)
AMBER = (242, 154, 34, 255)
AMBER_DK = (158, 76, 16, 255)

BLUE_HI = (152, 204, 255, 255)
BLUE = (68, 136, 238, 255)
BLUE_DK = (32, 74, 154, 255)

# ---------------------------------------------------------------------------
# Proportional 7px-tall RPG Bitmap Font (4-6px wide + 1px spacing)
# ---------------------------------------------------------------------------
FONT_5X7 = {
    "A": [
        ".###.",
        "#...#",
        "#...#",
        "#####",
        "#...#",
        "#...#",
        "#...#",
    ],
    "B": [
        "####.",
        "#...#",
        "#...#",
        "####.",
        "#...#",
        "#...#",
        "####.",
    ],
    "C": [
        ".####",
        "#....",
        "#....",
        "#....",
        "#....",
        "#....",
        ".####",
    ],
    "D": [
        "####.",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "####.",
    ],
    "E": [
        "#####",
        "#....",
        "#....",
        "####.",
        "#....",
        "#....",
        "#####",
    ],
    "F": [
        "#####",
        "#....",
        "#....",
        "####.",
        "#....",
        "#....",
        "#....",
    ],
    "G": [
        ".####",
        "#....",
        "#....",
        "#.###",
        "#...#",
        "#...#",
        ".####",
    ],
    "H": [
        "#...#",
        "#...#",
        "#...#",
        "#####",
        "#...#",
        "#...#",
        "#...#",
    ],
    "I": [
        "###",
        ".#.",
        ".#.",
        ".#.",
        ".#.",
        ".#.",
        "###",
    ],
    "J": [
        "..###",
        "...#.",
        "...#.",
        "...#.",
        "#..#.",
        "#..#.",
        ".##..",
    ],
    "K": [
        "#...#",
        "#..#.",
        "#.#..",
        "##...",
        "#.#..",
        "#..#.",
        "#...#",
    ],
    "L": [
        "#....",
        "#....",
        "#....",
        "#....",
        "#....",
        "#....",
        "#####",
    ],
    "M": [
        "#...#",
        "##.##",
        "#.#.#",
        "#.#.#",
        "#...#",
        "#...#",
        "#...#",
    ],
    "N": [
        "#...#",
        "##..#",
        "#.#.#",
        "#..##",
        "#...#",
        "#...#",
        "#...#",
    ],
    "O": [
        ".###.",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        ".###.",
    ],
    "P": [
        "####.",
        "#...#",
        "#...#",
        "####.",
        "#....",
        "#....",
        "#....",
    ],
    "Q": [
        ".###.",
        "#...#",
        "#...#",
        "#...#",
        "#.#.#",
        "#..#.",
        ".##.#",
    ],
    "R": [
        "####.",
        "#...#",
        "#...#",
        "####.",
        "#.#..",
        "#..#.",
        "#...#",
    ],
    "S": [
        ".####",
        "#....",
        "#....",
        ".###.",
        "....#",
        "....#",
        "####.",
    ],
    "T": [
        "#####",
        "..#..",
        "..#..",
        "..#..",
        "..#..",
        "..#..",
        "..#..",
    ],
    "U": [
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        ".###.",
    ],
    "V": [
        "#...#",
        "#...#",
        "#...#",
        "#...#",
        ".#.#.",
        ".#.#.",
        "..#..",
    ],
    "W": [
        "#...#",
        "#...#",
        "#...#",
        "#.#.#",
        "#.#.#",
        "##.##",
        "#...#",
    ],
    "X": [
        "#...#",
        "#...#",
        ".#.#.",
        "..#..",
        ".#.#.",
        "#...#",
        "#...#",
    ],
    "Y": [
        "#...#",
        "#...#",
        ".#.#.",
        "..#..",
        "..#..",
        "..#..",
        "..#..",
    ],
    "Z": [
        "#####",
        "....#",
        "...#.",
        "..#..",
        ".#...",
        "#....",
        "#####",
    ],
    "0": [
        ".###.",
        "#...#",
        "#..##",
        "#.#.#",
        "##..#",
        "#...#",
        ".###.",
    ],
    "1": [
        ".##..",
        "###..",
        ".##..",
        ".##..",
        ".##..",
        ".##..",
        "####.",
    ],
    "2": [
        ".###.",
        "#...#",
        "....#",
        "..##.",
        ".#...",
        "#....",
        "#####",
    ],
    "3": [
        "####.",
        "....#",
        "....#",
        ".###.",
        "....#",
        "....#",
        "####.",
    ],
    "4": [
        "...#.",
        "..##.",
        ".#.#.",
        "#..#.",
        "#####",
        "...#.",
        "...#.",
    ],
    "5": [
        "#####",
        "#....",
        "####.",
        "....#",
        "....#",
        "#...#",
        ".###.",
    ],
    "6": [
        ".###.",
        "#....",
        "####.",
        "#...#",
        "#...#",
        "#...#",
        ".###.",
    ],
    "7": [
        "#####",
        "....#",
        "...#.",
        "..#..",
        ".#...",
        ".#...",
        ".#...",
    ],
    "8": [
        ".###.",
        "#...#",
        "#...#",
        ".###.",
        "#...#",
        "#...#",
        ".###.",
    ],
    "9": [
        ".###.",
        "#...#",
        "#...#",
        ".####",
        "....#",
        "...#.",
        ".##..",
    ],
    "&": [
        ".##..",
        "#..#.",
        "#.#..",
        ".#...",
        "#.#.#",
        "#..#.",
        ".##.#",
    ],
    ":": [
        "..",
        "##",
        "##",
        "..",
        "##",
        "##",
        "..",
    ],
    ",": [
        "..",
        "..",
        "..",
        "..",
        "##",
        ".#",
        "#.",
    ],
    ".": [
        "..",
        "..",
        "..",
        "..",
        "..",
        "##",
        "##",
    ],
    "-": [
        "...",
        "...",
        "...",
        "###",
        "...",
        "...",
        "...",
    ],
    "+": [
        "...",
        ".#.",
        ".#.",
        "###",
        ".#.",
        ".#.",
        "...",
    ],
    "/": [
        "...#",
        "...#",
        "..#.",
        ".#..",
        ".#..",
        "#...",
        "#...",
    ],
    "!": [
        "##",
        "##",
        "##",
        "##",
        "..",
        "##",
        "##",
    ],
    "(": [
        ".#",
        "#.",
        "#.",
        "#.",
        "#.",
        "#.",
        ".#",
    ],
    ")": [
        "#.",
        ".#",
        ".#",
        ".#",
        ".#",
        ".#",
        "#.",
    ],
    ">": [
        "#..",
        ".#.",
        "..#",
        "..#",
        ".#.",
        "#..",
        "...",
    ],
    "*": [
        "...",
        "#.#",
        ".#.",
        "###",
        ".#.",
        "#.#",
        "...",
    ],
    " ": [
        "...",
        "...",
        "...",
        "...",
        "...",
        "...",
        "...",
    ],
}

# Heavy 9px-tall RPG Hero Title Font (with chunky 2px stems & subtle serif tips)
FONT_HERO = {
    "D": [
        "#####..",
        "##..##.",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##..##.",
        "#####..",
    ],
    "O": [
        ".#####.",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        ".#####.",
    ],
    "E": [
        "#######",
        "##.....",
        "##.....",
        "######.",
        "##.....",
        "##.....",
        "##.....",
        "##.....",
        "#######",
    ],
    "S": [
        ".######",
        "##.....",
        "##.....",
        ".#####.",
        ".....##",
        ".....##",
        ".....##",
        "##...##",
        ".#####.",
    ],
    "I": [
        "####",
        ".##.",
        ".##.",
        ".##.",
        ".##.",
        ".##.",
        ".##.",
        ".##.",
        "####",
    ],
    "T": [
        "######",
        "..##..",
        "..##..",
        "..##..",
        "..##..",
        "..##..",
        "..##..",
        "..##..",
        "..##..",
    ],
    "P": [
        "######.",
        "##...##",
        "##...##",
        "##...##",
        "######.",
        "##.....",
        "##.....",
        "##.....",
        "##.....",
    ],
    "L": [
        "##.....",
        "##.....",
        "##.....",
        "##.....",
        "##.....",
        "##.....",
        "##.....",
        "##.....",
        "#######",
    ],
    "U": [
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        "##...##",
        ".#####.",
    ],
    " ": [
        "....",
    ] * 9,
}

GOLD_GRAD_7 = [
    (255, 248, 212, 255),
    (255, 232, 146, 255),
    (252, 206, 86, 255),
    (240, 180, 52, 255),
    (216, 148, 34, 255),
    (184, 114, 24, 255),
    (150, 86, 18, 255),
]

GOLD_GRAD_9 = [
    (255, 252, 224, 255),
    (255, 240, 172, 255),
    (255, 220, 108, 255),
    (248, 198, 72, 255),
    (234, 172, 46, 255),
    (216, 146, 32, 255),
    (194, 120, 22, 255),
    (168, 96, 16, 255),
    (138, 74, 12, 255),
]

SILVER_GRAD_7 = [
    (246, 248, 255, 255),
    (226, 232, 248, 255),
    (204, 214, 236, 255),
    (182, 194, 222, 255),
    (158, 170, 200, 255),
    (132, 144, 176, 255),
    (108, 118, 148, 255),
]


def measure_text(text, font=FONT_5X7, scale=1, gap=1):
    w = 0
    for i, ch in enumerate(text.upper()):
        glyph = font[ch]
        w += len(glyph[0]) * scale
        if i + 1 < len(text):
            w += gap * scale
    return w


def draw_pixel_text(img, x, y, text, grad=GOLD_GRAD_7, font=FONT_5X7, scale=1, gap=1,
                    outline=OBSIDIAN, shadow=(8, 5, 12, 220)):
    px = img.load()
    w_img, h_img = img.size
    fg_pixels = []
    cx = x
    for ch in text.upper():
        glyph = font[ch]
        gw = len(glyph[0])
        gh = len(glyph)
        for gy in range(gh):
            row = glyph[gy]
            for gx in range(gw):
                if row[gx] == "#":
                    col = grad[min(gy, len(grad) - 1)]
                    for sy in range(scale):
                        for sx in range(scale):
                            fg_pixels.append((cx + gx * scale + sx, y + gy * scale + sy, col))
        cx += (gw + gap) * scale

    fg_set = {(px_x, px_y) for px_x, px_y, _ in fg_pixels}

    def put_blend(tx, ty, c):
        if 0 <= tx < w_img and 0 <= ty < h_img:
            if c[3] == 255:
                px[tx, ty] = c
            else:
                br, bg, bb, ba = px[tx, ty]
                a = c[3] / 255.0
                ia = 1.0 - a
                nr = int(c[0] * a + br * ia)
                ng = int(c[1] * a + bg * ia)
                nb = int(c[2] * a + bb * ia)
                na = max(ba, c[3])
                px[tx, ty] = (nr, ng, nb, na)

    if shadow:
        off = scale
        for fx, fy, _ in fg_pixels:
            for dx in range(-1, 2):
                for dy in range(-1, 2):
                    put_blend(fx + dx + off, fy + dy + off, shadow)

    if outline:
        offsets = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)]
        for fx, fy, _ in fg_pixels:
            for dx, dy in offsets:
                if (fx + dx, fy + dy) not in fg_set:
                    put_blend(fx + dx, fy + dy, outline)

    for fx, fy, col in fg_pixels:
        put_blend(fx, fy, col)

    return cx - gap * scale - x


# ---------------------------------------------------------------------------
# Dithered Backgrounds, Ornate RPG Borders & Primitives
# ---------------------------------------------------------------------------
BAYER_4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]


def composite_rect(img, box, fill=None, outline=None):
    """Alpha-composite a translucent rectangle onto `img`."""
    layer = Image.new("RGBA", img.size, TRANSPARENT)
    d = ImageDraw.Draw(layer)
    d.rectangle(box, fill=fill, outline=outline)
    img.alpha_composite(layer)


def draw_dither_halo(img, cx, cy, rx, ry, color_rgb, max_alpha=95):
    """Draw a stepped 16-bit Bayer-dithered radial pixel glow (zero flat circles)."""
    px = img.load()
    w, h = img.size
    cr, cg, cb = color_rgb
    x0 = max(3, int(cx - rx - 1))
    x1 = min(w - 4, int(cx + rx + 2))
    y0 = max(3, int(cy - ry - 1))
    y1 = min(h - 4, int(cy + ry + 2))
    for y in range(y0, y1):
        for x in range(x0, x1):
            dist = (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2) ** 0.5
            if dist >= 1.0:
                continue
            strength = (1.0 - dist) ** 1.35
            threshold = (BAYER_4[y & 3][x & 3] + 0.5) / 16.0
            if strength * 1.15 > threshold:
                a = max_alpha * (0.45 + 0.55 * strength) / 255.0
                br, bg, bb, ba = px[x, y]
                if ba > 0:
                    ia = 1.0 - a
                    px[x, y] = (
                        min(255, int(cr * a + br * ia)),
                        min(255, int(cg * a + bg * ia)),
                        min(255, int(cb * a + bb * ia)),
                        ba,
                    )


def fill_dither_grad(img, box, stops, vertical=True):
    """Fill `box` with 4x4 ordered Bayer dithering across `stops` [(t, (r,g,b,a)), ...]."""
    x0, y0, x1, y1 = box
    px = img.load()
    span = max(1, (y1 - y0 - 1) if vertical else (x1 - x0 - 1))
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = ((y - y0) if vertical else (x - x0)) / span
            t = max(0.0, min(1.0, t))
            seg = 0
            while seg + 1 < len(stops) - 1 and t > stops[seg + 1][0]:
                seg += 1
            t0, c0 = stops[seg]
            t1, c1 = stops[seg + 1]
            local = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            threshold = (BAYER_4[y & 3][x & 3] + 0.5) / 16.0
            px[x, y] = c1 if local > threshold else c0


def draw_beveled_frame(img, box=None, chamfer=2, gold=True):
    """Draw a chamfered 16-bit beveled RPG frame with corner rivets."""
    x0, y0, x1, y1 = box or (0, 0, img.width, img.height)
    px = img.load()
    hi = GOLD_LIGHT if gold else STEEL_LIGHT
    spec = GOLD_SPEC if gold else SILVER_LIGHT
    mid = GOLD_MID if gold else STEEL_MID
    dk = GOLD_DARK if gold else STEEL_DARK
    sh = GOLD_SHADOW if gold else STEEL_SHADOW

    # Outer silhouette clearance + obsidian rim + bright/dark bevel + inner rim
    for y in range(y0, y1):
        for x in range(x0, x1):
            dx = min(x - x0, x1 - 1 - x)
            dy = min(y - y0, y1 - 1 - y)
            if chamfer and (dx + dy < chamfer):
                px[x, y] = TRANSPARENT
                continue
            d = min(dx, dy)
            is_chamfer_edge = chamfer and (dx + dy == chamfer)
            is_chamfer_inner = chamfer and (dx + dy == chamfer + 1)
            if d == 0 or is_chamfer_edge:
                px[x, y] = OBSIDIAN
            elif d == 1 or is_chamfer_inner:
                top_left = (y - y0 <= 2) or (x - x0 <= 2)
                bottom_right = (y1 - 1 - y <= 1) or (x1 - 1 - x <= 1)
                if bottom_right and not (x - x0 == 1 and y - y0 == 1):
                    px[x, y] = dk
                elif top_left:
                    px[x, y] = hi
                else:
                    px[x, y] = mid
            elif d == 2:
                bottom_right = (y1 - 1 - y == 2) or (x1 - 1 - x == 2)
                px[x, y] = sh if bottom_right else mid
            elif d == 3:
                px[x, y] = OBSIDIAN

    # Corner studs / rivets
    inset = chamfer + 2
    corners = [
        (x0 + inset, y0 + inset),
        (x1 - 1 - inset, y0 + inset),
        (x0 + inset, y1 - 1 - inset),
        (x1 - 1 - inset, y1 - 1 - inset),
    ]
    for rx, ry in corners:
        for oy in range(-1, 2):
            for ox in range(-1, 2):
                if abs(ox) == 1 and abs(oy) == 1:
                    continue
                tx, ty = rx + ox, ry + oy
                if x0 <= tx < x1 and y0 <= ty < y1:
                    px[tx, ty] = OBSIDIAN
        px[rx, ry] = spec
        if rx + 1 < x1:
            px[rx + 1, ry] = mid
        if ry + 1 < y1:
            px[rx, ry + 1] = mid


def draw_sparkle(img, x, y, core, arm, big=False):
    px = img.load()
    w, h = img.size

    def p(tx, ty, c):
        if 0 <= tx < w and 0 <= ty < h:
            px[tx, ty] = c

    p(x, y, core)
    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        p(x + ox, y + oy, arm)
    if big:
        for ox, oy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            p(x + ox, y + oy, (arm[0], arm[1], arm[2], 140))


# ---------------------------------------------------------------------------
# Addon Sprite Helpers
# ---------------------------------------------------------------------------
def load_px_sprite(rel_path, native_size=16):
    im = Image.open(ROOT / rel_path).convert("RGBA")
    return im.resize((native_size, native_size), Image.NEAREST)


def load_2d_sprite(rel_path, size=48):
    im = Image.open(ROOT / rel_path).convert("RGBA")
    return im.resize((size, size), Image.LANCZOS)


def tint_image(im, rgb):
    r_t, g_t, b_t = rgb
    src = im.copy()
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (int(r * r_t / 255), int(g * g_t / 255), int(b * b_t / 255), a)
    return src


def make_px_shard(with_glow=True):
    gem = load_px_sprite("Modules/ResourceDing/Textures/ShardGem_px.tga", 16)
    bezel = load_px_sprite("Modules/ResourceDing/Textures/ShardBezel_px.tga", 16)
    if not with_glow:
        out = Image.new("RGBA", (16, 16), TRANSPARENT)
        out.alpha_composite(gem, (0, 0))
        out.alpha_composite(bezel, (0, 0))
        return out
    glow = load_px_sprite("Modules/ResourceDing/Textures/ShardGlow_px.tga", 32)
    out = Image.new("RGBA", (32, 32), TRANSPARENT)
    out.alpha_composite(glow, (0, 0))
    out.alpha_composite(gem, (8, 8))
    out.alpha_composite(bezel, (8, 8))
    return out


def make_2d_shard(size=54):
    glow = load_2d_sprite("Modules/ResourceDing/Textures/ShardGlow.tga", size)
    gem = load_2d_sprite("Modules/ResourceDing/Textures/ShardGem.tga", int(size * 0.66))
    bezel = load_2d_sprite("Modules/ResourceDing/Textures/ShardBezel.tga", int(size * 0.66))
    off = (size - gem.width) // 2
    out = Image.new("RGBA", (size, size), TRANSPARENT)
    out.alpha_composite(glow, (0, 0))
    out.alpha_composite(gem, (off, off))
    out.alpha_composite(bezel, (off, off))
    return out


def make_px_combo(rgb=(245, 72, 68)):
    orb = tint_image(load_px_sprite("Modules/ResourceDing/Textures/ComboOrb_px.tga", 16), rgb)
    ring = load_px_sprite("Modules/ResourceDing/Textures/ComboRing_px.tga", 16)
    out = Image.new("RGBA", (16, 16), TRANSPARENT)
    out.alpha_composite(orb, (0, 0))
    out.alpha_composite(ring, (0, 0))
    return out


def make_2d_combo(size=44, rgb=(245, 72, 68)):
    orb = tint_image(load_2d_sprite("Modules/ResourceDing/Textures/ComboOrb.tga", size), rgb)
    ring = load_2d_sprite("Modules/ResourceDing/Textures/ComboRing.tga", size)
    out = Image.new("RGBA", (size, size), TRANSPARENT)
    out.alpha_composite(orb, (0, 0))
    out.alpha_composite(ring, (0, 0))
    return out


def make_px_diamond(rgb=(255, 208, 64)):
    gem = tint_image(load_px_sprite("Core/Textures/MarkerDiamond_px.tga", 16), rgb)
    bezel = load_px_sprite("Core/Textures/MarkerDiamondBezel_px.tga", 16)
    out = Image.new("RGBA", (16, 16), TRANSPARENT)
    out.alpha_composite(gem, (0, 0))
    out.alpha_composite(bezel, (0, 0))
    return out


# ---------------------------------------------------------------------------
# Custom Pixel Art Illustrations (16-bit Gamepad, Health/Cast/DoT Bars, Silhouettes)
# ---------------------------------------------------------------------------
GAMEPAD_GRID = [
    "..........KKKKKK..........................KKKKKK..........",
    ".........KGGGGGGK........................KGGGGGGK.........",
    "......KKKKKKKKKKKKKK..................KKKKKKKKKKKKKK......",
    "....KKSSSSSSSSSSSSSSKKKKKKKKKKKKKKKKKKSSSSSSSSSSSSSSKK....",
    "...KSSddddddddddddddddddddddddddddddddddddddddddddddSSK...",
    "..KSdddddddKKKKddddddddddddddddddddddddddddKKKKdddddddpK..",
    ".KSddddddddKllKddddddddddddddddddddddddddddKGWKddddddddpK.",
    ".KSddddKKKKllllKKKKddddddddddddddddddddKKKKKggKKKKKddddpK.",
    ".KSddddKlWWlWWlmllKddddddddddddddddddddKBWKKKKKKRWKddddpK.",
    ".KSddddKmmmmlmmmmmKddddKKKdKKKKdKKKddddKbbKKYWKKrrKddddpK.",
    ".KSddddKKKKmmmmKKKKddddKsKdKGGKdKsKddddKKKKKyyKKKKKddddpK.",
    ".KSddddddddKmmKddddddddKKKdKKKKdKKKddddddddKKKKddddddddpK.",
    ".KSddddddddKKKKddddddddddddddddddddddddddddddddddddddddpK.",
    ".KSddddddddddddddddddddddddddddddddddddddddddddddddddddpK.",
    ".KSddddddddddddddddKKKKKKddddddddKKKKKKddddddddddddddddpK.",
    ".KSdddddddddddddddKssssssKddddddKssssssKdddddddddddddddpK.",
    ".KSdddddddddddddddKsppppsKddddddKsppppsKdddddddddddddddpK.",
    ".KpdddddddddddddddKspddmpKddddddKspddmpKdddddddddddddddpK.",
    ".KpdddddddddddddddKspdddpKddddddKspdddpKdddddddddddddddpK.",
    "..KpdddddddddddddKspppdpKddddddddKspppdpKdddddddddddddpK..",
    "..KpddddddddddddddKppppKddddddddddKppppKddddddddddddddpK..",
    "..KpdddddddddddddddKKKKddddddddddddKKKKdddddddddddddddpK..",
    "...KpddddddddddddddddddddddddddddddddddddddddddddddddpK...",
    "...KppddddddddddddddKKKKKKKKKKKKKKKKKKddddddddddddddppK...",
    "....KppddddddddddKK....................KKddddddddddppK....",
    "....KpppdddddddddK......................KdddddddddpppK....",
    ".....KpppdddddddK........................KdddddddpppK.....",
    "......KppppddddK..........................KddddppppK......",
    ".......KKKKKKKpK..........................KpKKKKKKK.......",
    "..........KKKK..............................KKKK..........",
]
assert all(len(row) == 58 for row in GAMEPAD_GRID), "GAMEPAD_GRID width mismatch"

GAMEPAD_PAL = {
    ".": TRANSPARENT,
    "K": OBSIDIAN,
    "S": (152, 164, 194, 255),
    "s": (106, 116, 144, 255),
    "d": (56, 60, 80, 255),
    "p": (34, 36, 52, 255),
    "l": (200, 210, 232, 255),
    "m": (122, 132, 158, 255),
    "W": (248, 252, 255, 255),
    "G": (248, 204, 70, 255),
    "g": (186, 132, 28, 255),
    "B": (72, 154, 255, 255),
    "b": (32, 92, 186, 255),
    "R": (244, 58, 66, 255),
    "r": (164, 26, 34, 255),
    "Y": (62, 226, 112, 255),
    "y": (26, 146, 62, 255),
}

MINI_ORB_GRID = [
    "..KKKKK..",
    ".KWllmmK.",
    "KWWllmmmK",
    "KWllmmmmK",
    "KllmmmmdK",
    "KmmmmdddK",
    "KmmmdddDK",
    ".KmddDDK.",
    "..KKKKK..",
]
assert all(len(row) == 9 for row in MINI_ORB_GRID), "MINI_ORB_GRID width mismatch"

MINI_ORB_PALS = [
    {  # Purple Shadow / Shard
        ".": TRANSPARENT, "K": OBSIDIAN, "W": (252, 232, 255, 255),
        "l": (222, 128, 255, 255), "m": (176, 62, 236, 255),
        "d": (118, 28, 176, 255), "D": (72, 14, 116, 255),
    },
    {  # Crimson Blood / Fire
        ".": TRANSPARENT, "K": OBSIDIAN, "W": (255, 224, 218, 255),
        "l": (255, 116, 104, 255), "m": (222, 46, 52, 255),
        "d": (152, 22, 28, 255), "D": (92, 12, 18, 255),
    },
    {  # Antique Gold Combo
        ".": TRANSPARENT, "K": OBSIDIAN, "W": (255, 250, 214, 255),
        "l": (252, 214, 96, 255), "m": (228, 162, 38, 255),
        "d": (162, 98, 20, 255), "D": (102, 56, 12, 255),
    },
]


def draw_grid_sprite(img, x, y, grid, palette, scale=1):
    px = img.load()
    w, h = img.size
    for gy, row in enumerate(grid):
        for gx, ch in enumerate(row):
            col = palette.get(ch)
            if not col or col[3] == 0:
                continue
            for sy in range(scale):
                for sx in range(scale):
                    tx, ty = x + gx * scale + sx, y + gy * scale + sy
                    if 0 <= tx < w and 0 <= ty < h:
                        px[tx, ty] = col


def draw_combat_bar(img, x, y, w, h, hp_pct=0.58, segments=None, shield_pct=0.0,
                    heal_pct=0.0, bg=(22, 16, 30, 255), hp_colors=(CRIMSON_HI, CRIMSON, CRIMSON_DK)):
    """Draw a crisp 16-bit RPG nameplate/unit health bar with predictions & shields."""
    d = ImageDraw.Draw(img)
    # Outer obsidian + steel bezel
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=OBSIDIAN)
    d.rectangle([x + 1, y + 1, x + w - 2, y + h - 2], fill=STEEL_MID)
    d.rectangle([x + 1, y + h - 2, x + w - 2, y + h - 2], fill=STEEL_DARK)
    d.rectangle([x + w - 2, y + 1, x + w - 2, y + h - 2], fill=STEEL_DARK)
    ix0, iy0 = x + 2, y + 2
    ix1, iy1 = x + w - 3, y + h - 3
    iw = ix1 - ix0 + 1
    ih = iy1 - iy0 + 1
    d.rectangle([ix0, iy0, ix1, iy1], fill=bg)

    hp_w = max(1, int(iw * hp_pct))
    hp_edge = ix0 + hp_w
    # Base HP fill with 3-band 16-bit vertical shading
    d.rectangle([ix0, iy0, hp_edge - 1, iy1], fill=hp_colors[1])
    d.line([(ix0, iy0), (hp_edge - 1, iy0)], fill=hp_colors[0])
    d.line([(ix0, iy1), (hp_edge - 1, iy1)], fill=hp_colors[2])

    # Prediction / DoT segments (eat leftwards from hp_edge)
    if segments:
        cursor = hp_edge
        for pct, c_hi, c_mid, c_dk in segments:
            sw = max(2, int(iw * pct))
            sx0 = max(ix0, cursor - sw)
            if sx0 < cursor:
                d.rectangle([sx0, iy0, cursor - 1, iy1], fill=c_mid)
                d.line([(sx0, iy0), (cursor - 1, iy0)], fill=c_hi)
                d.line([(sx0, iy1), (cursor - 1, iy1)], fill=c_dk)
                if sx0 > ix0:
                    d.line([(sx0, iy0), (sx0, iy1)], fill=OBSIDIAN)
            cursor = sx0

    # HealPrediction band extending right from hp_edge (subtle 16-bit RPG checker dither)
    if heal_pct > 0:
        hw = max(2, int(iw * heal_pct))
        hx1 = min(ix1, hp_edge + hw - 1)
        if hp_edge <= hx1:
            px_img = img.load()
            for hy in range(iy0, iy1 + 1):
                for hx in range(hp_edge, hx1 + 1):
                    if hy == iy0:
                        px_img[hx, hy] = GREEN_HI if ((hx - hp_edge) % 2 == 0) else GREEN
                    elif hy == iy1:
                        px_img[hx, hy] = GREEN_DK
                    else:
                        px_img[hx, hy] = GREEN if ((hx + hy) % 2 == 0) else GREEN_DK
            d.line([(hx1, iy0), (hx1, iy1)], fill=GREEN_HI)

    # ShieldsInfo narrow top edge band
    if shield_pct > 0:
        sw = max(4, int(iw * shield_pct))
        sx1 = min(ix1, ix0 + sw - 1)
        sh_h = max(2, ih // 4)
        d.rectangle([ix0, iy0, sx1, iy0 + sh_h - 1], fill=CYAN)
        d.line([(ix0, iy0), (sx1, iy0)], fill=CYAN_HI)
        d.line([(ix0, iy0 + sh_h), (sx1, iy0 + sh_h)], fill=OBSIDIAN)

    # HP edge bright vertical tick
    if ix0 < hp_edge <= ix1:
        d.line([(hp_edge - 1, iy0), (hp_edge - 1, iy1)], fill=GOLD_SPEC)


def add_landscape_silhouette(img, base_y):
    """Subtle distant 16-bit craggy ridge & spire silhouette near the horizon."""
    px = img.load()
    w = img.width
    sil = (9, 7, 16, 255)
    rim = (36, 26, 56, 255)
    for x in range(4, w - 4):
        ridge = int(
            4
            + 3 * math.sin(x * 0.045)
            + 2 * math.cos(x * 0.11)
            + (4 if 38 < x < 54 or 264 < x < 280 else 0)
        )
        top = base_y - ridge
        for y in range(top, img.height - 4):
            if y == top:
                px[x, y] = rim
            else:
                px[x, y] = sil


# ---------------------------------------------------------------------------
# 1. Hero Banner (native 356x116 -> 1068x348)
# ---------------------------------------------------------------------------
def build_hero_banner():
    nw, nh = 356, 116
    canvas = Image.new("RGBA", (nw, nh), TRANSPARENT)
    fill_dither_grad(
        canvas,
        (3, 3, nw - 3, nh - 3),
        [(0.0, NIGHT_TOP), (0.58, NIGHT_MID), (1.0, NIGHT_BOT)],
    )
    add_landscape_silhouette(canvas, nh - 10)

    # Dithered arcane/crimson halos behind wing emblems (true pixel-art gradients)
    draw_dither_halo(canvas, 34, 34, 26, 22, (165, 36, 44), max_alpha=125)
    draw_dither_halo(canvas, nw - 34, 34, 26, 22, (148, 52, 225), max_alpha=135)
    draw_dither_halo(canvas, nw // 2, 42, 95, 28, (96, 68, 148), max_alpha=65)

    # Arcane starfield sparkles (kept strictly outside plaque corners)
    stars = [
        (16, 12, GOLD_SPEC, GOLD_MID, False),
        (53, 14, CYAN_HI, BLUE, False),
        (106, 9, PURPLE_HI, PURPLE, True),
        (162, 8, GOLD_LIGHT, GOLD_DARK, False),
        (220, 9, CYAN_HI, BLUE, False),
        (266, 9, PURPLE_HI, PURPLE, True),
        (304, 13, CYAN_HI, BLUE, False),
        (338, 12, GOLD_SPEC, GOLD_MID, False),
        (68, 79, AMBER_HI, AMBER, False),
        (290, 77, PURPLE_HI, PURPLE, False),
        (182, 8, GOLD_SPEC, GOLD_MID, True),
    ]
    for sx, sy, c1, c2, big in stars:
        draw_sparkle(canvas, sx, sy, c1, c2, big=big)

    # Real addon Pixel Art icons left & right wings (clear of central plaque!)
    skull = load_px_sprite("Modules/DoTInfo/Textures/KillSkull_px.tga", 16).resize((32, 32), Image.NEAREST)
    blades = load_px_sprite("Modules/DoTInfo/Textures/KillBlades_px.tga", 16)
    crosshair = load_px_sprite("Modules/DoTInfo/Textures/KillCrosshair_px.tga", 16)

    shard = make_px_shard(with_glow=True)  # 32x32 native pixel glow + gem
    sword = load_px_sprite("Modules/HunterRangeFinder/Textures/MeleeSword_px.tga", 16)
    range_in = load_px_sprite("Modules/Range/Textures/RangeIn_px.tga", 16)

    canvas.alpha_composite(skull, (18, 17))
    canvas.alpha_composite(blades, (14, 54))
    canvas.alpha_composite(crosshair, (38, 54))

    canvas.alpha_composite(shard, (nw - 50, 17))
    canvas.alpha_composite(sword, (nw - 54, 54))
    canvas.alpha_composite(range_in, (nw - 30, 54))

    # Central dark emblem backing plaque (composited with real alpha + gold corner studs)
    title = "DOES IT DIE PLUS"
    tw = measure_text(title, FONT_HERO, scale=2, gap=1)
    pad_x = 12
    bx0 = (nw - tw) // 2 - pad_x
    bx1 = (nw + tw) // 2 + pad_x
    composite_rect(canvas, [bx0, 15, bx1, 71], fill=(10, 8, 18, 215), outline=OBSIDIAN)
    d = ImageDraw.Draw(canvas)
    d.rectangle([bx0 + 1, 16, bx1 - 1, 70], outline=GOLD_MID)
    d.line([(bx0 + 2, 70), (bx1 - 2, 70)], fill=GOLD_DARK)
    d.line([(bx1 - 1, 17), (bx1 - 1, 70)], fill=GOLD_DARK)
    d.rectangle([bx0 + 2, 17, bx1 - 2, 69], outline=OBSIDIAN)
    for sx, sy in ((bx0 + 3, 18), (bx1 - 4, 18), (bx0 + 3, 67), (bx1 - 4, 67)):
        d.rectangle([sx, sy, sx + 1, sy + 1], fill=GOLD_DARK)
        canvas.load()[sx, sy] = GOLD_SPEC

    # Bold hero title centered cleanly inside plaque
    draw_pixel_text(
        canvas,
        (nw - tw) // 2,
        22,
        title,
        grad=GOLD_GRAD_9,
        font=FONT_HERO,
        scale=2,
        gap=1,
        outline=OBSIDIAN,
        shadow=(6, 4, 10, 240),
    )

    # Subtitle
    sub = "WOW: FOREVER & RETAIL COMBAT HUD"
    sw = measure_text(sub, FONT_5X7, scale=1, gap=1)
    draw_pixel_text(
        canvas,
        (nw - sw) // 2,
        52,
        sub,
        grad=SILVER_GRAD_7,
        font=FONT_5X7,
        scale=1,
        gap=1,
        outline=OBSIDIAN,
        shadow=(6, 4, 10, 220),
    )

    # Flanking gold filigree diamonds beside subtitle
    for fx in ((nw - sw) // 2 - 12, (nw + sw) // 2 + 8):
        d.rectangle([fx, 54, fx + 3, 57], fill=GOLD_DARK)
        canvas.load()[fx + 1, 55] = GOLD_SPEC
        canvas.load()[fx + 2, 55] = GOLD_LIGHT
        canvas.load()[fx + 1, 56] = GOLD_LIGHT

    # Bottom combat health bar showcasing DoTs + Cast Prediction + Shields + Heals + Skull
    bar_w, bar_h = 204, 14
    bar_x = (nw - bar_w) // 2 - 4
    bar_y = 85
    draw_combat_bar(
        canvas,
        bar_x,
        bar_y,
        bar_w,
        bar_h,
        hp_pct=0.66,
        segments=[
            (0.16, PURPLE_HI, PURPLE, PURPLE_DK),   # Cast prediction / Shadow DoT
            (0.11, GREEN_HI, GREEN, GREEN_DK),      # Poison segment
            (0.13, AMBER_HI, AMBER, AMBER_DK),      # Bleed / Fire DoT
        ],
        shield_pct=0.45,
        heal_pct=0.14,
    )
    mini_skull = load_px_sprite("Modules/DoTInfo/Textures/KillSkull_px.tga", 16)
    canvas.alpha_composite(mini_skull, (bar_x + bar_w + 3, bar_y - 1))

    # Mini class orb row just left of the combat bar (crisp 9x9 handcrafted orb sprites)
    for idx, pal in enumerate(MINI_ORB_PALS):
        draw_grid_sprite(canvas, bar_x - 34 + idx * 11, bar_y + 2, MINI_ORB_GRID, pal, scale=1)

    draw_beveled_frame(canvas, chamfer=3, gold=True)
    out = canvas.resize((nw * 3, nh * 3), Image.NEAREST)
    out.save(OUT_DIR / "hero-banner.png")


# ---------------------------------------------------------------------------
# 2. Five Section Header Plaques (native 280x24 -> 840x72)
# ---------------------------------------------------------------------------
def build_section_plaque(filename, title, left_sprite, right_sprite, sparkle_rgb=None):
    nw, nh = 280, 24
    canvas = Image.new("RGBA", (nw, nh), TRANSPARENT)
    fill_dither_grad(
        canvas,
        (3, 3, nw - 3, nh - 3),
        [(0.0, (24, 18, 40, 255)), (0.55, OBSIDIAN_PANEL), (1.0, (12, 9, 18, 255))],
    )
    draw_beveled_frame(canvas, chamfer=2, gold=True)

    # Decorative horizontal gold divider lines inside plaque flanking the text
    tw = measure_text(title, FONT_5X7, scale=1, gap=1)
    tx = (nw - tw) // 2
    ty = 9
    px = canvas.load()

    def hline_ornate(lx0, lx1):
        if lx1 - lx0 < 6:
            return
        for x in range(lx0, lx1):
            px[x, 11] = GOLD_DARK if (x % 4 == 0) else GOLD_MID
            px[x, 12] = GOLD_SHADOW
        mx = (lx0 + lx1) // 2
        px[mx, 10] = GOLD_LIGHT
        px[mx, 11] = GOLD_SPEC
        px[mx, 12] = GOLD_LIGHT
        px[mx, 13] = GOLD_DARK
        px[mx - 1, 11] = GOLD_LIGHT
        px[mx + 1, 11] = GOLD_LIGHT

    hline_ornate(30, tx - 8)
    hline_ornate(tx + tw + 8, nw - 30)

    if sparkle_rgb:
        draw_sparkle(canvas, 25, 6, sparkle_rgb, GOLD_MID, False)
        draw_sparkle(canvas, nw - 26, 17, sparkle_rgb, GOLD_MID, False)

    canvas.alpha_composite(left_sprite, (8, 4))
    canvas.alpha_composite(right_sprite, (nw - 24, 4))

    draw_pixel_text(
        canvas,
        tx,
        ty,
        title,
        grad=GOLD_GRAD_7,
        font=FONT_5X7,
        scale=1,
        gap=1,
        outline=OBSIDIAN,
        shadow=(6, 4, 10, 230),
    )

    out = canvas.resize((nw * 3, nh * 3), Image.NEAREST)
    out.save(OUT_DIR / filename)


# ---------------------------------------------------------------------------
# 3. Art Style Showcase: Stylized 2D vs 16-bit Pixel Art (840x222)
# ---------------------------------------------------------------------------
def build_art_styles_showcase():
    scale = 3
    nw, nh = 280, 74
    canvas = Image.new("RGBA", (nw, nh), TRANSPARENT)
    fill_dither_grad(
        canvas,
        (3, 3, nw - 3, nh - 3),
        [(0.0, NIGHT_TOP), (0.6, NIGHT_MID), (1.0, NIGHT_BOT)],
    )
    draw_beveled_frame(canvas, chamfer=2, gold=True)

    d = ImageDraw.Draw(canvas)
    # Recessed left (Stylized 2D) and right (Pixel Art) showcase boxes
    left_box = (8, 7, 137, 56)
    right_box = (143, 7, 272, 56)
    for box, title_col, label in (
        (left_box, BLUE_HI, "STYLIZED 2D"),
        (right_box, GOLD_GRAD_7, "PIXEL ART (16-BIT)"),
    ):
        x0, y0, x1, y1 = box
        d.rectangle([x0, y0, x1, y1], fill=OBSIDIAN_RECESS)
        d.rectangle([x0, y0, x1, y1], outline=STEEL_DARK)
        d.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=OBSIDIAN)
        grad = SILVER_GRAD_7 if title_col == BLUE_HI else GOLD_GRAD_7
        lw = measure_text(label, FONT_5X7, scale=1, gap=1)
        draw_pixel_text(canvas, x0 + (x1 - x0 + 1 - lw) // 2, y0 + 4, label, grad=grad)
        d.line([(x0 + 8, y0 + 13), (x1 - 8, y0 + 13)], fill=STEEL_SHADOW)

        # 6 framed dark pedestals inside each panel (18x18 native -> 54x54 final)
        start_x = x0 + 5
        for i in range(6):
            px0 = start_x + i * 20
            py0 = y0 + 20
            px1, py1 = px0 + 18, py0 + 18
            d.rectangle([px0, py0, px1, py1], fill=(22, 18, 34, 255))
            d.rectangle([px0, py0, px1, py1], outline=GOLD_DARK if grad is GOLD_GRAD_7 else STEEL_MID)
            d.rectangle([px0 + 1, py0 + 1, px1 - 1, py1 - 1], outline=OBSIDIAN)

    # Pixel Art side drawn natively at 16x16 before 3x upscale
    px_sprites = [
        load_px_sprite("Modules/DoTInfo/Textures/KillSkull_px.tga", 16),
        make_px_shard(with_glow=False),
        make_px_combo((245, 72, 68)),
        load_px_sprite("Modules/Range/Textures/RangeIn_px.tga", 16),
        load_px_sprite("Modules/StatsInfo/Textures/ArrowUp_px.tga", 16),
        load_px_sprite("Modules/HunterRangeFinder/Textures/MeleeSword_px.tga", 16),
    ]
    for i, sp in enumerate(px_sprites):
        sx = right_box[0] + 6 + i * 20
        sy = right_box[1] + 21
        canvas.alpha_composite(sp, (sx, sy))

    # Bottom caption
    cap = "SWITCH LIVE: /UPT -> PROFILES  (STYLIZED 2D / PIXEL ART / CLASSIC)"
    cw = measure_text(cap, FONT_5X7, scale=1, gap=1)
    # Verify width; if slightly tight, trim to clean concise form
    if cw > nw - 20:
        cap = "SWITCH LIVE IN /UPT PROFILES: 2D / PIXEL / CLASSIC"
        cw = measure_text(cap, FONT_5X7, scale=1, gap=1)
    draw_pixel_text(
        canvas,
        (nw - cw) // 2,
        61,
        cap,
        grad=SILVER_GRAD_7,
        outline=OBSIDIAN,
        shadow=(6, 4, 10, 220),
    )

    out = canvas.resize((nw * scale, nh * scale), Image.NEAREST)

    # Composite crisp high-res Stylized 2D sprites into the left pedestals AFTER 3x upscale
    d2_sprites = [
        load_2d_sprite("Modules/DoTInfo/Textures/KillSkull2D.tga", 46),
        make_2d_shard(50),
        make_2d_combo(44, (245, 72, 68)),
        load_2d_sprite("Modules/Range/Textures/RangeIn.tga", 46),
        load_2d_sprite("Modules/StatsInfo/Textures/ArrowUp.tga", 46),
        load_2d_sprite("Modules/HunterRangeFinder/Textures/MeleeSword.tga", 46),
    ]
    for i, sp in enumerate(d2_sprites):
        cx = (left_box[0] + 5 + i * 20) * scale + 28
        cy = (left_box[1] + 20) * scale + 28
        out.alpha_composite(sp, (cx - sp.width // 2, cy - sp.height // 2))

    out.save(OUT_DIR / "art-styles-showcase.png")


# ---------------------------------------------------------------------------
# 4. Gamepad & UI Compatibility Banner (native 312x86 -> 936x258)
# ---------------------------------------------------------------------------
def build_gamepad_banner():
    nw, nh = 312, 86
    canvas = Image.new("RGBA", (nw, nh), TRANSPARENT)
    fill_dither_grad(
        canvas,
        (3, 3, nw - 3, nh - 3),
        [(0.0, NIGHT_TOP), (0.6, NIGHT_MID), (1.0, NIGHT_BOT)],
    )
    draw_beveled_frame(canvas, chamfer=3, gold=True)

    # Dithered arcane blue + antique gold glow behind central controller
    cx, cy = nw // 2, 36
    draw_dither_halo(canvas, cx, cy, 44, 28, (54, 128, 232), max_alpha=125)
    draw_dither_halo(canvas, cx, cy, 24, 15, (214, 156, 48), max_alpha=90)

    # Centerpiece: 16-bit Pixel Art Gamepad
    gw = len(GAMEPAD_GRID[0])
    draw_grid_sprite(canvas, (nw - gw) // 2, 16, GAMEPAD_GRID, GAMEPAD_PAL, scale=1)
    draw_sparkle(canvas, 118, 14, BLUE_HI, BLUE, False)
    draw_sparkle(canvas, 193, 15, GOLD_SPEC, GOLD_MID, True)

    d = ImageDraw.Draw(canvas)
    # Left Wing: Player & Enemy pixel RPG unit frames showing HealPrediction, ShieldsInfo & DoTInfo
    lx0, ly0, lx1, ly1 = 9, 10, 108, 57
    d.rectangle([lx0, ly0, lx1, ly1], fill=OBSIDIAN_RECESS, outline=STEEL_DARK)
    t1 = "HEALS & SHIELDS"
    t1w = measure_text(t1, FONT_5X7)
    draw_pixel_text(canvas, lx0 + (lx1 - lx0 + 1 - t1w) // 2, 14, t1, grad=SILVER_GRAD_7)
    draw_combat_bar(
        canvas,
        lx0 + 6,
        24,
        87,
        11,
        hp_pct=0.58,
        shield_pct=0.68,
        heal_pct=0.24,
        hp_colors=(GREEN_HI, GREEN, GREEN_DK),
    )
    draw_combat_bar(
        canvas,
        lx0 + 6,
        40,
        71,
        11,
        hp_pct=0.62,
        segments=[
            (0.18, PURPLE_HI, PURPLE, PURPLE_DK),
            (0.14, GREEN_HI, GREEN, GREEN_DK),
        ],
        shield_pct=0.28,
    )
    skull = load_px_sprite("Modules/DoTInfo/Textures/KillSkull_px.tga", 16)
    canvas.alpha_composite(skull, (lx0 + 79, 37))

    # Right Wing: TriggerGlow & Stats/Range badges
    rx0, ry0, rx1, ry1 = 204, 10, 303, 57
    d.rectangle([rx0, ry0, rx1, ry1], fill=OBSIDIAN_RECESS, outline=STEEL_DARK)
    t2 = "GLOW & TRACKERS"
    t2w = measure_text(t2, FONT_5X7)
    draw_pixel_text(canvas, rx0 + (rx1 - rx0 + 1 - t2w) // 2, 14, t2, grad=GOLD_GRAD_7)

    slot_specs = [
        ("Modules/HunterRangeFinder/Textures/MeleeSword_px.tga", True),
        ("Modules/DoTInfo/Textures/KillBlades_px.tga", False),
        ("Modules/Range/Textures/RangeIn_px.tga", False),
        ("Modules/StatsInfo/Textures/ArrowUp_px.tga", False),
    ]
    start_sx = rx0 + 9
    for i, (rel, glow) in enumerate(slot_specs):
        sx = start_sx + i * 21
        sy = 29
        if glow:
            d.rectangle([sx - 2, sy - 2, sx + 19, sy + 19], outline=GOLD_SPEC)
            d.rectangle([sx - 1, sy - 1, sx + 18, sy + 18], outline=AMBER)
        d.rectangle([sx, sy, sx + 17, sy + 17], fill=(24, 18, 36, 255), outline=STEEL_MID)
        sp = load_px_sprite(rel, 16)
        canvas.alpha_composite(sp, (sx + 1, sy + 1))

    # Bottom bar with compatibility list
    composite_rect(canvas, [9, 63, nw - 10, 77], fill=(12, 9, 20, 235), outline=GOLD_DARK)
    cap = "GAMEPAD READY * ELVUI * DAYLIGHTUI * PLATYNATOR"
    cw = measure_text(cap, FONT_5X7, scale=1, gap=1)
    draw_pixel_text(canvas, (nw - cw) // 2, 67, cap, grad=GOLD_GRAD_7)

    out = canvas.resize((nw * 3, nh * 3), Image.NEAREST)
    out.save(OUT_DIR / "gamepad-compat-banner.png")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_hero_banner()
    build_gamepad_banner()
    build_art_styles_showcase()

    build_section_plaque(
        "sec-predictions.png",
        "COMBAT PREDICTIONS & DOTS",
        load_px_sprite("Modules/DoTInfo/Textures/KillSkull_px.tga", 16),
        load_px_sprite("Modules/DoTInfo/Textures/KillCrosshair_px.tga", 16),
        sparkle_rgb=CRIMSON_HI,
    )
    build_section_plaque(
        "sec-glow.png",
        "TRIGGER GLOW & ACTION BARS",
        load_px_sprite("Modules/DoTInfo/Textures/KillBlades_px.tga", 16),
        load_px_sprite("Modules/DoTInfo/Textures/KillBlades_px.tga", 16),
        sparkle_rgb=GOLD_SPEC,
    )
    build_section_plaque(
        "sec-stats.png",
        "STATS & UPGRADE TOOLTIPS",
        load_px_sprite("Modules/StatsInfo/Textures/ArrowUp_px.tga", 16),
        load_px_sprite("Modules/StatsInfo/Textures/ArrowDown_px.tga", 16),
        sparkle_rgb=GREEN_HI,
    )
    build_section_plaque(
        "sec-tools.png",
        "CLASS TOOLS & ART STYLES",
        make_px_shard(with_glow=False),
        load_px_sprite("Modules/HunterRangeFinder/Textures/MeleeSword_px.tga", 16),
        sparkle_rgb=PURPLE_HI,
    )
    build_section_plaque(
        "sec-compat.png",
        "COMPATIBILITY, PROFILES & API",
        load_px_sprite("Modules/Range/Textures/RangeIn_px.tga", 16),
        make_px_diamond((255, 210, 64)),
        sparkle_rgb=CYAN_HI,
    )
    for png in sorted(OUT_DIR.glob("*.png")):
        im = Image.open(png)
        print(f"Generated {png.relative_to(ROOT)}: {im.size[0]}x{im.size[1]} ({png.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
