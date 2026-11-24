"""Generates handcrafted crisp 16-bit Pixel Art sprites for UsefulPlatesAndTooltips.

Every sprite is drawn on an exact 16x16 (or 16x8 / 32x32) pixel grid with hue-shifted shading,
1px dark outlines for contrast on any terrain, and nearest-neighbor 4x upscaling to 64x64
(64x32 / 128x128) uncompressed 32-bit RGBA TGA (descriptor 0x28).

    python tools/make_pixel_art.py
"""
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def write_pixel_tga(path, grid, palette, scale=4):
    """Render an ASCII pixel art `grid` using `palette` (char -> (r,g,b,a) 0..255) upscaled `scale`x nearest."""
    path.parent.mkdir(parents=True, exist_ok=True)
    gh = len(grid)
    gw = len(grid[0])
    assert all(len(row) == gw for row in grid), f"{path.name}: ragged grid rows"
    w, h = gw * scale, gh * scale
    rows = []
    for gy in range(gh):
        scanline = bytearray()
        for gx in range(gw):
            ch = grid[gy][gx]
            r, g, b, a = palette[ch]
            px = bytes((b, g, r, a))
            scanline += px * scale
        for _ in range(scale):
            rows.append(scanline)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
    path.write_bytes(header + b"".join(rows))
    print(f"{path.relative_to(ROOT)}: {w}x{h} ({gw}x{gh}@{scale}x), {path.stat().st_size} bytes")


# Common transparency + dark outline
T = (0, 0, 0, 0)
K = (14, 10, 18, 255)      # deep obsidian outline
K2 = (14, 10, 18, 185)     # softer corner outline

# ---------------------------------------------------------------------------
# 1. Warlock Soul Shard (Pixel Art) — ShardGem_px, ShardBezel_px, ShardGlow_px
# ---------------------------------------------------------------------------

SHARD_GEM_GRID = [
    "................",
    "................",
    ".......Ww.......",
    "......WLmM......",
    ".....WLLmMd.....",
    "....WLWLLmMd....",
    "....WLLmMMmd....",
    "....LLmmMMdd....",
    "....LLmmMMdd....",
    "....LmmMMddd....",
    ".....mMMddd.....",
    ".....mMdddD.....",
    "......mdDD......",
    ".......DD.......",
    "................",
    "................",
]
SHARD_GEM_PAL = {
    ".": T,
    "W": (255, 240, 255, 255),  # crisp specular sparkle
    "w": (236, 184, 255, 255),  # upper-right crown glint
    "L": (222, 128, 255, 255),  # bright lit orchid facet
    "m": (184,  68, 248, 255),  # luminous amethyst core
    "M": (146,  38, 224, 255),  # rich royal purple
    "d": ( 98,  18, 168, 255),  # shaded lower facet
    "D": ( 56,   8, 108, 255),  # deep shadow tip
}

SHARD_BEZEL_GRID = [
    ".......KK.......",
    "......KSSK......",
    ".....KS..sK.....",
    "....KS....sK....",
    "...KS......pK...",
    "...KS......pK...",
    "...KS......pK...",
    "...Ks......pK...",
    "...Ks......dK...",
    "...Kp......dK...",
    "....Kp....dK....",
    "....Kp....dK....",
    ".....Kp..dK.....",
    "......KddK......",
    ".......KK.......",
    "................",
]
SHARD_BEZEL_PAL = {
    ".": T,
    "K": K,
    "S": (232, 238, 252, 255),  # bright top-left silver bevel
    "s": (176, 184, 206, 255),  # mid steel
    "p": (122, 128, 150, 255),  # shaded pewter
    "d": ( 76,  80, 100, 255),  # dark bottom-right bevel
}

