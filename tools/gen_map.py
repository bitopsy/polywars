#!/usr/bin/env python3
"""Generates the source images for the 'Pylon City' map (pure stdlib).

Output (in the directory given to generate()):
    texture.png   4096x4096  RGB     diffuse texture (2 px per elmo)
    height.png     257x257   16-bit  heightmap, 0..65535 == MIN_H..MAX_H
    metal.png      128x128   8-bit    metal map (255 == full metal, 16 elmos per px)
which tools like SpringMapConvNG / pymapconv compile into .smf + .smt.

Layout: a 8x8 grid of city blocks (256 elmos period) separated by 80-elmo streets.
Most blocks are tall 'buildings' (walls for pathing); 12 are open plazas with a
metal spot in the middle: 2 home plazas per side, 4 flank plazas, a 2x2 central square.
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngutil import write_png  # noqa: E402

SIZE = 4                      # map units of 512 elmos  -> 2048 x 2048 elmos
ELMOS = SIZE * 512
H_SAMPLES = SIZE * 64 + 1     # 257 height samples (8 elmos apart)
TEX = SIZE * 1024             # 4096 px (16 px per height sample)
METAL_RES = SIZE * 32         # 128 px (16 elmos per px)
MIN_H, MAX_H = 0, 130
STREET_H, PLAZA_H, BUILDING_H = 20, 20, 80

PERIOD, STREET_HALF = 32, 5   # in height samples
PLAZAS = {(1, 3), (1, 4), (6, 3), (6, 4),          # home plazas
          (3, 1), (4, 1), (3, 6), (4, 6),          # flanks
          (3, 3), (4, 3), (3, 4), (4, 4)}          # central square
START_POSITIONS = [(256, 1024), (1792, 1024)]      # street intersections (Aegis west, Vanta east)

ASPHALT, SIDEWALK, CENTER = (52, 54, 58), (150, 150, 146), (222, 190, 60)
ROOF_A, ROOF_B, ROOF_LINE = (98, 102, 110), (88, 92, 100), (66, 68, 76)
PLAZA, PLAZA_LINE = (168, 170, 160), (146, 148, 140)
SPOT_FILL, SPOT_RING = (38, 62, 72), (70, 210, 230)


def cell(s):
    """-1 for a street sample, otherwise the block index along this axis."""
    k, r = divmod(s + STREET_HALF, PERIOD)
    return -1 if r < 2 * STREET_HALF else k


def height(sx, sz):
    bx, bz = cell(sx), cell(sz)
    if bx < 0 or bz < 0:
        return STREET_H
    if (bx, bz) in PLAZAS:
        return PLAZA_H
    return BUILDING_H + ((bx * 7 + bz * 13) % 5) * 8     # 80..112 for variety


def metal_spots():
    """Plaza centres in elmos."""
    return [(256 * bx + 128, 256 * bz + 128) for bx, bz in sorted(PLAZAS)]


# ---------------------------------------------------------------- texture
BLOCK_PX = (PERIOD - 2 * STREET_HALF) * 16          # 352


def _col_info():
    info = []
    for px in range(TEX):
        sx = px // 16
        bx = cell(sx)
        if bx < 0:
            k = (sx + STREET_HALF) // PERIOD
            info.append((-1, 0, abs(px - 512 * k)))                         # street: dist to centre
        else:
            info.append((bx, px - (PERIOD * bx + STREET_HALF) * 16, 0))    # block: local x
    return info


COLS = None


def _row_key(py):
    global COLS
    sz = py // 16
    bz = cell(sz)
    dash = (py // 48) % 2
    if bz < 0:
        k = (sz + STREET_HALF) // PERIOD
        d = abs(py - 512 * k)
        return ("H", d < 3, d > 66)
    ly = py - (PERIOD * bz + STREET_HALF) * 16
    if abs(ly - 176) <= 82:
        return ("B", bz, dash, ly)                                          # spot band: exact row
    return ("B", bz, dash, ly < 8 or ly >= BLOCK_PX - 8, ly % 64 < 2, ly % 44 < 2, (ly // 64) % 2)


def _make_row(py):
    sz = py // 16
    bz = cell(sz)
    out = bytearray()
    if bz < 0:
        k = (sz + STREET_HALF) // PERIOD
        d = abs(py - 512 * k)
        for px in range(TEX):
            bx, lx, vd = COLS[px]
            if bx < 0:
                c = ASPHALT                                                  # intersection
            elif d < 3 and (px // 48) % 2 == 0:
                c = CENTER
            elif d > 66:
                c = SIDEWALK
            else:
                c = ASPHALT
            out += bytes(c)
        return bytes(out)
    ly = py - (PERIOD * bz + STREET_HALF) * 16
    dash = (py // 48) % 2
    for px in range(TEX):
        bx, lx, vd = COLS[px]
        if bx < 0:                                                           # vertical street piece
            if vd < 3 and dash == 0:
                c = CENTER
            elif vd > 66:
                c = SIDEWALK
            else:
                c = ASPHALT
        elif (bx, bz) in PLAZAS:
            edge = lx < 8 or ly < 8 or lx >= BLOCK_PX - 8 or ly >= BLOCK_PX - 8
            dx, dy = lx - 176, ly - 176
            d2 = dx * dx + dy * dy
            if edge:
                c = SIDEWALK
            elif 70 * 70 <= d2 <= 82 * 82:
                c = SPOT_RING
            elif d2 < 70 * 70:
                c = SPOT_FILL
            elif lx % 44 < 2 or ly % 44 < 2:
                c = PLAZA_LINE
            else:
                c = PLAZA
        else:                                                                # building roof
            edge = lx < 8 or ly < 8 or lx >= BLOCK_PX - 8 or ly >= BLOCK_PX - 8
            if edge or lx % 64 < 2 or ly % 64 < 2:
                c = ROOF_LINE
            else:
                c = ROOF_A if ((lx // 64) + (ly // 64)) % 2 == 0 else ROOF_B
        out += bytes(c)
    return bytes(out)


def write_texture(path):
    global COLS
    COLS = _col_info()
    cache = {}

    def rows():
        for py in range(TEX):
            key = _row_key(py)
            r = cache.get(key)
            if r is None:
                r = cache[key] = _make_row(py)
            yield r

    write_png(path, TEX, TEX, 2, 8, rows(), level=3)


def write_height(path):
    def rows():
        for sz in range(H_SAMPLES):
            vals = [round(height(sx, sz) / MAX_H * 65535) for sx in range(H_SAMPLES)]
            yield struct.pack(">%dH" % H_SAMPLES, *vals)
    write_png(path, H_SAMPLES, H_SAMPLES, 0, 16, rows())


def write_metal(path):
    px_spots = [(x // 16, z // 16) for x, z in metal_spots()]

    def rows():
        for pz in range(METAL_RES):
            row = bytearray(METAL_RES)
            for cx, cz in px_spots:
                if abs(pz - cz) <= 2:
                    for px in range(cx - 2, cx + 3):
                        row[px] = 255
            yield bytes(row)
    write_png(path, METAL_RES, METAL_RES, 0, 8, rows())


def generate(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    write_height(os.path.join(out_dir, "height.png"))
    write_metal(os.path.join(out_dir, "metal.png"))
    write_texture(os.path.join(out_dir, "texture.png"))
    return {k: os.path.join(out_dir, k + ".png") for k in ("texture", "height", "metal")}


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "map/build"
    print(generate(out))
