"""More generators for tools/make_fill_textures.py: organic, geometric, material, bar-shaping and colour textures.

Each generator is fn(x, y, w, h) -> (luminance, alpha) or (r, g, b, a), all 0..1. The tiled ones repeat seamlessly:
noise lattices wrap at the tile edge, cell patterns measure distance on a torus, and line patterns use whole periods.
"""
import math
import random


# ---------------------------------------------------------------- tileable noise
def lattice(seed, cells):
    rng = random.Random(seed)
    grid = [[rng.random() for _ in range(cells)] for _ in range(cells)]

    def at(x, y):  # x, y in 0..1 (one tile)
        fx, fy = x * cells, y * cells
        x0, y0 = int(math.floor(fx)), int(math.floor(fy))
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = grid[y0 % cells][x0 % cells]
        b = grid[y0 % cells][(x0 + 1) % cells]
        c = grid[(y0 + 1) % cells][x0 % cells]
        d = grid[(y0 + 1) % cells][(x0 + 1) % cells]
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    return at


def fbm(seed, base=4, octaves=4):
    layers = [lattice(seed + i * 17, base * (2 ** i)) for i in range(octaves)]
    norm = sum(0.5 ** i for i in range(octaves))

    def at(x, y):
        return sum(layer(x, y) * (0.5 ** i) for i, layer in enumerate(layers)) / norm
    return at


def voronoi(seed, count):
    rng = random.Random(seed)
    pts = [(rng.random(), rng.random()) for _ in range(count)]

    def at(x, y):  # (F1, F2) on the torus, in tile units
        best = []
        for px, py in pts:
            dx, dy = abs(x - px), abs(y - py)
            dx, dy = min(dx, 1 - dx), min(dy, 1 - dy)
            best.append(math.hypot(dx, dy))
        best.sort()
        return best[0], best[1]
    return at


def clamp(v):
    return max(0.0, min(1.0, v))


def smoothstep(a, b, v):
    t = clamp((v - a) / (b - a))
    return t * t * (3 - 2 * t)


def wrapd(a, b, period):
    d = abs(a - b) % period
    return min(d, period - d)


# ---------------------------------------------------------------- organic
def make_clouds():
    n = fbm(3, 3, 5)
    return lambda x, y, w, h: (1, 0.12 + 0.88 * smoothstep(0.25, 0.8, n((x + .5) / w, (y + .5) / h)))


def make_marble():
    n = fbm(5, 3, 4)

    def f(x, y, w, h):
        u, v = (x + .5) / w, (y + .5) / h
        t = math.sin(2 * math.pi * (2 * u + 1 * v) + 7 * n(u, v))
        vein = 1 - abs(t)
        return 0.55 + 0.45 * vein ** 3, 1.0
    return f


def make_wood():
    n = fbm(9, 3, 4)

    def f(x, y, w, h):
        u, v = (x + .5) / w, (y + .5) / h
        grain = 0.5 + 0.5 * math.sin(2 * math.pi * (5 * v + 1.5 * n(u, v)))
        return 0.5 + 0.5 * grain, 1.0
    return f


def make_camo():
    n = fbm(11, 3, 4)

    def f(x, y, w, h):
        v = n((x + .5) / w, (y + .5) / h)
        return (1.0 if v > 0.58 else (0.62 if v > 0.45 else 0.3)), 1.0
    return f


def make_leopard():
    vor = voronoi(13, 14)
    n = lattice(2, 6)

    def f(x, y, w, h):
        u, v = (x + .5) / w, (y + .5) / h
        f1, f2 = vor(u, v)
        r = f1 + 0.05 * (n(u, v) - 0.5)
        ring = smoothstep(0.045, 0.06, r) * (1 - smoothstep(0.085, 0.1, r))
        core = 1 - smoothstep(0.03, 0.045, r)
        return 1, clamp(ring + core * 0.35)
    return f


def make_cracks():
    vor = voronoi(17, 22)

    def f(x, y, w, h):
        f1, f2 = vor((x + .5) / w, (y + .5) / h)
        return 1, 1 - smoothstep(0.0, 0.035, f2 - f1)
    return f