# 32x32 stepped pixel arcane halo + 4 pixel sparkles
def build_shard_glow_px():
    grid = []
    for y in range(32):
        row = []
        for x in range(32):
            dx = (x - 15.5) / 8.0
            dy = (y - 15.5) / 10.5
            r = (dx * dx + dy * dy) ** 0.5
            if r < 1.15:
                row.append("A")
            elif r < 1.45:
                row.append("B")
            elif r < 1.75:
                row.append("C")
            else:
                row.append(".")
        grid.append(row)
    # 4 crisp pixel sparkles around crystal
    for sx, sy in ((5, 6), (26, 8), (6, 24), (25, 25)):
        grid[sy][sx] = "S"
        for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            grid[sy + oy][sx + ox] = "s"
    return ["".join(r) for r in grid]

SHARD_GLOW_PAL = {
    ".": T,
    "A": (196,  92, 255, 195),
    "B": (164,  58, 240, 120),
    "C": (132,  36, 210,  55),
    "S": (250, 224, 255, 245),
    "s": (212, 130, 255, 145),
}

# ---------------------------------------------------------------------------
# 2. Combo Orbs (Pixel Art, grayscale tintable) — ComboOrb_px / Ring / Dark / Glow
# ---------------------------------------------------------------------------

COMBO_ORB_GRID = [
    "................",
    "................",
    ".....llllmm.....",
    "....lWWllmmm....",
    "...lWWWllmmmm...",
    "...lWWlllmmmm...",
    "..llllmmmmmmdd..",
    "..lllmmmmmmmdd..",
    "..lllmmmmmmddd..",
    "..llmmmmmmdddd..",
    "...mmmmmmdddd...",
    "...mmmmmddDDD...",
    "....mmmddDDD....",
    ".....ddDDDD.....",
    "................",
    "................",
]
GRAY_ORB_PAL = {
    ".": T,
    "W": (255, 255, 255, 255),
    "l": (244, 244, 244, 255),
    "m": (196, 196, 196, 255),
    "d": (140, 140, 140, 255),
    "D": ( 98,  98,  98, 255),
}

COMBO_DARK_GRID = [
    "................",
    "................",
    ".....dddddd.....",
    "....dddddddd....",
    "...ddddmmmmdd...",
    "...dddmmmmmmm...",
    "..dddmmmmmmmmm..",
    "..ddmmmmmmmmll..",
    "..ddmmmmmmmmll..",
    "..ddmmmmmmmlll..",
    "...mmmmmmmlll...",
    "...mmmmmmllll...",
    "....mmmmllll....",
    ".....llllll.....",
    "................",
    "................",
]
GRAY_DARK_PAL = {
    ".": T,
    "d": (26, 26, 30, 235),
    "m": (44, 44, 50, 235),
    "l": (64, 64, 72, 235),
}

COMBO_RING_GRID = [
    ".....KKKKKK.....",
    "...KKSSSSssKK...",
    "..KSS......ssK..",
    ".KS..........sK.",
    ".KS..........pK.",
    "KS............pK",
    "KS............pK",
    "KS............pK",
    "Ks............dK",
    "Ks............dK",
    "Kp............dK",
    ".Kp..........dK.",
    ".Kp..........dK.",
    "..Kpp......ddK..",
    "...KKppddddKK...",
    ".....KKKKKK.....",
]
METAL_PAL = {
    ".": T,
    "K": K,
    "S": (238, 242, 252, 255),
    "s": (182, 188, 204, 255),
    "p": (122, 128, 144, 255),
    "d": ( 72,  76,  90, 255),
}

def build_combo_glow_px():
    grid = []
    for y in range(32):
        row = []
        for x in range(32):
            r = ((x - 15.5) ** 2 + (y - 15.5) ** 2) ** 0.5
            if r < 10.5:
                row.append("A")
            elif r < 12.5:
                row.append("B")
            elif r < 14.5:
                row.append("C")
            else:
                row.append(".")
        grid.append(row)
    return ["".join(r) for r in grid]

COMBO_GLOW_PAL = {
    ".": T,
    "A": (255, 255, 255, 195),
    "B": (255, 255, 255, 115),
    "C": (255, 255, 255,  50),
}

# ---------------------------------------------------------------------------
# 3 & 4. RangeIn_px & RangeOut_px (16x16 steel medallions)
# ---------------------------------------------------------------------------

