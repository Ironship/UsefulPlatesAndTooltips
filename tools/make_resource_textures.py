"""Generates ResourceDing's combo point and soul shard textures into Modules/ResourceDing/Textures.

Combo points: a dark matte centre, a glossy fill orb the palette tints, a lit metal bezel and a
soft halo for the newest point.
Soul shards: a 3D faceted amethyst crystal, a sculpted lit metallic bezel with high-contrast dark
outer rim, and a violet arcane halo. All textures are plain 32-bit uncompressed TGA with a top-left
origin (descriptor 0x28), the format the shipped DoTInfo textures use.

    python tools/make_resource_textures.py
"""
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Modules" / "ResourceDing" / "Textures"
SS = 4  # supersampling per axis


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def write_tga(path, size, shade):
    """shade(nx, ny) -> (luminance, alpha) with normalized coords in [-1, 1]."""
    rows = []
    for py in range(size):
        row = bytearray()
        for px in range(size):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    nx = (px + (sx + 0.5) / SS) / size * 2 - 1
                    ny = (py + (sy + 0.5) / SS) / size * 2 - 1
                    lum, alpha = shade(nx, ny)
                    r += lum * alpha
                    g += lum * alpha
                    b += lum * alpha
                    a += alpha
            n = SS * SS
            r, g, b, a = r / n, g / n, b / n, a / n
            # straight alpha TGA: colour is the luminance, coverage separate
            row += bytes((int(clamp(b) * 255 + 0.5), int(clamp(g) * 255 + 0.5),
                          int(clamp(r) * 255 + 0.5), int(clamp(a) * 255 + 0.5)))
        rows.append(row)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    path.write_bytes(header + b"".join(rows))
    print(f"{path.name}: {size}x{size}, {path.stat().st_size} bytes")


def write_rgba_tga(path, size, shade):
    """shade(nx, ny) -> (r, g, b, alpha) with normalized coords in [-1, 1]; unpremultiplied straight alpha."""
    rows = []
    for py in range(size):
        row = bytearray()
        for px in range(size):
            pr = pg = pb = pa = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    nx = (px + (sx + 0.5) / SS) / size * 2 - 1
                    ny = (py + (sy + 0.5) / SS) / size * 2 - 1
                    cr, cg, cb, alpha = shade(nx, ny)
                    pr += cr * alpha
                    pg += cg * alpha
                    pb += cb * alpha
                    pa += alpha
            n = SS * SS
            pa /= n
            if pa > 1e-6:
                r, g, b = pr / (pa * n), pg / (pa * n), pb / (pa * n)
            else:
                r = g = b = 0.0
            row += bytes((int(clamp(b) * 255 + 0.5), int(clamp(g) * 255 + 0.5),
                          int(clamp(r) * 255 + 0.5), int(clamp(pa) * 255 + 0.5)))
        rows.append(row)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    path.write_bytes(header + b"".join(rows))
    print(f"{path.name}: {size}x{size}, {path.stat().st_size} bytes")


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def orb(nx, ny):
    r = math.hypot(nx, ny)
    a = smooth(0.94, 0.99, r)
    if a >= 1.0:
        return 0.0, 0.0
    a = 1.0 - a
    lum = 0.58 + 0.42 * (1 - r ** 1.7)
    d = math.hypot(nx + 0.30, ny + 0.34)
    lum += 0.50 * math.exp(-((d / 0.40) ** 2))
    lum += 0.16 * clamp((r - 0.40) / 0.55) * clamp((ny - 0.15) / 0.5)
    return clamp(lum), a


