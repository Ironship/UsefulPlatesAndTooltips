"""Generates the settings UI's nine-slice textures into Core/Textures.

Rounded.tga is a white rounded-corner fill, RoundedBorder1/2.tga the 1px and 2px rounded
outlines; all 16x16 with a 5px corner, drawn as nine-slices (SetTextureSliceMargins 5,5,5,5)
so the corners keep their shape at any button or panel size. 32-bit TGA, top-left origin,
the same format as the other generated art.

    python tools/make_ui_textures.py
"""
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Core" / "Textures"
SIZE = 16
RADIUS = 5.0
SS = 8  # supersampling per axis


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def rounded_coverage_rect(x, y, inset, radius):
    """Coverage of a rounded rect [inset, SIZE-inset] with corner radius `radius` at (x, y)."""
    lo, hi = inset, SIZE - inset
    cx = min(max(x, lo + radius), hi - radius)
    cy = min(max(y, lo + radius), hi - radius)
    d = math.hypot(x - cx, y - cy)
    return clamp(radius - d + 0.5)


def rounded_coverage(x, y):
    """Coverage of the outer rounded rect [1, SIZE-1] with corner radius RADIUS at (x, y)."""
    return rounded_coverage_rect(x, y, 1.0, RADIUS)


def shade_fill(px, py):
    a = rounded_coverage(px, py)
    return (1.0, a) if a > 0 else (1.0, 0.0)


def make_border(width):
    def shade(px, py):
        outer = rounded_coverage(px, py)
        inner = rounded_coverage_rect(px, py, 1.0 + width, max(RADIUS - width, 0.0))
        a = clamp(outer - inner)
        return (1.0, a) if a > 0 else (1.0, 0.0)
    return shade


def write_tga(path, shade):
    rows = []
    for py in range(SIZE):
        row = bytearray()
        for px in range(SIZE):
            a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    _, alpha = shade(px + (sx + 0.5) / SS, py + (sy + 0.5) / SS)
                    a += alpha
            a /= SS * SS
            v = int(clamp(a) * 255 + 0.5)
            row += bytes((v, v, v, v))
        rows.append(row)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    path.write_bytes(header + b"".join(rows))
    print(f"{path.name}: {SIZE}x{SIZE}, {path.stat().st_size} bytes")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    write_tga(OUT / "Rounded.tga", shade_fill)
    write_tga(OUT / "RoundedBorder1.tga", make_border(1.0))
    write_tga(OUT / "RoundedBorder2.tga", make_border(2.0))


if __name__ == "__main__":
    main()