RANGE_IN_GRID = [
    ".....KKKKKK.....",
    "...KKSSSSssKK...",
    "..KSSbbbbbbssK..",
    ".KSbbbbbbbbbbSK.",
    ".KSbbbbbbbbGWpK.",
    "KSbbbbbbbbGWGppK",
    "KSbGWbbbbGWGgppK",
    "KSbGWGbbGWGggppK",
    "KsbGGWGGWGggbbdK",
    "KsbbGGWWGggbbbdK",
    "KpbbbGGGggbbbbdK",
    ".KpbbbGGgbbbbdK.",
    ".KpbbbbbbbbbbdK.",
    "..KppbbbbbbddK..",
    "...KKppddddKK...",
    ".....KKKKKK.....",
]
RANGE_IN_PAL = {
    **METAL_PAL,
    "b": ( 14,  48,  26, 255),  # deep recessed emerald basin
    "W": (222, 255, 228, 255),  # specular mint-white highlight
    "G": ( 54, 232, 102, 255),  # bright emerald
    "g": ( 22, 152,  60, 255),  # shaded jade bevel
}

RANGE_OUT_GRID = [
    ".....KKKKKK.....",
    "...KKSSSSssKK...",
    "..KSSbbbbbbssK..",
    ".KSbbbbbbbbbbSK.",
    ".KSbWRbbbbWRbpK.",
    "KSbbWRRbbWRRbbpK",
    "KSbbbWRRWRrbbbpK",
    "KSbbbbWRRrbbbbpK",
    "KsbbbbWRRrbbbbdK",
    "KsbbbWRRWRrbbbdK",
    "KpbbWRrbbRRrbbdK",
    ".KpbRrbbbbRrbdK.",
    ".KpbbbbbbbbbbdK.",
    "..KppbbbbbbddK..",
    "...KKppddddKK...",
    ".....KKKKKK.....",
]
RANGE_OUT_PAL = {
    **METAL_PAL,
    "b": ( 56,  14,  18, 255),  # deep recessed crimson basin
    "W": (255, 212, 206, 255),  # bright coral-white highlight
    "R": (244,  48,  52, 255),  # vibrant crimson
    "r": (162,  20,  26, 255),  # shaded blood-red bevel
}

# ---------------------------------------------------------------------------
# 5, 6, 7. Pixel Art Kill Icons (Skull, Crosshair, Blades)
# ---------------------------------------------------------------------------

KILL_SKULL_PX_GRID = [
    "....KKKKKKKK....",
    "...KWWllllmmK...",
    "..KWlllmmmmmmK..",
    ".KWllmmmmmmmmdK.",
    ".KllmmmmmmmmmddK",
    ".KlmmmmmmmmmdddK",
    ".KlKFKmmmKFKdddK",
    ".KmKOKmmmKOKmddK",
    ".KmKKKmmmKKKmddK",
    "..KmmmKKKmmmddK.",
    "..KmmmdKdmmmddK.",
    "...KKmmmmmmdKK..",
    "....KmKmKmKmK...",
    "....KmKmKmKmK...",
    ".....KKKKKKK....",
    "................",
]
SKULL_PX_PAL = {
    ".": T,
    "K": K,
    "W": (255, 250, 236, 255),  # bone specular
    "l": (236, 224, 198, 255),  # lit ivory
    "m": (196, 180, 152, 255),  # mid bone
    "d": (132, 118,  98, 255),  # shadowed bone
    "F": (255, 192,  48, 255),  # fiery gold pupil spark
    "O": (236,  52,  26, 255),  # glowing crimson eye socket
}

KILL_CROSSHAIR_PX_GRID = [
    ".......KK.......",
    "......KGGK......",
    "....KKGggGKK....",
    "...KGGKGGKggK...",
    "..KGK..KK..KgK..",
    "..KG.K.rr.K.gdK.",
    ".KKG..KWWK..gdKK",
    "KGGgKrrWRrrKgdDK",
    "KggdKrrRRrrKgdDK",
    ".KKg..KrrK..ddKK",
    "..Kg.K.rr.K.ddK.",
    "..KdK..KK..KdK..",
    "...KddKddKddK...",
    "....KKdDDdKK....",
    "......KDDK......",
    ".......KK.......",
]
CROSSHAIR_PX_PAL = {
    ".": T,
    "K": K,
    "G": (255, 226, 108, 255),  # bright gold highlight
    "g": (224, 166,  38, 255),  # rich gold
    "d": (162, 104,  18, 255),  # dark antique gold
    "D": (108,  66,  12, 255),  # shadow gold
    "W": (255, 220, 224, 255),  # ruby core glint
    "R": (238,  38,  46, 255),  # bright ruby
    "r": (166,  18,  26, 255),  # crimson hairline/ruby shade
}

