"""Generates faceted dark-fantasy crystalline 3D UI emblems and markers for UsefulPlatesAndTooltips.

Matches the exact planar-facet crystal shading, crisp specular ridge lines, rich color ramps,
thin sculpted metallic bezel, and dark outer contrast silhouette of ShardGem.tga + ShardBezel.tga:

  Modules/Range/Textures/
    RangeIn.tga            64x64  faceted emerald crystal checkmark in thin steel bezel
    RangeOut.tga           64x64  faceted ruby crystal X in thin steel bezel

  Modules/StatsInfo/Textures/
    ArrowUp.tga            64x64  faceted emerald crystal upward upgrade arrow
    ArrowDown.tga          64x64  faceted ruby crystal downward arrow

  Core/Textures/
    MarkerDiamond.tga      64x64  grayscale tintable 3D faceted diamond jewel
    MarkerDiamondBezel.tga 64x64  lit metallic bezel + dark rim hugging MarkerDiamond
    MarkerSegment.tga      64x32  grayscale tintable faceted crystal/bevel segment plate

All textures are 32-bit uncompressed RGBA TGA with top-left origin (descriptor 0x28).

    python tools/make_ui_emblems.py
"""
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SS = 4  # 4x4 supersampling per pixel


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def smooth(e0, e1, x):
    if e0 == e1:
        return 1.0 if x >= e1 else 0.0
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def lerp3(c0, c1, t):
    return (c0[0] + (c1[0] - c0[0]) * t,
            c0[1] + (c1[1] - c0[1]) * t,
            c0[2] + (c1[2] - c0[2]) * t)


def norm3(x, y, z):
    m = math.sqrt(x * x + y * y + z * z)
    return (x / m, y / m, z / m) if m > 1e-9 else (0.0, 0.0, 1.0)


def over(dst, src):
    sr, sg, sb, sa = src
    if sa <= 1e-6:
        return dst
    dr, dg, db, da = dst
    if sa >= 1.0 - 1e-6 or da <= 1e-6:
        return src
    oa = sa + da * (1.0 - sa)
    inv = 1.0 / oa
    return ((sr * sa + dr * da * (1.0 - sa)) * inv,
            (sg * sa + dg * da * (1.0 - sa)) * inv,
            (sb * sa + db * da * (1.0 - sa)) * inv,
            oa)


# Exact same key/bounce light as Soul Shard (ShardGem.tga / ShardBezel.tga)
KEY_LIGHT = norm3(-0.55, -0.60, 0.58)
BOUNCE_LIGHT = norm3(0.45, 0.65, 0.45)
HALF_KEY = norm3(KEY_LIGHT[0], KEY_LIGHT[1], KEY_LIGHT[2] + 1.0)


def ramp(v, stops):
    if v <= stops[0][0]:
        return stops[0][1]
    for i in range(len(stops) - 1):
        v0, c0 = stops[i]
        v1, c1 = stops[i + 1]
        if v <= v1:
            return lerp3(c0, c1, (v - v0) / (v1 - v0))
    return stops[-1][1]


# Jewel-grade saturated ramps matching _amethyst_ramp in make_resource_textures.py
EMERALD_CRYSTAL = [
    (0.00, (0.02, 0.16, 0.08)),
    (0.28, (0.04, 0.38, 0.16)),
    (0.55, (0.10, 0.72, 0.28)),
    (0.78, (0.28, 0.94, 0.46)),
    (0.98, (0.64, 1.00, 0.72)),
    (1.28, (0.94, 1.00, 0.96)),
]

RUBY_CRYSTAL = [
    (0.00, (0.20, 0.02, 0.05)),
    (0.28, (0.48, 0.04, 0.10)),
    (0.55, (0.84, 0.10, 0.18)),
    (0.78, (1.00, 0.28, 0.30)),
    (0.98, (1.00, 0.62, 0.58)),
    (1.28, (1.00, 0.94, 0.92)),
]


def write_rgba_tga(path, width, height, shade):
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    n_samples = SS * SS
    for py in range(height):
        row = bytearray()
        for px in range(width):
            pr = pg = pb = pa = 0.0
            for sy in range(SS):
                ny = (py + (sy + 0.5) / SS) / height * 2.0 - 1.0
                for sx in range(SS):
                    nx = (px + (sx + 0.5) / SS) / width * 2.0 - 1.0
                    cr, cg, cb, a = shade(nx, ny)
                    pr += cr * a
                    pg += cg * a
                    pb += cb * a
                    pa += a
            pa /= n_samples
            if pa > 1e-6:
                inv = 1.0 / (pa * n_samples)
                r, g, b = pr * inv, pg * inv, pb * inv
            else:
                r = g = b = 0.0
            row += bytes((int(clamp(b) * 255 + 0.5),
                          int(clamp(g) * 255 + 0.5),
                          int(clamp(r) * 255 + 0.5),
                          int(clamp(pa) * 255 + 0.5)))
        rows.append(row)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)
    path.write_bytes(header + b"".join(rows))
    print(f"{path.relative_to(ROOT)}: {width}x{height}, {path.stat().st_size} bytes")


# ---------------------------------------------------------------------------
# Polygon & faceted crystal engine (exact same visual DNA as ShardGem + ShardBezel)
# ---------------------------------------------------------------------------

def poly_edges(verts):
    edges = []
    n = len(verts)
    for i in range(n):
        x0, y0 = verts[i]
        x1, y1 = verts[(i + 1) % n]
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy)
        # Clockwise winding in screen coords (y down) -> outward normal (dy, -dx)/len
        edges.append((x0, y0, x1, y1, dy / length, -dx / length, length))
    return edges


def dist_seg(px, py, x0, y0, x1, y1):
    vx, vy = x1 - x0, y1 - y0
    l2 = vx * vx + vy * vy
    t = clamp(((px - x0) * vx + (py - y0) * vy) / l2) if l2 > 1e-9 else 0.0
    return math.hypot(px - (x0 + vx * t), py - (y0 + vy * t))


def signed_dist_convex(x, y, edges):
    max_d = -1e9
    best_i = 0
    for i, (x0, y0, x1, y1, nx, ny, _) in enumerate(edges):
        d = (x - x0) * nx + (y - y0) * ny
        if d > max_d:
            max_d = d
            best_i = i
    if max_d <= 0.0:
        return max_d, best_i
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


def signed_dist_poly(x, y, edges):
    """Exact signed distance for ANY simple clockwise polygon (convex or concave) + nearest edge normal."""
    inside = False
    min_d = 1e9
    best_nx, best_ny = 0.0, -1.0
    for x0, y0, x1, y1, enx, eny, length in edges:
        # Ray-cast odd-even test
        if (y0 > y) != (y1 > y):
            x_int = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            if x < x_int:
                inside = not inside
        d = dist_seg(x, y, x0, y0, x1, y1)
        if d < min_d:
            min_d = d
            best_nx, best_ny = enx, eny
    return (-min_d if inside else min_d), best_nx, best_ny


