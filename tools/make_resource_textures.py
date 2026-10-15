"""Generates ResourceDing's combo point textures into Modules/ResourceDing/Textures.

The look: a dark matte centre, a glossy fill orb the palette tints, a lit metal bezel and a
soft halo for the newest point. All four are plain 32-bit uncompressed TGA with a top-left
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


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    write_tga(OUT / "ComboOrb.tga", 64, orb)
    write_tga(OUT / "ComboRing.tga", 64, ring)
    write_tga(OUT / "ComboOrbDark.tga", 64, orb_dark)
    write_tga(OUT / "ComboGlow.tga", 128, glow)


if __name__ == "__main__":
    main()