KILL_BLADES_PX_GRID = [
    ".KK..........KK.",
    "KWWK........KWWK",
    "KWSSK......KSSsK",
    ".KSSsK....KSSsK.",
    "..KSSsK..KSSsK..",
    "...KSSsKKSSsK...",
    "....KSSssSsK....",
    ".....KSSSSK.....",
    "....KSSsSSsK....",
    "...KSSsKKSSsK...",
    "..KGGKK..KKGGK..",
    ".KGgK.K..K.KgGK.",
    ".KDKhK....KhKDK.",
    "..KhhK....KhhK..",
    ".KRGKK....KKGRK.",
    "..KK........KK..",
]
BLADES_PX_PAL = {
    ".": T,
    "K": K,
    "W": (250, 254, 255, 255),  # blade edge highlight
    "S": (204, 218, 236, 255),  # forged steel
    "s": (132, 148, 170, 255),  # shaded steel facet
    "G": (255, 222,  96, 255),  # lit gold crossguard
    "g": (212, 152,  32, 255),  # mid gold
    "D": (146,  92,  16, 255),  # dark gold
    "h": (118,  48,  34, 255),  # wrapped leather hilt
    "R": (234,  44,  52, 255),  # ruby pommel
}

# ---------------------------------------------------------------------------
# 8 & 9. MarkerDiamond_px + MarkerDiamondBezel_px (grayscale tintable)
# ---------------------------------------------------------------------------

DIAMOND_PX_GRID = [
    "................",
    "................",
    ".......WW.......",
    "......Wllm......",
    ".....WWllmm.....",
    "....Wllllmmm....",
    "...Wlllmmmmmm...",
    "..Wlllmmmmmmdd..",
    "..lllmmmmmmddd..",
    "...llmmmmmddd...",
    "....lmmmmddd....",
    ".....mmmddd.....",
    "......mddd......",
    ".......dd.......",
    "................",
    "................",
]

DIAMOND_BEZEL_PX_GRID = [
    ".......KK.......",
    "......KSSK......",
    ".....KS..sK.....",
    "....KS....sK....",
    "...KS......sK...",
    "..KS........pK..",
    ".KS..........pK.",
    "KS............pK",
    "Ks............dK",
    ".Ks..........dK.",
    "..Kp........dK..",
    "...Kp......dK...",
    "....Kp....dK....",
    ".....Kp..dK.....",
    "......KddK......",
    ".......KK.......",
]

# ---------------------------------------------------------------------------
# 10. MarkerSegment_px (16x8 grayscale tintable pixel RPG pip/segment)
# ---------------------------------------------------------------------------

SEGMENT_PX_GRID = [
    ".KKKKKKKKKKKKKK.",
    "KWWWWWWWWWWWWWlK",
    "KWllllllllllllmK",
    "KmmmmmmmmmmmmmmK",
    "KmmmmmmmmmmmmmdK",
    "KddddddddddddddK",
    "KDDDDDDDDDDDDDDK",
    ".KKKKKKKKKKKKKK.",
]
SEGMENT_PX_PAL = {
    ".": T,
    "K": ( 36,  36,  42, 255),
    "W": (255, 255, 255, 255),
    "l": (236, 236, 236, 255),
    "m": (200, 200, 200, 255),
    "d": (156, 156, 156, 255),
    "D": (118, 118, 118, 255),
}

# ---------------------------------------------------------------------------
# 11 & 12. StatsInfo Pixel Art Upgrade / Downgrade Arrows
# ---------------------------------------------------------------------------