def point_in_tri(px, py, a, b, c):
    def cross(u, v, w):
        return (v[0] - u[0]) * (w[1] - u[1]) - (v[1] - u[1]) * (w[0] - u[0])
    c1 = cross(a, b, (px, py))
    c2 = cross(b, c, (px, py))
    c3 = cross(c, a, (px, py))
    return (c1 >= -1e-6 and c2 >= -1e-6 and c3 >= -1e-6) or (c1 <= 1e-6 and c2 <= 1e-6 and c3 <= 1e-6)


def shade_faceted_crystal(nx, ny, outer_edges, facets, ridges, glints, color_ramp, bezel_w=0.078):
    """Render a ShardGem+ShardBezel-style planar faceted crystal with thin sculpted metallic bezel."""
    d_out, enx, eny = signed_dist_poly(nx, ny, outer_edges)
    col = (0.0, 0.0, 0.0, 0.0)

    # 1. Crisp dark outer contrast silhouette (exact ShardBezel look!)
    outer_shadow = smooth(-0.01, 0.015, d_out) * (1.0 - smooth(0.072, 0.118, d_out))
    if outer_shadow > 0.0:
        col = (0.03, 0.03, 0.05, outer_shadow * 0.94)

    # 2. Faceted crystal interior (sharp planar facets, ZERO blurry tubes!)
    gem_a = 1.0 - smooth(-0.02, 0.018, d_out)
    if gem_a > 0.0:
        # Pick planar facet normal from explicit triangles (or fallback to nearest edge normal)
        fn = None
        subsurface = 0.0
        is_table = False
        for tri, fnorm, extra in facets:
            if point_in_tri(nx, ny, tri[0], tri[1], tri[2]):
                fn = fnorm
                subsurface = extra.get("sub", 0.0)
                is_table = extra.get("table", False)
                break
        if fn is None:
            fn = norm3(enx * 0.66, eny * 0.66, 0.75)

        if is_table:
            core_d = math.hypot(nx + 0.04, ny + 0.04) / 0.36
            inner_glow = math.exp(-(core_d * core_d) * 1.15)
            tilt = clamp(0.60 - nx * 0.34 - ny * 0.34, 0.28, 0.98)
            v = 0.44 + 0.34 * inner_glow + 0.24 * tilt
        else:
            diff = max(0.0, fn[0] * KEY_LIGHT[0] + fn[1] * KEY_LIGHT[1] + fn[2] * KEY_LIGHT[2])
            spec = max(0.0, fn[0] * HALF_KEY[0] + fn[1] * HALF_KEY[1] + fn[2] * HALF_KEY[2]) ** 11
            bounce = max(0.0, fn[0] * BOUNCE_LIGHT[0] + fn[1] * BOUNCE_LIGHT[1] + fn[2] * BOUNCE_LIGHT[2])
            grad = 0.08 * (-nx * 0.55 - ny * 0.75)
            sub_val = subsurface * smooth(-0.30, -0.04, d_out)
            v = 0.16 + 0.70 * diff + 0.50 * spec + 0.14 * bounce + grad + sub_val

        r, g, b = ramp(v, color_ramp)

        # Razor-sharp specular facet ridge lines (what makes Soul Shards pop at 14px!)
        ridge = 0.0
        for p0, p1, w in ridges:
            dr = dist_seg(nx, ny, p0[0], p0[1], p1[0], p1[1])
            ridge = max(ridge, w * math.exp(-((dr / 0.025) ** 2)))
        r = clamp(r + 0.36 * ridge)
        g = clamp(g + 0.34 * ridge)
        b = clamp(b + 0.36 * ridge)

        # Star crystal glints
        for gx, gy, rad, strength in glints:
            gl = strength * math.exp(-((math.hypot(nx - gx, ny - gy) / rad) ** 2))
            r, g, b = clamp(r + gl), clamp(g + gl * 0.96), clamp(b + gl * 0.96)

        col = over(col, (r, g, b, gem_a))

    # 3. Thin sculpted lit metallic bezel hugging outer contour (exact ShardBezel aesthetic!)
    metal_band = smooth(-bezel_w - 0.028, -bezel_w, d_out) * (1.0 - smooth(0.004, 0.030, d_out))
    inner_lip = smooth(-bezel_w - 0.055, -bezel_w - 0.022, d_out) * (1.0 - smooth(-bezel_w - 0.005, -bezel_w + 0.015, d_out))
    if inner_lip > 0.0:
        col = over(col, (0.04, 0.04, 0.06, inner_lip * 0.58))
    if metal_band > 0.0:
        ca = enx * KEY_LIGHT[0] + eny * KEY_LIGHT[1]
        lum = 0.54 + 0.38 * max(0.0, ca) ** 1.15 - 0.22 * max(0.0, -ca) ** 1.4
        profile = smooth(-bezel_w - 0.028, -bezel_w * 0.45, d_out) * (1.0 - 0.32 * smooth(-0.02, 0.02, d_out))
        lum *= 0.62 + 0.48 * profile
        spec = max(0.0, ca) ** 3 * math.exp(-(((d_out + bezel_w * 0.45) / 0.024) ** 2)) * 0.36
        lum = clamp(lum + spec)
        col = over(col, (clamp(lum * 0.95), clamp(lum * 0.97), clamp(lum * 1.04), metal_band))

    return col


# ---------------------------------------------------------------------------
# 1. RangeIn.tga — Faceted Emerald Crystal Checkmark (NO Vista plastic circle!)
# ---------------------------------------------------------------------------

# Clean sharp crystalline checkmark polygon (clockwise in screen coords — bold jewel proportions!)
CHECK_OUTER = [
    (-0.84,  0.00),  # 0: left outer tip
    (-0.56, -0.28),  # 1: left upper bevel corner
    (-0.14,  0.12),  # 2: inner elbow V-notch
    ( 0.56, -0.72),  # 3: right upper tip
    ( 0.86, -0.44),  # 4: right outer shoulder
    (-0.14,  0.74),  # 5: bottom pointed jewel tip
]
CHECK_EDGES = poly_edges(CHECK_OUTER)
# Spine vertices along the crisp central facet ridge
CK_L = (-0.66, -0.10)
CK_V = (-0.14,  0.42)
CK_R = ( 0.70, -0.56)