def ring(nx, ny):
    r = math.hypot(nx, ny)
    band = smooth(0.62, 0.65, r) * (1 - smooth(0.95, 0.98, r))
    if band <= 0:
        return 0.0, 0.0
    ang = math.atan2(ny, nx)
    light = math.atan2(-0.60, -0.55)  # up-left
    c = math.cos(ang - light)
    lum = 0.55 + 0.33 * max(0.0, c) ** 1.4 - 0.20 * max(0.0, -c) ** 1.6
    if r < 0.78:  # the step down into the orb
        lum *= 0.52 + 0.48 * ((r - 0.62) / 0.16)
    diff = (ang - light + math.pi) % (2 * math.pi) - math.pi
    lum += 0.30 * math.exp(-(diff ** 2) / 0.55) * math.exp(-(((r - 0.69) / 0.05) ** 2))
    if r > 0.91:  # crisp the outer boundary
        lum *= 0.40 + 0.60 * ((0.97 - r) / 0.06)
    return clamp(lum), band


def orb_dark(nx, ny):
    r = math.hypot(nx, ny)
    a = 1.0 - smooth(0.86, 0.91, r)
    if a <= 0:
        return 0.0, 0.0
    lum = 0.20
    lum *= 1 - 0.55 * clamp(-ny - 0.05) * (1 - r)  # shadow under the top inner wall
    lum += 0.10 * clamp((ny - 0.1) / 0.6) * r       # faint bottom bounce
    lum = clamp(lum, 0.04, 0.4)
    return lum, a


def glow(nx, ny):
    r = math.hypot(nx, ny)
    a = 0.80 * math.exp(-(((r - 0.58) / 0.26) ** 2))
    a *= clamp((1.0 - r) / 0.12)
    return (1.0, clamp(a)) if a > 0 else (1.0, 0.0)


# ---------------------------------------------------------------------------
# Soul Shard crystal geometry (elongated hexagonal warlock gem)
# ---------------------------------------------------------------------------

SHARD_OUTER = [
    (0.00, -0.88),   # 0: top tip
    (0.61, -0.23),   # 1: upper-right shoulder
    (0.55,  0.31),   # 2: lower-right hip
    (0.00,  0.88),   # 3: bottom tip
    (-0.55, 0.31),   # 4: lower-left hip
    (-0.61, -0.23),  # 5: upper-left shoulder
]

SHARD_TABLE = [
    (0.00, -0.46),   # 0: top table vertex
    (0.30, -0.14),   # 1: upper-right
    (0.27,  0.18),   # 2: lower-right
    (0.00,  0.45),   # 3: bottom
    (-0.27, 0.18),   # 4: lower-left
    (-0.30, -0.14),  # 5: upper-left
]


def _poly_edges(verts):
    edges = []
    n = len(verts)
    for i in range(n):
        x0, y0 = verts[i]
        x1, y1 = verts[(i + 1) % n]
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        # Clockwise winding in screen coords (y down): outward normal is (dy, -dx) / len
        nx, ny = dy / length, -dx / length
        edges.append((x0, y0, x1, y1, nx, ny, length))
    return edges


OUTER_EDGES = _poly_edges(SHARD_OUTER)
TABLE_EDGES = _poly_edges(SHARD_TABLE)


def _signed_dist_convex(x, y, edges):
    """Exact signed distance to a convex polygon (< 0 inside, > 0 outside) + nearest edge index."""
    max_d = -1e9
    best_i = 0
    for i, (x0, y0, x1, y1, nx, ny, _) in enumerate(edges):
        d = (x - x0) * nx + (y - y0) * ny
        if d > max_d:
            max_d = d
            best_i = i
    if max_d <= 0.0:
        return max_d, best_i
    # Outside: exact Euclidean distance to nearest segment
    min_d2 = 1e9
    for i, (x0, y0, x1, y1, _, _, length) in enumerate(edges):
        vx, vy = x1 - x0, y1 - y0
        t = clamp(((x - x0) * vx + (y - y0) * vy) / (length * length))
        px, py = x0 + vx * t, y0 + vy * t
        d2 = (x - px) ** 2 + (y - py) ** 2
        if d2 < min_d2:
            min_d2 = d2
            best_i = i
    return math.sqrt(min_d2), best_i