ARROW_UP_PX_GRID = [
    ".......KK.......",
    "......KWWK......",
    ".....KWWGGK.....",
    "....KWWGGGGK....",
    "...KWWGGGGGgK...",
    "..KWWGGGGGGggK..",
    ".KWWGGGGGGGGggK.",
    "KWWGGGGGGGGGGggK",
    "KKKKKWGgggKKKKKK",
    "....KWGgggK.....",
    "....KWGgggK.....",
    "....KWGgggK.....",
    "....KWGgggK.....",
    "....KGGgggK.....",
    "....KgggggK.....",
    ".....KKKKK......",
]
ARROW_UP_PX_PAL = {
    ".": T,
    "K": K,
    "W": (214, 255, 222, 255),
    "G": ( 50, 232,  96, 255),
    "g": ( 18, 150,  54, 255),
}

ARROW_DOWN_PX_GRID = list(reversed(ARROW_UP_PX_GRID))
ARROW_DOWN_PX_PAL = {
    ".": T,
    "K": K,
    "W": (255, 204, 198, 255),
    "G": (244,  48,  52, 255),
    "g": (158,  18,  24, 255),
}


def main():
    rd = ROOT / "Modules" / "ResourceDing" / "Textures"
    write_pixel_tga(rd / "ShardGem_px.tga", SHARD_GEM_GRID, SHARD_GEM_PAL, scale=4)
    write_pixel_tga(rd / "ShardBezel_px.tga", SHARD_BEZEL_GRID, SHARD_BEZEL_PAL, scale=4)
    write_pixel_tga(rd / "ShardGlow_px.tga", build_shard_glow_px(), SHARD_GLOW_PAL, scale=4)
    write_pixel_tga(rd / "ComboOrb_px.tga", COMBO_ORB_GRID, GRAY_ORB_PAL, scale=4)
    write_pixel_tga(rd / "ComboRing_px.tga", COMBO_RING_GRID, METAL_PAL, scale=4)
    write_pixel_tga(rd / "ComboOrbDark_px.tga", COMBO_DARK_GRID, GRAY_DARK_PAL, scale=4)
    write_pixel_tga(rd / "ComboGlow_px.tga", build_combo_glow_px(), COMBO_GLOW_PAL, scale=4)

    rg = ROOT / "Modules" / "Range" / "Textures"
    write_pixel_tga(rg / "RangeIn_px.tga", RANGE_IN_GRID, RANGE_IN_PAL, scale=4)
    write_pixel_tga(rg / "RangeOut_px.tga", RANGE_OUT_GRID, RANGE_OUT_PAL, scale=4)

    dt = ROOT / "Modules" / "DoTInfo" / "Textures"
    write_pixel_tga(dt / "KillSkull_px.tga", KILL_SKULL_PX_GRID, SKULL_PX_PAL, scale=4)
    write_pixel_tga(dt / "KillCrosshair_px.tga", KILL_CROSSHAIR_PX_GRID, CROSSHAIR_PX_PAL, scale=4)
    write_pixel_tga(dt / "KillBlades_px.tga", KILL_BLADES_PX_GRID, BLADES_PX_PAL, scale=4)

    ct = ROOT / "Core" / "Textures"
    write_pixel_tga(ct / "MarkerDiamond_px.tga", DIAMOND_PX_GRID, GRAY_ORB_PAL, scale=4)
    write_pixel_tga(ct / "MarkerDiamondBezel_px.tga", DIAMOND_BEZEL_PX_GRID, METAL_PAL, scale=4)
    write_pixel_tga(ct / "MarkerSegment_px.tga", SEGMENT_PX_GRID, SEGMENT_PX_PAL, scale=4)

    st = ROOT / "Modules" / "StatsInfo" / "Textures"
    write_pixel_tga(st / "ArrowUp_px.tga", ARROW_UP_PX_GRID, ARROW_UP_PX_PAL, scale=4)
    write_pixel_tga(st / "ArrowDown_px.tga", ARROW_DOWN_PX_GRID, ARROW_DOWN_PX_PAL, scale=4)


if __name__ == "__main__":
    main()