CHECK_FACETS = [
    # Left short arm: upper-lit bevel vs lower-shaded bevel
    ((CHECK_OUTER[0], CHECK_OUTER[1], CK_L), norm3(-0.62, -0.55, 0.56), {}),
    ((CHECK_OUTER[1], CHECK_OUTER[2], CK_L), norm3( 0.44, -0.60, 0.66), {}),
    ((CHECK_OUTER[2], CK_V,           CK_L), norm3( 0.44, -0.60, 0.66), {}),
    ((CHECK_OUTER[0], CK_L,           CK_V), norm3(-0.52,  0.54, 0.66), {"sub": 0.24}),
    ((CHECK_OUTER[0], CK_V, CHECK_OUTER[5]), norm3(-0.52,  0.54, 0.66), {"sub": 0.28}),
    # Right long arm: upper-left sunlit bevel vs lower-right deep emerald bevel
    ((CHECK_OUTER[2], CHECK_OUTER[3], CK_R), norm3(-0.58, -0.56, 0.59), {}),
    ((CHECK_OUTER[2], CK_R,           CK_V), norm3(-0.58, -0.56, 0.59), {}),
    ((CHECK_OUTER[3], CHECK_OUTER[4], CK_R), norm3( 0.52, -0.52, 0.68), {}),
    ((CK_R,           CHECK_OUTER[4], CHECK_OUTER[5]), norm3( 0.60,  0.54, 0.59), {"sub": 0.26}),
    ((CK_V,           CK_R,           CHECK_OUTER[5]), norm3( 0.60,  0.54, 0.59), {"sub": 0.26}),
]
CHECK_RIDGES = [
    (CK_L, CK_V, 0.95),
    (CK_V, CK_R, 1.00),
    (CHECK_OUTER[2], CK_V, 0.65),
    (CK_V, CHECK_OUTER[5], 0.48),
]
CHECK_GLINTS = [
    (0.56, -0.48, 0.10, 0.62),
    (-0.54, -0.06, 0.085, 0.44),
]


def range_in(nx, ny):
    return shade_faceted_crystal(nx, ny, CHECK_EDGES, CHECK_FACETS, CHECK_RIDGES, CHECK_GLINTS, EMERALD_CRYSTAL, 0.042)


# ---------------------------------------------------------------------------
# 2. RangeOut.tga — Faceted Ruby Crystal Cross (NO Vista plastic circle!)
# ---------------------------------------------------------------------------

# Sharp 12-vertex crystalline faceted X (bold ruby-blade proportions!)
_A = 0.80   # arm outer extent
_T = 0.46   # shoulder width along arm
_C = 0.30   # inner crossing notch
CROSS_OUTER = [
    (-_A, -_T), (-_T, -_A), (0.0, -_C),
    ( _T, -_A), ( _A, -_T), ( _C, 0.0),
    ( _A,  _T), ( _T,  _A), (0.0,  _C),
    (-_T,  _A), (-_A,  _T), (-_C, 0.0),
]
CROSS_EDGES = poly_edges(CROSS_OUTER)
CR_CTR = (0.0, 0.0)
CR_TL = (-0.63, -0.63)
CR_TR = ( 0.63, -0.63)
CR_BR = ( 0.63,  0.63)
CR_BL = (-0.63,  0.63)

CROSS_FACETS = [
    # Upper-left arm (catches brilliant key light!)
    ((CROSS_OUTER[0], CROSS_OUTER[1], CR_TL), norm3(-0.62, -0.62, 0.48), {}),
    ((CROSS_OUTER[1], CROSS_OUTER[2], CR_CTR), norm3( 0.44, -0.64, 0.63), {}),
    ((CROSS_OUTER[1], CR_CTR,         CR_TL), norm3( 0.44, -0.64, 0.63), {}),
    ((CROSS_OUTER[0], CR_TL,          CR_CTR), norm3(-0.64,  0.44, 0.63), {}),
    ((CROSS_OUTER[0], CR_CTR, CROSS_OUTER[11]), norm3(-0.64,  0.44, 0.63), {}),
    # Upper-right arm
    ((CROSS_OUTER[3], CROSS_OUTER[4], CR_TR), norm3( 0.62, -0.62, 0.48), {}),
    ((CROSS_OUTER[2], CROSS_OUTER[3], CR_TR), norm3(-0.52, -0.58, 0.63), {}),
    ((CROSS_OUTER[2], CR_TR,          CR_CTR), norm3(-0.52, -0.58, 0.63), {}),
    ((CR_CTR,         CR_TR, CROSS_OUTER[4]), norm3( 0.64,  0.44, 0.63), {"sub": 0.20}),
    ((CR_CTR, CROSS_OUTER[4], CROSS_OUTER[5]), norm3( 0.64,  0.44, 0.63), {"sub": 0.20}),
    # Lower-right arm (shaded + ruby internal refraction)
    ((CROSS_OUTER[6], CROSS_OUTER[7], CR_BR), norm3( 0.62,  0.62, 0.48), {"sub": 0.28}),
    ((CROSS_OUTER[5], CROSS_OUTER[6], CR_BR), norm3( 0.62, -0.46, 0.63), {"sub": 0.20}),
    ((CROSS_OUTER[5], CR_BR,          CR_CTR), norm3( 0.62, -0.46, 0.63), {"sub": 0.20}),
    ((CR_CTR,         CR_BR, CROSS_OUTER[7]), norm3(-0.46,  0.64, 0.61), {"sub": 0.28}),
    ((CR_CTR, CROSS_OUTER[7], CROSS_OUTER[8]), norm3(-0.46,  0.64, 0.61), {"sub": 0.28}),
    # Lower-left arm
    ((CROSS_OUTER[9], CROSS_OUTER[10], CR_BL), norm3(-0.62,  0.62, 0.48), {"sub": 0.24}),
    ((CROSS_OUTER[11], CR_CTR,        CR_BL), norm3(-0.58, -0.50, 0.64), {}),
    ((CROSS_OUTER[11], CR_BL, CROSS_OUTER[10]), norm3(-0.58, -0.50, 0.64), {}),
    ((CR_CTR, CROSS_OUTER[8], CROSS_OUTER[9]), norm3( 0.50,  0.60, 0.62), {"sub": 0.26}),
    ((CR_CTR, CROSS_OUTER[9],         CR_BL), norm3( 0.50,  0.60, 0.62), {"sub": 0.26}),
]
CROSS_RIDGES = [
    (CR_TL, CR_BR, 0.95),
    (CR_TR, CR_BL, 0.95),
    (CROSS_OUTER[2], CR_CTR, 0.50),
    (CROSS_OUTER[11], CR_CTR, 0.55),
]
CROSS_GLINTS = [
    (-0.48, -0.48, 0.095, 0.64),
    ( 0.00,  0.00, 0.11,  0.40),
]


def range_out(nx, ny):
    return shade_faceted_crystal(nx, ny, CROSS_EDGES, CROSS_FACETS, CROSS_RIDGES, CROSS_GLINTS, RUBY_CRYSTAL, 0.042)


# ---------------------------------------------------------------------------
# 3 & 4. ArrowUp.tga & ArrowDown.tga — Faceted Emerald & Ruby Crystal Arrows
# ---------------------------------------------------------------------------