def make_bubbles():
    rng = random.Random(23)
    pts = [(rng.random(), rng.random(), 0.05 + rng.random() * 0.07) for _ in range(16)]

    def f(x, y, w, h):
        u, v = (x + .5) / w, (y + .5) / h
        a = 0.0
        for px, py, r in pts:
            dx, dy = abs(u - px), abs(v - py)
            dx, dy = min(dx, 1 - dx), min(dy, 1 - dy)
            d = math.hypot(dx, dy)
            ring = smoothstep(r - 0.012, r - 0.004, d) * (1 - smoothstep(r - 0.004, r + 0.004, d))
            glint = (1 - smoothstep(0, r * 0.35, math.hypot(u - px + r * 0.35, v - py + r * 0.35))) * 0.8 if d < r else 0
            a = max(a, ring, glint * 0.8 + (0.15 if d < r else 0))
        return 1, clamp(a)
    return f


def make_veins():
    n = fbm(29, 4, 4)

    def f(x, y, w, h):
        v = n((x + .5) / w, (y + .5) / h)
        line = 1 - abs(2 * v - 1)
        return 0.15 + 0.85 * line ** 4, 0.25 + 0.75 * line ** 2
    return f


def make_sand():
    rng = random.Random(31)
    cache = {}

    def f(x, y, w, h):
        key = (x, y)
        if key not in cache:
            cache[key] = rng.random()
        return 0.6 + 0.4 * cache[key], 0.35 + 0.65 * ((cache[key] * 7.3) % 1)
    return f


def scales(x, y, w, h):          # fish scales: the lower arc of circles on a staggered lattice (period 16)
    best = 0.0
    for px, py in ((0, 0), (8, 8)):
        for ddx in (-16, 0, 16):
            for ddy in (-16, 0, 16):
                dx, dy = x + .5 - (px + ddx), y + .5 - (py + ddy)
                d = math.hypot(dx, dy)
                if dy > -1.5 and abs(d - 8) < 1.0:
                    best = max(best, 1 - abs(d - 8))
    return 0.5 + 0.5 * best, clamp(best * 1.2)


def ripples(x, y, w, h):
    t = 2 * math.pi
    v = math.sin(t * (x / w * 2 + 0.15 * math.sin(t * y / h * 2))) + math.sin(t * (y / h * 3 + 0.2 * math.sin(t * x / w * 2)))
    return 1, clamp(0.5 + 0.35 * v)


# ---------------------------------------------------------------- geometric
def hexagons(x, y, w, h):          # a hexagonal lattice: centres (0,0) and (8,16) on a 16x32 tile, y squeezed to true scale
    d = []
    for ddx in (-16, 0, 16):
        for ddy in (-32, 0, 32):
            for cx, cy in ((0, 0), (8, 16)):
                dx, dy = x + .5 - (cx + ddx), (y + .5 - (cy + ddy)) * 0.866
                d.append(math.hypot(dx, dy))
    d.sort()
    return 1, 1 - smoothstep(0.0, 2.4, d[1] - d[0])


def triangles(x, y, w, h):
    on = ((x - y) % 16) < 1 or ((x + y) % 16) < 1 or (x % 16) < 1
    return 1, 1.0 if on else 0.0


def argyle(x, y, w, h):
    d = abs(wrapd(x + .5, 16, 32)) + abs(wrapd(y + .5, 16, 32))
    inside = d < 10
    line = abs(d - 10) < 0.8
    return (0.45 if inside else 1.0), (1.0 if (inside or line) else 0.0) * (1.0 if not line else 1.0)


def plaid(x, y, w, h):
    bx = 1 if (x % 16) < 7 else 0
    by = 1 if (y % 16) < 7 else 0
    return 0.45 + 0.35 * bx + 0.2 * by, clamp(0.35 * bx + 0.35 * by + 0.1)


