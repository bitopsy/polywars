#!/usr/bin/env python3
"""Generates placeholder art (pure stdlib): S3O models, unit textures, build pics,
side pics and a loading picture. Replace with real art whenever you like; the unit
defs only reference file names.

    python3 tools/gen_assets.py        # writes into game/
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from pngutil import write_png  # noqa: E402

GAME = os.path.join(os.path.dirname(HERE), "game")

# ------------------------------------------------------------------ S3O writer
FACES = [  # outward normal, 4 corners as multipliers of half-size (CCW seen from outside)
    ((0, 1, 0),  [(-1, 1, 1), (1, 1, 1), (1, 1, -1), (-1, 1, -1)]),
    ((0, -1, 0), [(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)]),
    ((0, 0, 1),  [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
    ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)]),
    ((1, 0, 0),  [(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)]),
    ((-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
]


def build_s3o(boxes, tex1, tex2):
    """boxes: (cx, cy, cz, sx, sy, sz, accent). Accent parts sample the left half of the
    texture (team-colour mask), body parts the right half."""
    verts = []
    for cx, cy, cz, sx, sy, sz, accent in boxes:
        u = 0.25 if accent else 0.75
        for normal, corners in FACES:
            for mx, my, mz in corners:
                verts.append((cx + mx * sx / 2, cy + my * sy / 2, cz + mz * sz / 2) + normal + (u, 0.5))
    height = max(v[1] for v in verts)
    radius = max((v[0] ** 2 + (v[1] - height / 2) ** 2 + v[2] ** 2) ** 0.5 for v in verts)

    header_size, piece_size = 52, 52
    name = b"base\0"
    t1, t2 = tex1.encode() + b"\0", tex2.encode() + b"\0"
    off_piece = header_size
    off_name = off_piece + piece_size
    off_t1 = off_name + len(name)
    off_t2 = off_t1 + len(t1)
    off_verts = (off_t2 + len(t2) + 3) & ~3
    off_table = off_verts + 32 * len(verts)

    out = bytearray()
    out += b"Spring unit\0"
    out += struct.pack("<I", 0)
    out += struct.pack("<fffff", radius, height, 0.0, height / 2, 0.0)   # radius, height, mid xyz
    out += struct.pack("<IIII", off_piece, 0, off_t1, off_t2)
    assert len(out) == header_size, len(out)
    out += struct.pack("<10I", off_name, 0, 0, len(verts), off_verts, 0, 2, len(verts), off_table, 0)
    out += struct.pack("<fff", 0.0, 0.0, 0.0)
    out += name + t1 + t2
    out += b"\0" * (off_verts - len(out))
    for v in verts:
        out += struct.pack("<8f", *v)
    out += struct.pack("<%dI" % len(verts), *range(len(verts)))
    return bytes(out)


# ------------------------------------------------------------------ unit shapes
# (cx, cy, cz, sx, sy, sz, accent)   y is up, +z is the unit's front
SHAPES = {
    "aegis_commander": [(-5, 8, 0, 5, 16, 6, 0), (5, 8, 0, 5, 16, 6, 0), (0, 22, 0, 16, 12, 10, 0),
                        (0, 31, 1, 8, 6, 8, 1), (11, 26, 3, 4, 4, 16, 1), (0, 23, -7, 12, 10, 4, 0)],
    "vanta_commander": [(-7, 8, 0, 8, 16, 9, 0), (7, 8, 0, 8, 16, 9, 0), (0, 24, 0, 22, 14, 14, 0),
                        (0, 34, 1, 8, 6, 8, 1), (-14, 26, 4, 6, 6, 18, 1), (14, 26, 4, 6, 6, 18, 1),
                        (0, 26, -9, 16, 12, 5, 0)],
    "aegis_pylon": [(0, 4, 0, 14, 8, 14, 0), (0, 30, 0, 5, 52, 5, 0), (0, 58, 0, 10, 6, 10, 1)],
    "vanta_pylon": [(0, 4, 0, 16, 8, 16, 0), (0, 30, 0, 8, 52, 8, 0), (0, 50, 0, 22, 4, 4, 1), (0, 58, 0, 6, 8, 6, 1)],
    "aegis_generator": [(0, 8, 0, 34, 16, 34, 0), (-8, 22, -8, 10, 16, 10, 1), (8, 22, 8, 10, 16, 10, 1),
                        (0, 24, 0, 8, 12, 8, 1)],
    "vanta_generator": [(0, 9, 0, 36, 18, 36, 0), (0, 26, 0, 18, 16, 18, 0), (0, 38, 0, 8, 8, 8, 1),
                        (-14, 24, 14, 6, 10, 6, 1)],
    "aegis_factory": [(0, 10, 0, 70, 20, 70, 0), (0, 28, -8, 56, 16, 40, 0), (-24, 42, -24, 10, 24, 10, 0),
                      (0, 10, 36, 24, 16, 4, 1), (0, 40, 14, 40, 3, 3, 1)],
    "vanta_factory": [(0, 11, 0, 72, 22, 72, 0), (0, 32, 0, 60, 20, 60, 0), (-26, 50, -26, 12, 20, 12, 0),
                      (26, 50, -26, 12, 20, 12, 0), (0, 11, 37, 28, 18, 4, 1)],
    "aegis_skirmisher": [(0, 7, 0, 12, 8, 18, 0), (0, 12, 3, 8, 6, 8, 1), (-6, 3, 0, 3, 6, 10, 0),
                         (6, 3, 0, 3, 6, 10, 0), (0, 9, 11, 2, 2, 10, 1)],
    "vanta_gunner": [(0, 8, 0, 14, 10, 16, 0), (0, 15, -1, 8, 5, 8, 1), (-5, 9, 10, 3, 3, 12, 1),
                     (5, 9, 10, 3, 3, 12, 1)],
    "aegis_prism": [(0, 8, 0, 26, 10, 36, 0), (0, 16, 0, 16, 8, 16, 1), (0, 16, 16, 4, 4, 22, 1)],
    "vanta_howitzer": [(0, 8, 0, 28, 10, 34, 0), (0, 16, -2, 20, 9, 18, 0), (0, 20, 14, 5, 5, 30, 1)],
}

FACTION = {"aegis": ((176, 192, 216), (60, 140, 255)), "vanta": ((124, 72, 62), (255, 90, 60))}


def write_texture_pair(faction):
    base, _ = FACTION[faction]
    w, h = 32, 16
    # tex1: RGB colour, A = team-colour mask (left half = accent = team coloured)
    rows1 = []
    rows2 = []
    for _y in range(h):
        r1, r2 = bytearray(), bytearray()
        for x in range(w):
            if x < w // 2:
                r1 += bytes((225, 225, 225, 255))
            else:
                r1 += bytes(base + (0,))
            r2 += bytes((0, 64, 0, 255))      # R glow, G reflectivity
        rows1.append(bytes(r1))
        rows2.append(bytes(r2))
    d = os.path.join(GAME, "unittextures")
    write_png(os.path.join(d, faction + "_tex1.png"), w, h, 6, 8, rows1)
    write_png(os.path.join(d, faction + "_tex2.png"), w, h, 6, 8, rows2)


def write_pic(path, faction, kind):
    base, team = FACTION[faction]
    n = 64
    rows = []
    for y in range(n):
        r = bytearray()
        for x in range(n):
            g = 20 + y // 3
            c = (g // 2, g // 2, g)
            if kind == "building" and 14 <= x < 50 and 22 <= y < 52:
                c = base
            elif kind == "mobile" and 10 <= x < 54 and 26 <= y < 46:
                c = base
            elif kind == "commander" and (24 <= x < 40 and 10 <= y < 54):
                c = base
            if (kind == "building" and 26 <= x < 38 and 8 <= y < 22) or \
               (kind == "mobile" and 30 <= x < 60 and 34 <= y < 38) or \
               (kind == "commander" and 40 <= x < 56 and 24 <= y < 30):
                c = team
            r += bytes(c)
        rows.append(bytes(r))
    write_png(path, n, n, 2, 8, rows)


def write_loadpicture(path):
    w, h = 1024, 512
    import random
    rnd = random.Random(7)
    skyline = []
    x = 0
    while x < w:
        bw = rnd.randint(30, 90)
        skyline.append((x, x + bw, rnd.randint(120, 330)))
        x += bw
    rows = []
    for y in range(h):
        r = bytearray()
        for xx in range(w):
            t = y / h
            c = (int(12 + 40 * t), int(14 + 34 * t), int(30 + 60 * t))
            for x0, x1, bh in skyline:
                if x0 <= xx < x1 and y > h - bh:
                    lit = ((xx // 9) + (y // 11)) % 7 == 0
                    c = (200, 180, 90) if lit else (14, 16, 26)
                    break
            r += bytes(c)
        rows.append(bytes(r))
    write_png(path, w, h, 2, 8, rows)


def main():
    for d in ("objects3d", "unittextures", "unitpics", "sidepics", "bitmaps/loadpictures"):
        os.makedirs(os.path.join(GAME, d), exist_ok=True)
    for faction in FACTION:
        write_texture_pair(faction)
        write_pic(os.path.join(GAME, "sidepics", faction + ".png"), faction, "commander")
    for name, boxes in SHAPES.items():
        faction = name.split("_")[0]
        with open(os.path.join(GAME, "objects3d", name + ".s3o"), "wb") as f:
            f.write(build_s3o(boxes, faction + "_tex1.png", faction + "_tex2.png"))
        kind = ("commander" if "commander" in name else
                "building" if name.split("_")[1] in ("pylon", "generator", "factory") else "mobile")
        write_pic(os.path.join(GAME, "unitpics", name + ".png"), faction, kind)
    write_loadpicture(os.path.join(GAME, "bitmaps", "loadpictures", "pylon_city.png"))
    print("assets written to", GAME)


if __name__ == "__main__":
    main()