ARROW_OUTER = [
    ( 0.00, -0.84),  # 0: top apex
    ( 0.72,  0.02),  # 1: right wing tip
    ( 0.28,  0.02),  # 2: right inner notch
    ( 0.28,  0.76),  # 3: right shaft base
    (-0.28,  0.76),  # 4: left shaft base
    (-0.28,  0.02),  # 5: left inner notch
    (-0.72,  0.02),  # 6: left wing tip
]
ARROW_EDGES = poly_edges(ARROW_OUTER)
AR_MID = (0.0, -0.08)
AR_BOT = (0.0,  0.76)

ARROW_FACETS = [
    # Arrowhead: crisp sunlit left facet vs shaded right facet + bottom jewel bevel
    ((ARROW_OUTER[0], AR_MID, ARROW_OUTER[6]), norm3(-0.62, -0.48, 0.62), {}),
    ((ARROW_OUTER[6], AR_MID, ARROW_OUTER[5]), norm3(-0.30,  0.62, 0.72), {"sub": 0.16}),
    ((ARROW_OUTER[0], ARROW_OUTER[1], AR_MID), norm3( 0.62, -0.48, 0.62), {}),
    ((AR_MID, ARROW_OUTER[1], ARROW_OUTER[2]), norm3( 0.30,  0.62, 0.72), {"sub": 0.22}),
    # Shaft: split cleanly along central crystal spine
    ((ARROW_OUTER[5], AR_MID, AR_BOT), norm3(-0.64,  0.10, 0.76), {}),
    ((ARROW_OUTER[5], AR_BOT, ARROW_OUTER[4]), norm3(-0.64,  0.10, 0.76), {"sub": 0.18}),
    ((AR_MID, ARROW_OUTER[2], ARROW_OUTER[3]), norm3( 0.64,  0.12, 0.76), {"sub": 0.24}),
    ((AR_MID, ARROW_OUTER[3], AR_BOT), norm3( 0.64,  0.12, 0.76), {"sub": 0.24}),
]
ARROW_RIDGES = [
    (ARROW_OUTER[0], AR_BOT, 1.00),
    (ARROW_OUTER[6], AR_MID, 0.68),
    (ARROW_OUTER[1], AR_MID, 0.50),
]
ARROW_GLINTS = [
    (-0.10, -0.52, 0.095, 0.58),
]


def arrow_up(nx, ny):
    return shade_faceted_crystal(nx, ny, ARROW_EDGES, ARROW_FACETS, ARROW_RIDGES, ARROW_GLINTS, EMERALD_CRYSTAL, 0.068)


def arrow_down(nx, ny):
    # Mirror polygon vertically while keeping top-left key light natural!
    v = [(x, -y) for (x, y) in reversed(ARROW_OUTER)]
    edges = poly_edges(v)
    mid = (0.0, 0.08)
    top = (0.0, -0.76)
    facets = [
        # Top shaft: left sunlit vs right shaded
        (((-0.28, -0.76), top, mid), norm3(-0.64, -0.18, 0.75), {}),
        (((-0.28, -0.76), mid, (-0.28, -0.02)), norm3(-0.64, -0.18, 0.75), {}),
        ((top, (0.28, -0.76), (0.28, -0.02)), norm3( 0.64, -0.16, 0.75), {}),
        ((top, (0.28, -0.02), mid), norm3( 0.64, -0.16, 0.75), {}),
        # Downward arrowhead: upper bevel + sharp left/right crystal facets
        (((-0.72, -0.02), (-0.28, -0.02), mid), norm3(-0.34, -0.64, 0.69), {}),
        ((( 0.28, -0.02), ( 0.72, -0.02), mid), norm3( 0.34, -0.64, 0.69), {}),
        (((-0.72, -0.02), mid, (0.0, 0.84)), norm3(-0.62,  0.46, 0.63), {"sub": 0.20}),
        ((mid, (0.72, -0.02), (0.0, 0.84)), norm3( 0.62,  0.46, 0.63), {"sub": 0.28}),
    ]
    ridges = [
        (top, (0.0, 0.84), 1.00),
        ((-0.72, -0.02), mid, 0.72),
        (( 0.72, -0.02), mid, 0.50),
    ]
    glints = [(-0.14, -0.44, 0.095, 0.56)]
    return shade_faceted_crystal(nx, ny, edges, facets, ridges, glints, RUBY_CRYSTAL, 0.068)


# ---------------------------------------------------------------------------
# 5, 6, 7. Core/Textures/MarkerDiamond.tga, MarkerDiamondBezel.tga, MarkerSegment.tga
# ---------------------------------------------------------------------------

DIAMOND_OUTER = [(0.0, -0.86), (0.86, 0.0), (0.0, 0.86), (-0.86, 0.0)]
DIAMOND_TABLE = [(0.0, -0.44), (0.44, 0.0), (0.0, 0.44), (-0.44, 0.0)]
D_OUTER_EDGES = poly_edges(DIAMOND_OUTER)
D_TABLE_EDGES = poly_edges(DIAMOND_TABLE)
D_FACET_NORMALS = [
    norm3( 0.56, -0.56, 0.61),
    norm3( 0.56,  0.56, 0.61),
    norm3(-0.56,  0.56, 0.61),
    norm3(-0.56, -0.56, 0.61),
]


def marker_diamond(nx, ny):
    d_out, _ = signed_dist_convex(nx, ny, D_OUTER_EDGES)
    alpha = 1.0 - smooth(-0.025, 0.02, d_out)
    if alpha <= 0.0:
        return 0.0, 0.0, 0.0, 0.0

    d_tab, _ = signed_dist_convex(nx, ny, D_TABLE_EDGES)
    if d_tab <= 0.0:
        core_d = math.hypot(nx + 0.04, ny + 0.04) / 0.34
        inner_glow = math.exp(-(core_d * core_d) * 1.1)
        tilt = clamp(0.68 - nx * 0.35 - ny * 0.35, 0.35, 1.0)
        lum = 0.56 + 0.24 * inner_glow + 0.18 * tilt
        lum += smooth(-0.08, 0.0, d_tab) * clamp((-nx - ny) * 1.5) * 0.22
    else:
        facet = 0 if (nx >= 0 and ny < 0) else 1 if (nx >= 0 and ny >= 0) else 2 if (nx < 0 and ny >= 0) else 3
        fn = D_FACET_NORMALS[facet]
        diff = max(0.0, fn[0] * KEY_LIGHT[0] + fn[1] * KEY_LIGHT[1] + fn[2] * KEY_LIGHT[2])
        spec = max(0.0, fn[0] * HALF_KEY[0] + fn[1] * HALF_KEY[1] + fn[2] * HALF_KEY[2]) ** 10
        bounce = max(0.0, fn[0] * BOUNCE_LIGHT[0] + fn[1] * BOUNCE_LIGHT[1] + fn[2] * BOUNCE_LIGHT[2])
        lum = 0.38 + 0.46 * diff + 0.34 * spec + 0.12 * bounce
        if facet == 3:
            lum += 0.10
        elif facet in (1, 2):
            lum += 0.10 * smooth(0.0, 0.20, d_tab) * (1.0 - smooth(-0.08, 0.0, d_out))

    ridge = 0.0
    for i in range(4):
        dr = dist_seg(nx, ny, DIAMOND_OUTER[i][0], DIAMOND_OUTER[i][1], DIAMOND_TABLE[i][0], DIAMOND_TABLE[i][1])
        ridge = max(ridge, (0.95 if i in (0, 3) else 0.45) * math.exp(-((dr / 0.030) ** 2)))
    ridge = max(ridge, (0.65 if (nx + ny) < 0.08 else 0.30) * math.exp(-((abs(d_tab) / 0.026) ** 2)))
    lum += 0.28 * ridge
    lum += 0.40 * math.exp(-((math.hypot(nx + 0.22, ny + 0.22) / 0.09) ** 2))
    lum = clamp(lum, 0.34, 1.0)
    return lum, lum, lum, alpha