def _point_in_quad(x, y, q):
    for i in range(4):
        x0, y0 = q[i]
        x1, y1 = q[(i + 1) % 4]
        if (x1 - x0) * (y - y0) - (y1 - y0) * (x - x0) < -1e-6:
            return False
    return True


def _dist_seg(x, y, x0, y0, x1, y1):
    vx, vy = x1 - x0, y1 - y0
    l2 = vx * vx + vy * vy
    t = clamp(((x - x0) * vx + (y - y0) * vy) / l2) if l2 > 0 else 0.0
    return math.hypot(x - (x0 + vx * t), y - (y0 + vy * t))


# Six bevel quads (clockwise in screen coords) + per-facet 3D surface normal
BEVEL_QUADS = []
FACET_NORMALS = [
    ( 0.42, -0.58, 0.70),  # 0: upper-right crown
    ( 0.76,  0.14, 0.63),  # 1: mid-right wall
    ( 0.48,  0.62, 0.62),  # 2: lower-right pavilion
    (-0.46,  0.60, 0.65),  # 3: lower-left pavilion
    (-0.76,  0.12, 0.64),  # 4: mid-left wall
    (-0.44, -0.58, 0.69),  # 5: upper-left crown (faces key light!)
]
for _i in range(6):
    _j = (_i + 1) % 6
    BEVEL_QUADS.append((SHARD_OUTER[_i], SHARD_OUTER[_j], SHARD_TABLE[_j], SHARD_TABLE[_i]))


def _norm3(x, y, z):
    m = math.sqrt(x * x + y * y + z * z)
    return x / m, y / m, z / m


KEY_LIGHT = _norm3(-0.55, -0.60, 0.58)
BOUNCE_LIGHT = _norm3(0.45, 0.65, 0.45)
VIEW_DIR = (0.0, 0.0, 1.0)
HALF_KEY = _norm3(KEY_LIGHT[0] + VIEW_DIR[0], KEY_LIGHT[1] + VIEW_DIR[1], KEY_LIGHT[2] + VIEW_DIR[2])


def _amethyst_ramp(v):
    """Map lighting value v in [0, 1.4] to rich Warlock Soul Shard RGB."""
    # Deep obsidian-violet -> royal amethyst -> luminous orchid -> lavender-white specular
    stops = [
        (0.00, (0.14, 0.02, 0.28)),
        (0.28, (0.32, 0.06, 0.58)),
        (0.55, (0.58, 0.16, 0.92)),
        (0.78, (0.78, 0.36, 1.00)),
        (0.98, (0.93, 0.68, 1.00)),
        (1.28, (1.00, 0.95, 1.00)),
    ]
    if v <= stops[0][0]:
        return stops[0][1]
    for k in range(len(stops) - 1):
        v0, c0 = stops[k]
        v1, c1 = stops[k + 1]
        if v <= v1:
            t = (v - v0) / (v1 - v0)
            return (c0[0] + (c1[0] - c0[0]) * t,
                    c0[1] + (c1[1] - c0[1]) * t,
                    c0[2] + (c1[2] - c0[2]) * t)
    return stops[-1][1]