def basket(x, y, w, h):
    horizontal = ((x // 8) + (y // 8)) % 2 == 0
    strand = (y % 4) if horizontal else (x % 4)
    return 0.4 + 0.6 * (1 - abs(strand - 1.5) / 1.5), 1.0


def stars(x, y, w, h):             # four-point stars (an astroid) on an 8px lattice
    dx, dy = abs(wrapd(x + .5, 4, 8)), abs(wrapd(y + .5, 4, 8))
    d = math.sqrt(dx) + math.sqrt(dy)
    return 1, clamp((2.4 - d) * 1.6)


def pluses(x, y, w, h):
    dx, dy = abs(wrapd(x + .5, 4, 8)), abs(wrapd(y + .5, 4, 8))
    return 1, 1.0 if (dx < 0.9 and dy < 3) or (dy < 0.9 and dx < 3) else 0.0


def tiles(x, y, w, h):
    tx, ty = x % 16, y % 16
    if tx == 0 or ty == 0:
        return 0.15, 1.0
    shade = 1 - (tx + ty) / 30.0
    return 0.45 + 0.55 * shade, 1.0


def rivets(x, y, w, h):
    dx, dy = wrapd(x + .5, 8, 16), wrapd(y + .5, 8, 16)
    d = math.hypot(dx, dy)
    if d > 5.2:
        return 0.3, 0.15
    light = 1 - clamp(math.hypot(dx + 1.5, dy + 1.5) / 6.5)
    return 0.35 + 0.65 * light, 1.0


def louvers(x, y, w, h):
    t = y % 8
    return (1.0 - 0.7 * (t / 7.0)) if t < 6 else 0.15, 1.0 if t < 6 else 0.55


def rings(x, y, w, h):
    d = math.hypot(wrapd(x + .5, 8, 16), wrapd(y + .5, 8, 16))
    return 1, 1.0 if (d % 3.0) < 1.1 and d < 8 else 0.0


def bitmap(rows):
    height, width = len(rows), len(rows[0])

    def f(x, y, w, h):
        return 1, 1.0 if rows[y % height][x % width] == "#" else 0.0
    return f


houndstooth = bitmap([
    "##..#...", "###..#..", "####.#..", "#.######", "...#####", "..#.####", "..#..###", ".#...##.",
])
zebra = lambda x, y, w, h: (1, 1.0 if math.sin(2 * math.pi * (x / w * 4 + 0.35 * math.sin(2 * math.pi * y / h))) > 0.15 else 0.0)


# ---------------------------------------------------------------- material
def make_leather():
    vor = voronoi(41, 60)
    n = lattice(7, 8)

    def f(x, y, w, h):
        u, v = (x + .5) / w, (y + .5) / h
        f1, f2 = vor(u, v)
        crease = 1 - smoothstep(0.0, 0.02, f2 - f1)
        return 0.55 + 0.35 * n(u, v) - 0.3 * crease, 1.0
    return f


def make_cloth():
    def f(x, y, w, h):
        warp = 0.5 + 0.5 * math.sin(2 * math.pi * x / 4.0)
        weft = 0.5 + 0.5 * math.sin(2 * math.pi * y / 4.0)
        over = ((x // 4) + (y // 4)) % 2 == 0
        return 0.45 + 0.4 * (warp if over else weft) + 0.15 * (warp * weft), 1.0
    return f


def make_scratched():
    rng = random.Random(53)
    lines = [(rng.random(), rng.random(), 0.15 + rng.random() * 0.35, rng.random() * math.pi) for _ in range(26)]

    def f(x, y, w, h):
        u, v = (x + .5) / w, (y + .5) / h
        a = 0.0
        for px, py, length, ang in lines:
            for ox in (-1, 0, 1):
                for oy in (-1, 0, 1):
                    dx, dy = u - (px + ox), v - (py + oy)
                    along = dx * math.cos(ang) + dy * math.sin(ang)
                    across = -dx * math.sin(ang) + dy * math.cos(ang)
                    if abs(along) < length / 2 and abs(across) < 0.012:
                        a = max(a, 1 - abs(across) / 0.012)
        return 1, 0.12 + 0.88 * a
    return f


# ---------------------------------------------------------------- bar shaping (stretched over the bar)
def vert(fn):
    return lambda x, y, w, h: fn(y / float(h - 1))


def tube(v):
    return 0.35 + 0.65 * math.sin(math.pi * min(1, v * 1.15)) ** 0.7 * (1 if v < 0.9 else 0.7), 1.0


def chrome(v):
    bands = 0.5 + 0.5 * math.sin(2 * math.pi * (v * 1.5 + 0.1))
    return 0.25 + 0.75 * bands ** 2 * (1 - 0.35 * v), 1.0


def split(v):
    return (1.0 if v < 0.5 else 0.45), 1.0


def stairs(v):
    return 1.0 - 0.25 * int(v * 4), 1.0


def center_glow(v):
    return 1.0, 0.1 + 0.9 * math.sin(math.pi * v) ** 2


def dark_edges(v):
    return 1.0 - 0.7 * abs(2 * v - 1) ** 2, 1.0


def glass_strong(v):
    if v < 0.45:
        return 1.0, 0.95 - 0.35 * v / 0.45
    return 0.5 - 0.15 * (v - 0.45) / 0.55, 0.9


def capsule(x, y, w, h):          # rounded caps at both ends, tube shading across (stretched)
    u, v = x / float(w - 1), y / float(h - 1)
    cap = 0.12
    edge = min(u, 1 - u)
    if edge < cap:
        r = (cap - edge) / cap
        alpha = clamp(1 - r ** 2.2 + 0.0) if abs(2 * v - 1) < math.sqrt(max(0.0, 1 - r * r)) else 0.0
    else:
        alpha = 1.0
    shade = 0.4 + 0.6 * math.sin(math.pi * v)
    return shade, alpha


def segments(count):              # a thin gap at every 1/count of the bar (stretched, so the gaps scale with it)
    def f(x, y, w, h):
        step = w / float(count)
        into = (x + .5) % step
        gap = min(into, step - into) < 0.8 and 0.5 < (x + .5) < w - 0.5
        return 1.0, 0.0 if gap else 1.0
    return f


def sweep_left(x, y, w, h):       # a soft bright band at the right end, a "leading edge"
    u = x / float(w - 1)
    return 1.0, clamp(0.35 + 0.65 * smoothstep(0.7, 1.0, u)) * (0.85 if u > 0.97 else 1.0)


# ---------------------------------------------------------------- colour (use a white fill colour)
def hsv(h, s, v):
    i = int(h * 6) % 6
    f = h * 6 - int(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    return ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))[i]


def ramp(stops):
    def at(t):
        t = clamp(t)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t <= t1:
                k = (t - t0) / (t1 - t0) if t1 > t0 else 0
                return tuple(c0[j] + (c1[j] - c0[j]) * k for j in range(3))
        return stops[-1][1]
    return at


def horizontal(stops, alpha=1.0):
    r = ramp(stops)
    return lambda x, y, w, h: r(x / float(w - 1)) + (alpha,)


rainbow = lambda x, y, w, h: hsv(x / float(w) * 0.83, 0.85, 1.0) + (1.0,)
FIRE = horizontal([(0, (0.25, 0, 0)), (0.35, (0.9, 0.1, 0.05)), (0.7, (1, 0.6, 0.05)), (1, (1, 0.95, 0.5))])
ICE = horizontal([(0, (0.1, 0.2, 0.55)), (0.5, (0.3, 0.7, 1)), (1, (0.9, 1, 1))])
TOXIC = horizontal([(0, (0.05, 0.25, 0.05)), (0.5, (0.3, 0.9, 0.1)), (1, (0.85, 1, 0.3))])
PLASMA = horizontal([(0, (0.35, 0.05, 0.7)), (0.5, (1, 0.2, 0.8)), (1, (0.3, 0.9, 1))])
SUNSET = horizontal([(0, (0.3, 0.1, 0.5)), (0.4, (0.9, 0.25, 0.4)), (0.75, (1, 0.6, 0.2)), (1, (1, 0.9, 0.5))])
AURORA = horizontal([(0, (0.05, 0.6, 0.4)), (0.5, (0.2, 0.8, 0.9)), (1, (0.6, 0.35, 0.95))])
LAVA = horizontal([(0, (0.1, 0.0, 0.0)), (0.4, (0.7, 0.05, 0.0)), (0.75, (1, 0.45, 0.0)), (1, (1, 0.9, 0.3))])
BLOOD = horizontal([(0, (0.15, 0.0, 0.02)), (0.6, (0.65, 0.02, 0.06)), (1, (0.95, 0.15, 0.15))])
GOLDBAR = horizontal([(0, (0.5, 0.35, 0.05)), (0.5, (1, 0.85, 0.3)), (1, (0.6, 0.42, 0.08))])
STEELBLUE = horizontal([(0, (0.25, 0.3, 0.4)), (0.5, (0.7, 0.78, 0.9)), (1, (0.3, 0.35, 0.45))])


def vertical(stops):
    r = ramp(stops)
    return lambda x, y, w, h: r(y / float(h - 1)) + (1.0,)


FIRE_V = vertical([(0, (1, 0.95, 0.5)), (0.4, (1, 0.5, 0.05)), (0.8, (0.8, 0.1, 0.02)), (1, (0.3, 0.0, 0.0))])
OCEAN_V = vertical([(0, (0.5, 0.9, 1)), (0.5, (0.1, 0.5, 0.9)), (1, (0.02, 0.1, 0.4))])

# (name, width, height, fn)
TILED_EXTRA = [
    ("clouds", 64, 64, make_clouds()), ("marble", 64, 64, make_marble()), ("wood", 64, 64, make_wood()),
    ("camo", 64, 64, make_camo()), ("leopard", 64, 64, make_leopard()), ("cracks", 64, 64, make_cracks()),
    ("bubbles", 64, 64, make_bubbles()), ("veins", 64, 64, make_veins()), ("sand", 32, 32, make_sand()),
    ("scales", 16, 16, scales), ("ripples", 32, 32, ripples),
    ("hexagons", 16, 32, hexagons), ("triangles", 16, 16, triangles), ("argyle", 32, 32, argyle), ("plaid", 32, 32, plaid),
    ("basket", 16, 16, basket), ("stars", 8, 8, stars), ("pluses", 8, 8, pluses), ("tiles", 16, 16, tiles),
    ("rivets", 16, 16, rivets), ("louvers", 8, 8, louvers), ("rings", 16, 16, rings), ("houndstooth", 8, 8, houndstooth),
    ("zebra", 32, 32, zebra), ("leather", 64, 64, make_leather()), ("cloth", 16, 16, make_cloth()),
    ("scratched", 64, 64, make_scratched()),
]
SOFT_EXTRA = [
    ("tube", 4, 64, vert(tube)), ("chrome", 4, 64, vert(chrome)), ("split", 4, 64, vert(split)),
    ("stairs", 4, 64, vert(stairs)), ("center_glow", 4, 64, vert(center_glow)), ("dark_edges", 4, 64, vert(dark_edges)),
    ("glass_strong", 4, 64, vert(glass_strong)), ("capsule", 128, 16, capsule),
    ("segments10", 128, 4, segments(10)), ("segments5", 128, 4, segments(5)), ("segments20", 128, 4, segments(20)),
    ("sweep", 64, 4, sweep_left),
]
COLOR_EXTRA = [
    ("rainbow", 64, 4, rainbow), ("fire", 64, 4, FIRE), ("ice", 64, 4, ICE), ("toxic", 64, 4, TOXIC),
    ("plasma", 64, 4, PLASMA), ("sunset", 64, 4, SUNSET), ("aurora", 64, 4, AURORA), ("lava", 64, 4, LAVA),
    ("bloodred", 64, 4, BLOOD), ("goldbar", 64, 4, GOLDBAR), ("steelblue", 64, 4, STEELBLUE),
    ("fire_v", 4, 64, FIRE_V), ("ocean_v", 4, 64, OCEAN_V),
]