def marker_diamond_bezel(nx, ny):
    d_out, edge_i = signed_dist_convex(nx, ny, D_OUTER_EDGES)
    outer_shadow = smooth(-0.01, 0.02, d_out) * (1.0 - smooth(0.075, 0.125, d_out))
    metal_band = smooth(-0.115, -0.08, d_out) * (1.0 - smooth(0.005, 0.032, d_out))
    inner_lip = smooth(-0.145, -0.115, d_out) * (1.0 - smooth(-0.09, -0.065, d_out))

    col = (0.0, 0.0, 0.0, 0.0)
    if outer_shadow > 0.0:
        col = (0.04, 0.04, 0.06, outer_shadow * 0.92)
    if inner_lip > 0.0:
        col = over(col, (0.05, 0.05, 0.07, inner_lip * 0.60))
    if metal_band > 0.0:
        _, _, _, _, enx, eny, _ = D_OUTER_EDGES[edge_i]
        ca = enx * KEY_LIGHT[0] + eny * KEY_LIGHT[1]
        lum = 0.56 + 0.36 * max(0.0, ca) ** 1.2 - 0.22 * max(0.0, -ca) ** 1.4
        profile = smooth(-0.115, -0.055, d_out) * (1.0 - 0.32 * smooth(-0.025, 0.02, d_out))
        lum *= 0.60 + 0.48 * profile
        spec = max(0.0, ca) ** 3 * math.exp(-(((d_out + 0.052) / 0.026) ** 2)) * 0.34
        lum = clamp(lum + spec)
        col = over(col, (clamp(lum * 0.96), clamp(lum * 0.97), clamp(lum * 1.03), metal_band))
    return col


# Crisp faceted crystal-bar segment (planar top/bottom/left/right chamfers matching Soul Shard!)
SEG_OUTER = [(-1.86, -0.82), (1.86, -0.82), (1.94, -0.68), (1.94, 0.68), (1.86, 0.82), (-1.86, 0.82), (-1.94, 0.68), (-1.94, -0.68)]
SEG_EDGES = poly_edges(SEG_OUTER)


def marker_segment(nx, ny):
    px, py = nx * 2.0, ny
    d_out, _ = signed_dist_convex(px, py, SEG_EDGES)
    alpha = 1.0 - smooth(-0.05, 0.04, d_out)
    if alpha <= 0.0:
        return 0.0, 0.0, 0.0, 0.0
    # Crisp faceted chamfer planes instead of soft tube shading
    if py < -0.44:
        lum = 0.98 - 0.06 * nx  # top lit chamfer
    elif py > 0.44:
        lum = 0.56 - 0.05 * nx  # bottom shadow chamfer
    elif px < -1.56:
        lum = 0.92              # left lit chamfer
    elif px > 1.56:
        lum = 0.62              # right shaded chamfer
    else:
        lum = 0.82 - 0.10 * py - 0.05 * nx
    # Sharp ridge highlight along top chamfer seam
    ridge = math.exp(-(((py + 0.44) / 0.065) ** 2)) * (1.0 if abs(px) < 1.62 else 0.4)
    lum += 0.20 * ridge
    # Crisp dark bevel border at very perimeter
    edge = 1.0 - 0.45 * smooth(-0.14, 0.0, d_out)
    lum = clamp(lum * edge, 0.32, 1.0)
    return lum, lum, lum, alpha


# ---------------------------------------------------------------------------
# 8, 9, 10. Stylized 2D faceted Kill Emblems (KillSkull2D, KillCrosshair, KillBlades)
# Clean geometric 2D silhouettes, crisp planar cel/facet shading, razor dark outlines
# — exact same 2D vector/faceted aesthetic as ShardGem + RangeIn + ArrowUp!
# ---------------------------------------------------------------------------

BONE_2D = [
    (0.00, (0.44, 0.38, 0.30)),   # crisp warm bone shadow plane
    (0.45, (0.74, 0.68, 0.56)),   # mid bone plane
    (0.75, (0.93, 0.89, 0.78)),   # lit ivory plane
    (1.05, (1.00, 0.99, 0.93)),   # crisp top-left highlight
]

GOLD_2D = [
    (0.00, (0.38, 0.22, 0.04)),
    (0.42, (0.76, 0.52, 0.10)),
    (0.76, (0.98, 0.78, 0.22)),
    (1.08, (1.00, 0.96, 0.68)),
]

STEEL_2D = [
    (0.00, (0.24, 0.29, 0.38)),
    (0.42, (0.50, 0.57, 0.68)),
    (0.76, (0.82, 0.88, 0.96)),
    (1.08, (0.99, 1.00, 1.00)),
]


def sd_ellipse(px, py, cx, cy, rx, ry):
    dx, dy = (px - cx) / rx, (py - cy) / ry
    k0 = math.hypot(dx, dy)
    if k0 < 1e-9:
        return -min(rx, ry)
    k1 = math.hypot(dx / rx, dy / ry)
    return k0 * (k0 - 1.0) / k1


def sd_round_box(px, py, bx, by, r):
    qx = abs(px) - bx + r
    qy = abs(py) - by + r
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


# 8. KillSkull2D.tga — Crisp stylized 2D angular/faceted vector death skull
SKULL_2D_OUTER = [
    ( 0.00, -0.82),  # 0: crown top
    ( 0.44, -0.70),  # 1: right forehead
    ( 0.68, -0.34),  # 2: right temple
    ( 0.64,  0.14),  # 3: right cheekbone peak
    ( 0.44,  0.34),  # 4: right cheek tuck
    ( 0.36,  0.66),  # 5: right jaw corner
    ( 0.20,  0.76),  # 6: right chin
    (-0.20,  0.76),  # 7: left chin
    (-0.36,  0.66),  # 8: left jaw corner
    (-0.44,  0.34),  # 9: left cheek tuck
    (-0.64,  0.14),  # 10: left cheekbone peak
    (-0.68, -0.34),  # 11: left temple
    (-0.44, -0.70),  # 12: left forehead
]
SKULL_2D_EDGES = poly_edges(SKULL_2D_OUTER)