def shard_gem(nx, ny):
    d_out, _ = _signed_dist_convex(nx, ny, OUTER_EDGES)
    alpha = 1.0 - smooth(-0.025, 0.02, d_out)
    if alpha <= 0.0:
        return 0.0, 0.0, 0.0, 0.0

    d_tab, _ = _signed_dist_convex(nx, ny, TABLE_EDGES)

    if d_tab <= 0.0:
        # Center table face: glowing translucent amethyst heart + subtle internal refraction
        core_d = math.hypot((nx + 0.03) / 0.26, (ny + 0.04) / 0.36)
        inner_glow = math.exp(-(core_d * core_d) * 1.15)
        diag = math.exp(-(((nx * 0.72 + ny * 0.68 + 0.05) / 0.10) ** 2)) * 0.24
        # Slight bright crown edge at top-left of table, darker lower-right corner
        tilt = clamp(0.58 - nx * 0.35 - ny * 0.32, 0.25, 0.95)
        v = 0.44 + 0.34 * inner_glow + 0.22 * tilt + diag
        # Crisp bright sheen along the upper-left table border
        edge_hi = smooth(-0.08, 0.0, d_tab) * clamp((-nx - ny) * 1.6) * 0.26
        r, g, b = _amethyst_ramp(v + edge_hi)
        # Warm magenta soul-fire tint in the glowing heart
        r = clamp(r + 0.12 * inner_glow)
        g = clamp(g + 0.04 * inner_glow)
    else:
        # Find which of the 6 crystal bevel facets this pixel lies on
        facet = 0
        for i, quad in enumerate(BEVEL_QUADS):
            if _point_in_quad(nx, ny, quad):
                facet = i
                break
        fn = _norm3(*FACET_NORMALS[facet])
        diff = max(0.0, fn[0] * KEY_LIGHT[0] + fn[1] * KEY_LIGHT[1] + fn[2] * KEY_LIGHT[2])
        spec = max(0.0, fn[0] * HALF_KEY[0] + fn[1] * HALF_KEY[1] + fn[2] * HALF_KEY[2]) ** 10
        bounce = max(0.0, fn[0] * BOUNCE_LIGHT[0] + fn[1] * BOUNCE_LIGHT[1] + fn[2] * BOUNCE_LIGHT[2])

        # Smooth internal variation across each facet so none look flat-shaded
        grad = 0.08 * (-nx * 0.6 - ny * 0.8)
        # Subsurface internal caustics in the lower pavilion (light refracting out the bottom!)
        subsurface = 0.0
        if facet in (2, 3):
            subsurface = 0.28 * smooth(0.0, 0.22, d_tab) * (1.0 - smooth(-0.08, 0.0, d_out))
        elif facet == 5:
            # Upper-left crown catches brilliant direct sunlight
            grad += 0.18
        elif facet == 0:
            grad += 0.05

        v = 0.16 + 0.68 * diff + 0.48 * spec + 0.14 * bounce + grad + subsurface
        r, g, b = _amethyst_ramp(v)
        if subsurface > 0:
            # Magenta-violet internal transmission glow on lower facets
            r = clamp(r + 0.18 * subsurface)
            b = clamp(b + 0.08 * subsurface)

    # Crisp specular ridge lines between facets (crucial for 14px readability!)
    ridge = 0.0
    for i in range(6):
        vx0, vy0 = SHARD_OUTER[i]
        vx1, vy1 = SHARD_TABLE[i]
        dr = _dist_seg(nx, ny, vx0, vy0, vx1, vy1)
        weight = 1.0 if i in (0, 5) else 0.55 if i in (1, 4) else 0.30
        ridge = max(ridge, weight * math.exp(-((dr / 0.028) ** 2)))
    # Table outline ridge
    dr_tab = abs(d_tab)
    tab_weight = 0.72 if (nx + ny) < 0.08 else 0.34
    ridge = max(ridge, tab_weight * math.exp(-((dr_tab / 0.025) ** 2)))

    r = clamp(r + 0.34 * ridge)
    g = clamp(g + 0.26 * ridge)
    b = clamp(b + 0.38 * ridge)

    # Tiny razor star glint on upper-left crown vertex
    glint_d = math.hypot(nx + 0.22, ny + 0.30)
    glint = 0.62 * math.exp(-((glint_d / 0.075) ** 2))
    r, g, b = clamp(r + glint), clamp(g + glint * 0.92), clamp(b + glint)

    return r, g, b, alpha


