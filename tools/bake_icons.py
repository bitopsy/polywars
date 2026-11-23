#!/usr/bin/env python3
"""Bakes the 2D art from the 3D brick models (dev tool; the game ships the PNGs it writes).

    python3 tools/gen_assets.py     # models first
    python3 tools/bake_icons.py     # build pics, strategic icons, side pics, loading screen, README banner

Needs: Pillow, Node + `npm i three@0.160.0`, Playwright (headless Chromium). Set NODE_PATH so node finds
both (e.g. NODE_PATH=$(npm root -g):/path/to/node_modules).
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
GAME = os.path.join(ROOT, "game")
sys.path.insert(0, HERE)
import s3o_export  # noqa: E402

FACTION_BG = {
    "aegis": ((92, 150, 230), (22, 44, 104)),
    "vanta": ((214, 74, 52), (84, 16, 18)),
}
FACTION_ACCENT = {"aegis": (255, 214, 10), "vanta": (255, 160, 30)}
TIER = {  # number of tier studs shown on the build pic (units only)
    "skirmisher": 1, "gunner": 1, "scout": 1, "raider": 1, "constructor": 1, "mender": 1,
    "striker": 2, "bruiser": 2, "prism": 2, "howitzer": 2, "breacher": 2,
    "heavy": 3, "commander": 3,
}
ICON_SIZE = {  # relative strategic icon size (Spring icontypes `size`)
    "commander": 2.0, "heavy": 1.7, "factory": 1.9, "prism": 1.4, "howitzer": 1.4, "breacher": 1.5, "mortar": 1.4,
    "obelisk": 1.4, "striker": 1.2, "bruiser": 1.2, "generator": 1.3, "siphon": 1.3, "pylon": 1.3, "mast": 1.3,
    "turret": 1.2, "beacon": 1.1, "barrier": 1.0, "constructor": 1.0, "mender": 0.9, "scout": 0.8,
    "raider": 0.8, "skirmisher": 0.9, "gunner": 0.9,
}


def run_node(models_json, out_dir, extra):
    env = dict(os.environ)
    cmd = ["node", os.path.join(HERE, "render_models.js"), models_json, out_dir] + extra
    r = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout + r.stderr)
        raise SystemExit("render failed (is NODE_PATH set so node finds `three` and `playwright`?)")


def gradient(size, top, bottom):
    w, h = size
    im = Image.new("RGB", size)
    px = im.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return im


def studded_band(d, w, y0, y1, col, hi):
    d.rectangle([0, y0, w, y1], fill=col)
    n = 8
    step = w / n
    for i in range(n):
        cx = int(step * (i + 0.5))
        d.ellipse([cx - 6, y0 - 3, cx + 6, y0 + 4], fill=hi)
        d.ellipse([cx - 6, y0 - 4, cx + 6, y0 + 2], fill=col)


def build_pic(name, render, size=128):
    faction = name.split("_")[0]
    kind = name.split("_", 1)[1]
    top, bot = FACTION_BG[faction]
    S = size * 4
    bg = gradient((S, S), top, bot)
    d = ImageDraw.Draw(bg)
    # faint brick-wall pattern in the background
    bw, bh = S // 4, S // 8
    line = tuple(int(c * 0.82) for c in bot)
    for row in range(0, 8):
        y = row * bh
        d.line([(0, y), (S, y)], fill=tuple(int(c * 1.0) for c in line), width=3)
        off = (bw // 2) if row % 2 else 0
        for col in range(-1, 5):
            x = col * bw + off
            d.line([(x, y), (x, y + bh)], fill=line, width=3)
    bg = bg.filter(ImageFilter.GaussianBlur(2))
    # unit render, trimmed and fitted
    r = render.convert("RGBA")
    bbox = r.getbbox()
    r = r.crop(bbox)
    tgt = int(S * 0.92)
    k = min(tgt / r.width, tgt / r.height)
    r = r.resize((int(r.width * k), int(r.height * k)), Image.LANCZOS)
    bg = bg.convert("RGBA")
    # baseplate strip at the bottom for the "on a LEGO baseplate" feel
    d = ImageDraw.Draw(bg)
    studded_band(d, S, int(S * 0.9), S, (48, 52, 60), (86, 92, 104))
    bg.alpha_composite(r, ((S - r.width) // 2, int(S * 0.93) - r.height))
    d = ImageDraw.Draw(bg)
    # tier studs (units)
    n = TIER.get(kind, 0)
    ac = FACTION_ACCENT[faction]
    for i in range(n):
        cx, cy = int(S * 0.9) - i * int(S * 0.115), int(S * 0.1)
        rr = int(S * 0.042)
        d.ellipse([cx - rr, cy - rr + 6, cx + rr, cy + rr + 6], fill=tuple(int(c * 0.6) for c in ac))
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=ac)
        d.ellipse([cx - rr * 0.5, cy - rr * 0.6, cx + rr * 0.1, cy - rr * 0.1], fill=(255, 255, 255, 150))
    # bevelled frame
    f = int(S * 0.03)
    d.rectangle([0, 0, S - 1, S - 1], outline=(12, 14, 20), width=f)
    d.line([(f, f), (S - f, f)], fill=(255, 255, 255, 120), width=4)
    d.line([(f, f), (f, S - f)], fill=(255, 255, 255, 90), width=4)
    return bg.convert("RGB").resize((size, size), Image.LANCZOS)


def strategic_icon(name, render, size=64):
    """white-ish brick silhouette with a black outline; the engine tints it with the team colour"""
    S = size * 4
    r = render.convert("RGBA")
    # drop the ground shadow: keep only strongly opaque pixels
    a = r.getchannel("A").point(lambda v: 255 if v > 200 else 0)
    bbox = a.getbbox()
    r = r.crop(bbox)
    a = a.crop(bbox)
    k = min((S - 24) / r.width, (S - 24) / r.height)
    nw, nh = int(r.width * k), int(r.height * k)
    r = r.resize((nw, nh), Image.LANCZOS)
    a = a.resize((nw, nh), Image.LANCZOS).point(lambda v: 255 if v > 128 else 0)
    # luminance-based light grey body so team tint still reads, with contrast kept
    grey = r.convert("L").point(lambda v: int(150 + v * 0.42))
    body = Image.merge("RGBA", (grey, grey, grey, a))
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ox, oy = (S - nw) // 2, (S - nh) // 2
    outline = a.filter(ImageFilter.MaxFilter(13))
    black = Image.new("RGBA", (nw, nh), (0, 0, 0, 255))
    black.putalpha(outline)
    canvas.alpha_composite(black, (ox, oy))
    canvas.alpha_composite(body, (ox, oy))
    return canvas.resize((size, size), Image.LANCZOS)


def hero_scene():
    def line(faction, ry, x0, items):
        return [dict(model="%s_%s" % (faction, m), x=x0 + dx, z=dz, ry=ry, s=sc) for (m, dx, dz, sc) in items]
    items = []
    items += line("aegis", 75, -150, [("commander", 0, 0, 2.2), ("heavy", -55, -75, 1.2), ("prism", -45, 80, 1.15),
                                      ("skirmisher", 55, -40, 1.7), ("skirmisher", 50, 40, 1.7), ("scout", 85, 0, 1.5),
                                      ("striker", 0, -135, 1.3), ("mender", -10, 140, 1.5)])
    items += line("vanta", -75, 150, [("commander", 0, 0, 2.0), ("heavy", 60, 70, 1.2), ("howitzer", 45, -85, 1.15),
                                      ("gunner", -55, 40, 1.7), ("gunner", -50, -40, 1.7), ("raider", -85, 0, 1.5),
                                      ("bruiser", 0, 135, 1.3), ("breacher", 20, -150, 1.15)])
    items += [dict(model="aegis_pylon", x=-290, z=-120, ry=0, s=1.5), dict(model="aegis_turret", x=-270, z=110, ry=60, s=1.5),
              dict(model="vanta_pylon", x=290, z=120, ry=0, s=1.5), dict(model="vanta_turret", x=270, z=-110, ry=-60, s=1.5)]
    return dict(out="hero.png", background=["#4a86d0", "#141a30"],
                plate=dict(w=760, d=440, color="#4a5260", pitch=20), radius=420,
                camera=dict(pos=[0, 210, 430], target=[0, 30, 0], fov=36), items=items)


def main():
    tmp = tempfile.mkdtemp(prefix="pwbake_")
    models_json = os.path.join(tmp, "models.json")
    json.dump(s3o_export.export(), open(models_json, "w"))
    names = sorted(json.load(open(models_json)).keys())

    shots = os.path.join(tmp, "shots")
    run_node(models_json, shots, ["--size", "512", "--views", "iso"])
    run_node(models_json, os.path.join(tmp, "icons"), ["--size", "512", "--views", "icon", "--shadow", "0"])

    os.makedirs(os.path.join(GAME, "unitpics"), exist_ok=True)
    os.makedirs(os.path.join(GAME, "icons"), exist_ok=True)
    os.makedirs(os.path.join(GAME, "sidepics"), exist_ok=True)
    lua = ["-- Strategic (zoomed-out / minimap) icons: white brick silhouettes, tinted by the engine with the team colour.",
           "-- Generated by tools/bake_icons.py. Unit defs reference these via `icontype = \"<unit name>\"`.", "return {"]
    for n in names:
        kind = n.split("_", 1)[1]
        render = Image.open(os.path.join(shots, n + "__iso.png"))
        build_pic(n, render).save(os.path.join(GAME, "unitpics", n + ".png"), optimize=True)
        icon = strategic_icon(n, Image.open(os.path.join(tmp, "icons", n + "__icon.png")))
        icon.save(os.path.join(GAME, "icons", n + ".png"), optimize=True)
        lua.append('\t%s = { bitmap = "icons/%s.png", size = %.1f, distance = 1.0, radiusadjust = 0 },' % (n, n, ICON_SIZE.get(kind, 1.0)))
    lua.append("}")
    open(os.path.join(GAME, "gamedata", "icontypes.lua"), "w").write("\n".join(lua) + "\n")
    # side pics: commander portraits
    for f in ("aegis", "vanta"):
        render = Image.open(os.path.join(shots, "%s_commander__iso.png" % f))
        build_pic("%s_commander" % f, render, size=128).save(os.path.join(GAME, "sidepics", f + ".png"), optimize=True)

    # hero banner for the loading screen / README
    spec = os.path.join(tmp, "scene.json")
    json.dump(hero_scene(), open(spec, "w"))
    run_node(models_json, tmp, ["--scene", spec, "--width", "1536", "--height", "768"])
    hero = Image.open(os.path.join(tmp, "hero.png")).convert("RGB")
    hero.save(os.path.join(GAME, "bitmaps", "loadpictures", "brickwars.jpg"), quality=90, optimize=True, progressive=True)
    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    hero.save(os.path.join(ROOT, "docs", "banner_0.7.0.jpg"), quality=88, optimize=True, progressive=True)
    print("baked", len(names), "build pics + icons; side pics; loading screen; docs banner")


if __name__ == "__main__":
    main()