EYE_L_POLY = [(-0.44, -0.14), (-0.12, -0.02), (-0.16, 0.16), (-0.42, 0.14)]
EYE_R_POLY = [( 0.12, -0.02), ( 0.44, -0.14), ( 0.42, 0.14), ( 0.16, 0.16)]
EYE_L_EDGES = poly_edges(EYE_L_POLY)
EYE_R_EDGES = poly_edges(EYE_R_POLY)
NOSE_POLY = [(0.00, 0.12), (0.11, 0.34), (0.00, 0.30), (-0.11, 0.34)]
NOSE_EDGES = poly_edges(NOSE_POLY)


def kill_skull_2d(nx, ny):
    d_out, _, _ = signed_dist_poly(nx, ny, SKULL_2D_EDGES)
    col = (0.0, 0.0, 0.0, 0.0)

    # Bold crisp 2D dark obsidian outline
    rim_a = 1.0 - smooth(0.06, 0.11, d_out)
    if rim_a > 0.0:
        col = (0.04, 0.03, 0.05, rim_a * 0.98)

    fill_a = 1.0 - smooth(-0.02, 0.02, d_out)
    if fill_a <= 0.0:
        return col

    # Clean stylized 2D cel/facet shading: sharp stepped tonal planes, ZERO soft 3D airbrush!
    # Diagonal light axis from upper-left (-0.65, -0.76)
    ldot = -nx * 0.62 - ny * 0.72
    if ldot > 0.36:
        tone = 0.98   # bright sunlit upper-left forehead highlight plane
    elif ldot > 0.05:
        tone = 0.80   # clean lit ivory face plane
    elif ldot > -0.30:
        tone = 0.56   # mid warm bone plane
    else:
        tone = 0.28   # crisp lower-right shadow plane
    # Slight brow ridge highlight band above eyes (crisp 2D graphic accent)
    if -0.26 < ny < -0.11 and abs(nx) < 0.46:
        tone = max(tone, 0.88 if nx < 0.10 else 0.70)
    # Cheekbone crisp highlight facets
    if 0.12 < ny < 0.26 and 0.26 < abs(nx) < 0.56:
        tone = max(tone, 0.86 if nx < 0 else 0.64)
    # Subtle crisp 2D inner edge dark accent along lower-right contour
    if d_out > -0.075 and (nx + ny) > 0.0:
        tone *= 0.74
    r, g, b = ramp(tone, BONE_2D)

    # Crisp 2D graphic forehead crack (upper-right)
    dc = min(dist_seg(nx, ny, 0.24, -0.74, 0.14, -0.48),
             dist_seg(nx, ny, 0.14, -0.48, 0.22, -0.34))
    crack_a = 1.0 - smooth(0.015, 0.028, dc)
    if crack_a > 0.0:
        r, g, b = lerp3((r, g, b), (0.12, 0.09, 0.08), crack_a * 0.85)

    # Clean stylized teeth slits in lower jaw
    if ny > 0.44 and abs(nx) < 0.34:
        gum = 1.0 - smooth(0.016, 0.030, abs(ny - 0.48))
        r, g, b = lerp3((r, g, b), (0.16, 0.12, 0.10), gum * 0.85)
        for tx in (-0.16, 0.0, 0.16):
            slit = (1.0 - smooth(0.018, 0.032, abs(nx - tx))) * smooth(0.46, 0.52, ny)
            r, g, b = lerp3((r, g, b), (0.06, 0.04, 0.05), slit * 0.95)

    # Crisp angular 2D eye sockets with sharp faceted glowing crimson-amber diamond eyes
    dl, _, _ = signed_dist_poly(nx, ny, EYE_L_EDGES)
    dr, _, _ = signed_dist_poly(nx, ny, EYE_R_EDGES)
    d_eye = min(dl, dr)
    eye_a = 1.0 - smooth(-0.018, 0.018, d_eye)
    if eye_a > 0.0:
        er, eg, eb = 0.06, 0.02, 0.03
        # Sharp 2D diamond pupil ember inside each socket
        pl = abs(nx + 0.27) + abs(ny - 0.04)
        pr = abs(nx - 0.27) + abs(ny - 0.04)
        dp = min(pl, pr)
        if dp < 0.095:
            p_a = 1.0 - smooth(0.065, 0.095, dp)
            inner = 1.0 - smooth(0.025, 0.055, dp)
            pcol = lerp3((0.96, 0.20, 0.12), (1.00, 0.88, 0.32), inner)
            er, eg, eb = lerp3((er, eg, eb), pcol, p_a)
        r, g, b = lerp3((r, g, b), (er, eg, eb), eye_a)

    # Crisp angular 2D nasal cavity
    dn, _, _ = signed_dist_poly(nx, ny, NOSE_EDGES)
    nose_a = 1.0 - smooth(-0.015, 0.018, dn)
    if nose_a > 0.0:
        r, g, b = lerp3((r, g, b), (0.07, 0.04, 0.05), nose_a)

    return over(col, (r, g, b, fill_a))


# 9. KillCrosshair.tga — Crisp stylized 2D faceted gold reticle + ruby shard bullseye
_OCT_OUT = [(0.74 * math.cos(a), 0.74 * math.sin(a)) for a in [(i + 0.5) * math.pi / 4 for i in range(8)]]
_OCT_IN = [(0.52 * math.cos(a), 0.52 * math.sin(a)) for a in [(i + 0.5) * math.pi / 4 for i in range(8)]]
OCT_OUT_EDGES = poly_edges(_OCT_OUT)
OCT_IN_EDGES = poly_edges(_OCT_IN)

CORE_GEM = [(0.0, -0.26), (0.26, 0.0), (0.0, 0.26), (-0.26, 0.0)]
CORE_TAB = [(0.0, -0.13), (0.13, 0.0), (0.0, 0.13), (-0.13, 0.0)]
CORE_OUT_EDGES = poly_edges(CORE_GEM)
CORE_TAB_EDGES = poly_edges(CORE_TAB)


def _cardinal_spike_2d(x, y):
    ax, ay = abs(x), abs(y)
    if ay > ax:
        ax, ay = ay, ax
    # Bold 2D kite/diamond spear from r=0.33 to r=0.90, peak width 0.13 at r=0.62
    verts = [(0.33, 0.0), (0.62, -0.13), (0.90, 0.0), (0.62, 0.13)]
    d, _ = signed_dist_convex(ax, ay, poly_edges(verts))
    return d