def shard_bezel(nx, ny):
    """Sculpted lit metallic bezel + dark outer shadow silhouette hugging SHARD_OUTER."""
    d_out, edge_i = _signed_dist_convex(nx, ny, OUTER_EDGES)

    # Outer dark shadow silhouette (gives crisp high-contrast separation on any nameplate/terrain)
    outer_shadow = smooth(-0.01, 0.02, d_out) * (1.0 - smooth(0.085, 0.135, d_out))
    # Metallic bezel rim sitting tightly around d_out in [-0.055 .. +0.065]
    metal_band = smooth(-0.075, -0.042, d_out) * (1.0 - smooth(0.045, 0.080, d_out))

    # Subtle metallic prongs at the 6 vertices for Warcraft jewel-craft detail
    prong = 0.0
    for i, (vx, vy) in enumerate(SHARD_OUTER):
        scale = 0.078 if i in (0, 3) else 0.058
        pd = math.hypot(nx - vx * 0.99, ny - vy * 0.99)
        prong = max(prong, 1.0 - smooth(scale * 0.65, scale, pd))
    metal_band = max(metal_band, prong * (1.0 - smooth(0.06, 0.10, d_out)))

    if outer_shadow <= 0.0 and metal_band <= 0.0:
        return 0.0, 0.0, 0.0, 0.0

    # Key light from top-left (-0.55, -0.60), matching ComboRing.tga
    ang = math.atan2(ny, nx)
    light = math.atan2(-0.60, -0.55)
    c = math.cos(ang - light)
    lum = 0.56 + 0.36 * max(0.0, c) ** 1.3 - 0.24 * max(0.0, -c) ** 1.5
    # Inner bevel step down onto crystal
    if d_out < -0.01:
        lum *= 0.60 + 0.40 * clamp((d_out + 0.075) / 0.065)
    # Specular sheen peak on top-left rim
    diff = (ang - light + math.pi) % (2 * math.pi) - math.pi
    lum += 0.28 * math.exp(-(diff * diff) / 0.50) * math.exp(-(((d_out - 0.005) / 0.032) ** 2))
    lum = clamp(lum)

    # Cool silver-lavender arcane metal tint
    mr, mg, mb = clamp(lum * 0.95), clamp(lum * 0.91), clamp(lum * 1.04)

    # Composite metal over dark outer shadow
    sa = outer_shadow * 0.92
    ma = clamp(metal_band)
    out_a = ma + sa * (1.0 - ma)
    if out_a <= 1e-6:
        return 0.0, 0.0, 0.0, 0.0
    sr, sg, sb = 0.04, 0.02, 0.07
    r = (mr * ma + sr * sa * (1.0 - ma)) / out_a
    g = (mg * ma + sg * sa * (1.0 - ma)) / out_a
    b = (mb * ma + sb * sa * (1.0 - ma)) / out_a
    return clamp(r), clamp(g), clamp(b), clamp(out_a)


def shard_glow(nx, ny):
    """Soft elongated violet soul-fire halo behind a highlighted/newest soul shard."""
    # Elongated elliptical/diamond radial falloff matching crystal aspect
    rx, ry = nx / 0.68, ny / 0.90
    r = math.hypot(rx, ry)
    core = math.exp(-((r / 0.62) ** 2))
    halo = 0.85 * math.exp(-(((r - 0.42) / 0.34) ** 2))
    a = max(core * 0.70, halo) * clamp((1.0 - math.hypot(nx, ny)) / 0.18)
    if a <= 0.0:
        return 0.0, 0.0, 0.0, 0.0
    # Warm orchid-violet inner core fading into deep royal purple outer aura
    r_col = clamp(0.68 + 0.28 * core)
    g_col = clamp(0.24 + 0.30 * core)
    b_col = 1.0
    return r_col, g_col, b_col, clamp(a * 0.88)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    write_tga(OUT / "ComboOrb.tga", 64, orb)
    write_tga(OUT / "ComboRing.tga", 64, ring)
    write_tga(OUT / "ComboOrbDark.tga", 64, orb_dark)
    write_tga(OUT / "ComboGlow.tga", 128, glow)
    write_rgba_tga(OUT / "ShardGem.tga", 64, shard_gem)
    write_rgba_tga(OUT / "ShardBezel.tga", 64, shard_bezel)
    write_rgba_tga(OUT / "ShardGlow.tga", 128, shard_glow)


if __name__ == "__main__":
    main()
