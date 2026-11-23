#!/usr/bin/env python3
"""Generates the game's brick art (pure stdlib): LEGO-style S3O models for every unit and structure,
the faction colour atlases, and - if the icon baker has not run yet - plain fallback pictures.

    python3 tools/gen_assets.py          # models + textures -> game/
    python3 tools/bake_icons.py          # (optional, needs three.js + Playwright + Pillow) build pics / icons / load screen

Models are designed in tools/brickunits.py with the brick kit in tools/bricklib.py.
Nothing here needs the Spring engine.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from pngutil import write_png  # noqa: E402
import bricklib as bl  # noqa: E402
import brickunits  # noqa: E402

GAME = os.path.join(os.path.dirname(HERE), "game")


def write_textures():
    d = os.path.join(GAME, "unittextures")
    os.makedirs(d, exist_ok=True)
    for faction in ("aegis", "vanta"):
        rows1, rows2 = bl.texture_rows(faction)
        write_png(os.path.join(d, faction + "_tex1.png"), bl.TEX, bl.TEX, 6, 8, rows1)
        write_png(os.path.join(d, faction + "_tex2.png"), bl.TEX, bl.TEX, 6, 8, rows2)


def write_models(verbose=False):
    d = os.path.join(GAME, "objects3d")
    os.makedirs(d, exist_ok=True)
    units = brickunits.build_all()
    for name, u in sorted(units.items()):
        data = u.s3o()
        model = bl.read_s3o(data)                    # round-trip check: the file must parse back
        with open(os.path.join(d, name + ".s3o"), "wb") as f:
            f.write(data)
        if verbose:
            nv = sum(len(p["verts"]) for p in model["pieces"].values())
            print("%-20s %2d pieces %6d verts  radius %.1f  height %.1f" % (name, len(model["pieces"]), nv, model["radius"], model["height"]))
    return units


def write_fallback_pics():
    """flat coloured squares, only used when bake_icons.py has not produced pictures yet"""
    import struct
    for d in ("unitpics", "sidepics", "icons"):
        os.makedirs(os.path.join(GAME, d), exist_ok=True)
    cols = {"aegis": (60, 140, 255), "vanta": (255, 90, 60)}
    for name in brickunits.build_all():
        path = os.path.join(GAME, "unitpics", name + ".png")
        if os.path.exists(path):
            continue
        c = cols[name.split("_")[0]]
        rows = [bytes(c) * 64 for _ in range(64)]
        write_png(path, 64, 64, 2, 8, rows)


def main():
    write_textures()
    write_models(verbose=True)
    write_fallback_pics()
    print("assets written to", GAME)


if __name__ == "__main__":
    main()