def kill_crosshair_2d(nx, ny):
    col = (0.0, 0.0, 0.0, 0.0)
    d_o, _ = signed_dist_convex(nx, ny, OCT_OUT_EDGES)
    d_i, _ = signed_dist_convex(nx, ny, OCT_IN_EDGES)
    d_ring = max(d_o, -d_i)
    d_sp = _cardinal_spike_2d(nx, ny)
    d_core, _ = signed_dist_convex(nx, ny, CORE_OUT_EDGES)

    # Subtle crisp 2D dark tinted interior glass
    if d_i < 0.0:
        col = (0.08, 0.02, 0.03, (1.0 - smooth(-0.04, 0.02, d_i)) * 0.45)

    # Crisp 2D dark obsidian outline behind entire reticle
    d_all = min(d_ring, d_sp, d_core)
    rim_a = 1.0 - smooth(0.035, 0.085, d_all)
    if rim_a > 0.0:
        col = over(col, (0.04, 0.02, 0.03, rim_a * 0.96))

    # Crisp 2D crimson crosshair lines inside glass
    if d_i < -0.02 and d_core > 0.02:
        line = max(1.0 - smooth(0.015, 0.028, abs(nx)), 1.0 - smooth(0.015, 0.028, abs(ny)))
        if line > 0.0:
            col = over(col, (0.94, 0.16, 0.20, line * 0.78))

    # Stylized 2D faceted octagonal gold ring (sharp planar cel split, NO blurry torus!)
    ring_a = 1.0 - smooth(-0.015, 0.018, d_ring)
    if ring_a > 0.0:
        # Sharp 2D inner vs outer chamfer + directional facet tone
        mid_r = (d_o + d_i) * 0.5  # negative toward center, positive toward outer
        ldot = -nx * 0.65 - ny * 0.65
        base_t = 0.88 if ldot > 0.22 else (0.64 if ldot > -0.22 else 0.34)
        # Outer bevel slightly darker than inner bright chamfer
        if d_o > -0.08:
            base_t -= 0.16
        elif d_i > -0.07:
            base_t += 0.14
        gr, gg, gb = ramp(clamp(base_t, 0.05, 1.08), GOLD_2D)
        # Crisp crimson inlay line right along ring center
        if abs(d_o + 0.11) < 0.026:
            gr, gg, gb = lerp3((gr, gg, gb), (0.78, 0.10, 0.14), 0.75)
        col = over(col, (gr, gg, gb, ring_a))

    # Stylized 2D faceted cardinal spikes (razor 2-facet light/shadow split!)
    sp_a = 1.0 - smooth(-0.015, 0.018, d_sp)
    if sp_a > 0.0:
        if abs(nx) >= abs(ny):
            lit = (ny < 0.0)
            ridge_d = abs(ny)
        else:
            lit = (nx < 0.0)
            ridge_d = abs(nx)
        # Left/top half bright gold, right/bottom half deep antique gold
        tone = 0.94 if lit else 0.42
        if (-nx - ny) > 0.25:
            tone += 0.12
        sr, sg, sb = ramp(clamp(tone, 0.05, 1.08), GOLD_2D)
        ridge = math.exp(-((ridge_d / 0.018) ** 2)) * 0.28
        col = over(col, (clamp(sr + ridge), clamp(sg + ridge * 0.9), clamp(sb + ridge * 0.5), sp_a))

    # Center 2D faceted ruby crystal bullseye (exact Soul Shard / MarkerDiamond facet look!)
    core_a = 1.0 - smooth(-0.015, 0.018, d_core)
    if core_a > 0.0:
        d_tab, _ = signed_dist_convex(nx, ny, CORE_TAB_EDGES)
        if d_tab <= 0.0:
            v = 0.88 - 0.35 * (nx + ny)
        else:
            facet = 0 if (nx >= 0 and ny < 0) else 1 if (nx >= 0 and ny >= 0) else 2 if (nx < 0 and ny >= 0) else 3
            v = (0.72, 0.32, 0.54, 1.06)[facet]
        rr, rg, rb = ramp(v, RUBY_CRYSTAL)
        glint = 0.55 * math.exp(-((math.hypot(nx + 0.06, ny + 0.06) / 0.05) ** 2))
        col = over(col, (clamp(rr + glint), clamp(rg + glint * 0.85), clamp(rb + glint * 0.85), core_a))

    return col


# 10. KillBlades.tga — Crisp stylized 2D crossed faceted steel & gold execution daggers
def _dagger_2d(nx, ny, angle):
    ca, sa = math.cos(angle), math.sin(angle)
    lx = nx * ca + ny * sa
    ly = -nx * sa + ny * ca

    # Sharp 2D angular blade polygon (tip at y=-0.84, shoulders at y=-0.50, base at y=0.26)
    blade_poly = [(0.0, -0.84), (0.145, -0.48), (0.118, 0.26), (-0.118, 0.26), (-0.145, -0.48)]
    d_blade, _ = signed_dist_convex(lx, ly, poly_edges(blade_poly))
    # Angular diamond-shaped crossguard
    guard_poly = [(-0.34, 0.30), (-0.22, 0.23), (0.22, 0.23), (0.34, 0.30), (0.22, 0.37), (-0.22, 0.37)]
    d_guard, _ = signed_dist_convex(lx, ly, poly_edges(guard_poly))
    # Grip
    d_grip = sd_round_box(lx, ly - 0.52, 0.062, 0.16, 0.02)
    # Faceted diamond pommel
    pom_poly = [(0.0, 0.63), (0.115, 0.74), (0.0, 0.85), (-0.115, 0.74)]
    d_pom, _ = signed_dist_convex(lx, ly, poly_edges(pom_poly))

    d_all = min(d_blade, d_guard, d_grip, d_pom)
    col = (0.0, 0.0, 0.0, 0.0)

    # Crisp dark obsidian 2D outline
    rim_a = 1.0 - smooth(0.025, 0.075, d_all)
    if rim_a > 0.0:
        col = (0.04, 0.03, 0.05, rim_a * 0.97)

    # Grip (flat cel-shaded dark crimson leather)
    grip_a = 1.0 - smooth(-0.012, 0.015, d_grip)
    if grip_a > 0.0:
        gcol = (0.42, 0.14, 0.14) if lx < 0 else (0.24, 0.07, 0.08)
        col = over(col, (gcol[0], gcol[1], gcol[2], grip_a))

    # Blade (crisp 2-plane 2D facet split down central spine + bright razor edge!)
    blade_a = 1.0 - smooth(-0.012, 0.015, d_blade)
    if blade_a > 0.0:
        # Left facet brightly lit silver-ice, right facet cool gunmetal steel
        tone = 0.92 if lx < 0.0 else 0.44
        if ly < -0.50:
            tone += 0.10  # bright tapered tip bevel
        # Sharp white specular spine ridge
        spine = math.exp(-((lx / 0.018) ** 2)) * 0.25
        sr, sg, sb = ramp(clamp(tone + spine, 0.05, 1.08), STEEL_2D)
        # Subtle crimson glint at very tip
        if ly < -0.60:
            sr, sg, sb = lerp3((sr, sg, sb), (0.96, 0.20, 0.24), smooth(-0.60, -0.82, ly) * 0.35)
        col = over(col, (sr, sg, sb, blade_a))

    # Crossguard (crisp 2D faceted gold)
    guard_a = 1.0 - smooth(-0.012, 0.015, d_guard)
    if guard_a > 0.0:
        tone = 0.94 if (ly < 0.30) else 0.44
        if lx < 0:
            tone += 0.08
        gr, gg, gb = ramp(clamp(tone, 0.05, 1.08), GOLD_2D)
        col = over(col, (gr, gg, gb, guard_a))

    # Diamond ruby-in-gold pommel
    pom_a = 1.0 - smooth(-0.012, 0.015, d_pom)
    if pom_a > 0.0:
        inner = abs(lx) + abs(ly - 0.74) < 0.062
        if inner:
            pr, pg, pb = ramp(0.95 if lx < 0 else 0.55, RUBY_CRYSTAL)
        else:
            pr, pg, pb = ramp(0.90 if ly < 0.74 else 0.42, GOLD_2D)
        col = over(col, (pr, pg, pb, pom_a))

    return col


