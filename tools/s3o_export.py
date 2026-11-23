#!/usr/bin/env python3
"""Export S3O models (rest pose, pieces flattened) as JSON for the three.js previewer / icon baker.

    python3 tools/s3o_export.py out.json [model names...]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bricklib as bl  # noqa: E402

GAME = os.path.join(os.path.dirname(HERE), "game")


def flatten(model):
    """-> list of (x,y,z,nx,ny,nz,u,v) in the unit's rest pose (piece offsets applied)."""
    out = []
    pieces = model["pieces"]

    def walk(name, base):
        p = pieces[name]
        o = (base[0] + p["offset"][0], base[1] + p["offset"][1], base[2] + p["offset"][2])
        for v in p["verts"]:
            out.append((v[0] + o[0], v[1] + o[1], v[2] + o[2]) + tuple(v[3:]))
        for c in p["children"]:
            walk(c, o)
    walk(model["root"], (0, 0, 0))
    return out


def export(names=None, objdir=None):
    objdir = objdir or os.path.join(GAME, "objects3d")
    res = {}
    for f in sorted(os.listdir(objdir)):
        if not f.endswith(".s3o"):
            continue
        name = f[:-4]
        if names and name not in names:
            continue
        faction = name.split("_")[0]
        pal = bl.faction_palette(faction)
        order = list(pal.keys())
        model = bl.read_s3o(open(os.path.join(objdir, f), "rb").read())
        verts = flatten(model)
        pos, nrm, col, team, glow = [], [], [], [], []
        for v in verts:
            pos += [round(v[0], 4), round(v[1], 4), round(v[2], 4)]
            nrm += [round(v[3], 4), round(v[4], 4), round(v[5], 4)]
            cx, cy = int(v[6] * bl.GRID), int(v[7] * bl.GRID)
            i = cy * bl.GRID + cx
            rgb, tm, gl, sp = pal[order[i]]
            col += [rgb[0] / 255, rgb[1] / 255, rgb[2] / 255]
            team.append(1 if tm >= 200 else (0.6 if tm > 0 else 0))
            glow.append(1 if gl else 0)
        xs, ys, zs = pos[0::3], pos[1::3], pos[2::3]
        bbox = [min(xs), min(ys), min(zs), max(xs), max(ys), max(zs)]
        res[name] = dict(faction=faction, pos=pos, nrm=nrm, col=col, team=team, glow=glow, bbox=bbox,
                         radius=model["radius"], height=model["height"],
                         pieces=sorted(model["pieces"].keys()))
    return res


if __name__ == "__main__":
    out = sys.argv[1]
    names = set(sys.argv[2:]) or None
    json.dump(export(names), open(out, "w"))
    print("exported", out)