def kill_blades_2d(nx, ny):
    sx, sy = nx * 0.90, ny * 0.90
    col = _dagger_2d(sx, sy, -0.76)
    col = over(col, _dagger_2d(sx, sy, 0.76))
    return col


# 11. MeleeSword.tga — Crisp stylized 2D diagonal hunter broadsword (emerald gem pommel)
def melee_sword_2d(nx, ny):
    # Diagonal pointing top-right (+45 deg): rotate sample coords by +pi/4
    ang = 0.785398
    ca, sa = math.cos(ang), math.sin(ang)
    lx = (nx * ca + ny * sa) * 0.94
    ly = (-nx * sa + ny * ca) * 0.94

    # Broad angular sword blade (tip at y=-0.92, shoulders at y=-0.56, base at y=0.22)
    blade_poly = [(0.0, -0.92), (0.185, -0.54), (0.145, 0.22), (-0.145, 0.22), (-0.185, -0.54)]
    d_blade, _ = signed_dist_convex(lx, ly, poly_edges(blade_poly))
    # Winged faceted gold crossguard
    guard_poly = [(-0.42, 0.26), (-0.26, 0.17), (0.26, 0.17), (0.42, 0.26), (0.26, 0.35), (-0.26, 0.35)]
    d_guard, _ = signed_dist_convex(lx, ly, poly_edges(guard_poly))
    # Wrapped dark leather grip
    d_grip = sd_round_box(lx, ly - 0.50, 0.075, 0.17, 0.024)
    # Faceted diamond emerald-in-gold pommel
    pom_poly = [(0.0, 0.62), (0.14, 0.76), (0.0, 0.90), (-0.14, 0.76)]
    d_pom, _ = signed_dist_convex(lx, ly, poly_edges(pom_poly))

    d_all = min(d_blade, d_guard, d_grip, d_pom)
    col = (0.0, 0.0, 0.0, 0.0)

    # Crisp obsidian 2D outline
    rim_a = 1.0 - smooth(0.025, 0.078, d_all)
    if rim_a > 0.0:
        col = (0.04, 0.03, 0.05, rim_a * 0.98)

    # Leather grip (cel-shaded warm umber)
    grip_a = 1.0 - smooth(-0.012, 0.015, d_grip)
    if grip_a > 0.0:
        gcol = (0.44, 0.28, 0.15) if lx < 0 else (0.24, 0.14, 0.08)
        col = over(col, (gcol[0], gcol[1], gcol[2], grip_a))

    # Steel broadsword blade (razor 2-facet light/shadow split + bright tip bevel + emerald fuller glint)
    blade_a = 1.0 - smooth(-0.012, 0.015, d_blade)
    if blade_a > 0.0:
        tone = 0.95 if lx < 0.0 else 0.44
        if ly < -0.54:
            tone += 0.10
        spine = math.exp(-((lx / 0.020) ** 2)) * 0.28
        sr, sg, sb = ramp(clamp(tone + spine, 0.05, 1.08), STEEL_2D)
        # Subtle bright emerald edge sheen near crossguard to pair with Hunter MELEE green
        if ly > -0.18 and abs(lx) < 0.045:
            sr, sg, sb = lerp3((sr, sg, sb), (0.18, 0.90, 0.44), 0.30 * (1.0 - smooth(-0.18, 0.20, -ly)))
        col = over(col, (sr, sg, sb, blade_a))

    # Faceted gold crossguard
    guard_a = 1.0 - smooth(-0.012, 0.015, d_guard)
    if guard_a > 0.0:
        tone = 0.95 if (ly < 0.26) else 0.42
        if lx < 0:
            tone += 0.08
        gr, gg, gb = ramp(clamp(tone, 0.05, 1.08), GOLD_2D)
        col = over(col, (gr, gg, gb, guard_a))

    # Emerald crystal-in-gold pommel
    pom_a = 1.0 - smooth(-0.012, 0.015, d_pom)
    if pom_a > 0.0:
        inner = abs(lx) + abs(ly - 0.76) < 0.080
        if inner:
            pr, pg, pb = ramp(0.95 if lx < 0 else 0.55, EMERALD_CRYSTAL)
        else:
            pr, pg, pb = ramp(0.92 if ly < 0.76 else 0.42, GOLD_2D)
        col = over(col, (pr, pg, pb, pom_a))

    return col


def main():
    write_rgba_tga(ROOT / "Modules" / "Range" / "Textures" / "RangeIn.tga", 64, 64, range_in)
    write_rgba_tga(ROOT / "Modules" / "Range" / "Textures" / "RangeOut.tga", 64, 64, range_out)
    write_rgba_tga(ROOT / "Modules" / "StatsInfo" / "Textures" / "ArrowUp.tga", 64, 64, arrow_up)
    write_rgba_tga(ROOT / "Modules" / "StatsInfo" / "Textures" / "ArrowDown.tga", 64, 64, arrow_down)
    write_rgba_tga(ROOT / "Modules" / "DoTInfo" / "Textures" / "KillSkull2D.tga", 64, 64, kill_skull_2d)
    write_rgba_tga(ROOT / "Modules" / "DoTInfo" / "Textures" / "KillCrosshair.tga", 64, 64, kill_crosshair_2d)
    write_rgba_tga(ROOT / "Modules" / "DoTInfo" / "Textures" / "KillBlades.tga", 64, 64, kill_blades_2d)
    write_rgba_tga(ROOT / "Modules" / "HunterRangeFinder" / "Textures" / "MeleeSword.tga", 64, 64, melee_sword_2d)
    write_rgba_tga(ROOT / "Core" / "Textures" / "MarkerDiamond.tga", 64, 64, marker_diamond)
    write_rgba_tga(ROOT / "Core" / "Textures" / "MarkerDiamondBezel.tga", 64, 64, marker_diamond_bezel)
    write_rgba_tga(ROOT / "Core" / "Textures" / "MarkerSegment.tga", 64, 32, marker_segment)


if __name__ == "__main__":
    main()
