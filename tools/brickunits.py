#!/usr/bin/env python3
"""Unit / structure designs for Pylon Wars, built from bricks (see bricklib.py).

Piece-name conventions understood by game/scripts/pw_common.lua:
  base            root piece
  turret          yaws toward the target           gun    pitches (child of turret or base)
  flare, flare1.. muzzle points (children of gun)  nano   build-arm tip (builders)
  legl legr       walk cycle (swing about X)       arml armr  arms swing opposite to legs
  wheel*          spin about X while moving        spiny* spinx* spinz*  endless spinners
  brk*            loose bricks that fly off when the unit dies

Every design function takes the faction ("aegis" / "vanta") and returns a bricklib.Unit.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from bricklib import Unit, PLATE, BRICK  # noqa: E402

P = PLATE   # shorthand: one plate in studs


# ------------------------------------------------------------------ shared helpers
def colors(f):
    """faction specific colour roles"""
    return dict(
        hull="main", hull2="sub", trim="accent", trim2="accent2", dark="dark", black="black",
        glow="glow", lens="lens", metal="metal", steel="steel", team="team", warn="warn",
    )


def loose_bricks(u, base, spots, col_cycle=("accent", "warn", "team", "sub")):
    """small coloured bricks sitting on the hull that scatter when the unit dies.
    spots = [(x, yplates, z, w, d)] in studs."""
    for i, (x, yp, z, w, d) in enumerate(spots):
        piv = (x, yp * P, z)
        pc = u.piece("brk%d" % (i + 1), parent=base, pivot=piv)
        pc.brick(w, d, 3 if w * d >= 2 else 1, x, yp, z, col_cycle[i % len(col_cycle)])


def minifig(u, base, f, x=0.0, z=0.0, y0=0.0, scale=1.0, torso="hull", legs="dark", arms=None, head_col="skin",
            helmet=None, visor=None, backpack=None, weapon=None, walk=True, heavy=False):
    """A real minifigure: head, torso, hips, two legs, two arms. Returns dict of pieces.
    Legs are separate pieces (walk cycle), the upper body is the `turret` piece (yaw aiming),
    the right arm is `gun` (pitch aiming) carrying the weapon. Dimensions in studs * scale."""
    k = scale
    arms = arms or torso
    leg_h = 1.5 * k
    hip_y = y0 + leg_h
    w = 2.0 * k * (1.18 if heavy else 1.0)
    # legs ---------------------------------------------------------------
    legl = u.piece("legl", parent=base, pivot=(x - 0.5 * k, hip_y, z))
    legr = u.piece("legr", parent=base, pivot=(x + 0.5 * k, hip_y, z))
    for pc, sx in ((legl, -1), (legr, 1)):
        cx = x + sx * 0.5 * k
        pc.box(0.95 * k, leg_h, 1.0 * k, cx, y0 + leg_h / 2, z, legs, bevel=0.05)
        pc.box(0.98 * k, 0.28 * k, 1.12 * k, cx, y0 + 0.14 * k, z + 0.08 * k, "black", bevel=0.04)   # boots
    base.box(2.0 * k, 0.5 * k, 1.1 * k, x, hip_y + 0.25 * k, z, legs, bevel=0.05)    # hips (static)
    # upper body (turret piece) --------------------------------------------
    ty = hip_y + 0.5 * k
    tur = u.piece("turret", parent=base, pivot=(x, ty, z))
    tur.box(w, 1.5 * k, 1.05 * k, x, ty + 0.75 * k, z, torso, bevel=0.06)
    tur.box(w * 0.5, 0.35 * k, 1.1 * k, x, ty + 0.35 * k, z, "team" if not heavy else "trim", bevel=0.04)  # belt stripe
    # head -----------------------------------------------------------------------
    hy = ty + 1.5 * k
    tur.cyl((x, hy, z), (x, hy + 0.2 * k, z), 0.28 * k, col=head_col, sides=10)             # neck stud
    tur.cyl((x, hy + 0.2 * k, z), (x, hy + 0.95 * k, z), 0.52 * k, col=head_col, sides=12)
    tur.stud(x, hy + 0.95 * k, z, head_col, r=0.26 * k, h=0.2 * k)
    # face: two eyes + visor / smile
    if visor:
        tur.box(0.95 * k, 0.28 * k, 0.12 * k, x, hy + 0.6 * k, z + 0.52 * k, visor, bevel=0.02)
    else:
        for ex in (-0.17, 0.17):
            tur.box(0.1 * k, 0.12 * k, 0.06 * k, x + ex * k, hy + 0.62 * k, z + 0.5 * k, "black", bevel=0.0)
        tur.box(0.3 * k, 0.06 * k, 0.05 * k, x, hy + 0.36 * k, z + 0.5 * k, "black", bevel=0.0)
    if helmet:
        tur.cyl((x, hy + 0.62 * k, z), (x, hy + 1.12 * k, z), 0.58 * k, 0.52 * k, col=helmet, sides=12)
        tur.stud(x, hy + 1.12 * k, z, helmet, r=0.2 * k, h=0.18 * k)
    if backpack:
        tur.box(1.2 * k, 1.1 * k, 0.55 * k, x, ty + 0.85 * k, z - 0.8 * k, backpack, bevel=0.05)
    # left arm (swings in the walk cycle) -------------------------------------
    sh_y = ty + 1.3 * k
    arml = u.piece("arml", parent=tur, pivot=(x - w / 2 - 0.28 * k, sh_y, z))
    arml.box(0.5 * k, 1.25 * k, 0.55 * k, x - w / 2 - 0.28 * k, sh_y - 0.6 * k, z, arms, bevel=0.04)
    arml.box(0.42 * k, 0.4 * k, 0.45 * k, x - w / 2 - 0.28 * k, sh_y - 1.35 * k, z, head_col, bevel=0.04)
    # right arm = gun (pitches), carries the weapon ------------------------------
    gun = u.piece("gun", parent=tur, pivot=(x + w / 2 + 0.28 * k, sh_y, z))
    gx = x + w / 2 + 0.28 * k
    gun.box(0.5 * k, 1.25 * k, 0.55 * k, gx, sh_y - 0.3 * k, z + 0.35 * k, arms, bevel=0.04)
    gun.box(0.42 * k, 0.4 * k, 0.45 * k, gx, sh_y - 0.3 * k, z + 0.95 * k, head_col, bevel=0.04)
    return dict(legl=legl, legr=legr, turret=tur, gun=gun, arml=arml, gx=gx, gz=z + 0.95 * k, gy=sh_y - 0.3 * k)


def weapon_rifle(u, gun, gx, gy, gz, k, body="dark", barrel="steel", tip="glow", length=2.6, flare_name="flare", fat=0.34):
    """pistol-grip rifle held forward by the right hand; adds the muzzle flare piece."""
    gun.box(fat * k, 0.5 * k, 1.1 * k, gx, gy + 0.02 * k, gz + 0.45 * k, body, bevel=0.04)
    gun.rod((gx, gy + 0.08 * k, gz + 0.9 * k), (gx, gy + 0.08 * k, gz + length * k), 0.12 * k, barrel, sides=8)
    gun.box(0.3 * k, 0.3 * k, 0.5 * k, gx, gy + 0.3 * k, gz + 0.5 * k, tip, bevel=0.02)
    fl = u.piece(flare_name, parent=gun, pivot=(gx, gy + 0.08 * k, gz + length * k))
    fl.cyl((gx, gy + 0.08 * k, gz + (length - 0.25) * k), (gx, gy + 0.08 * k, gz + (length + 0.1) * k), 0.16 * k, col=tip, sides=8)
    return fl


# ------------------------------------------------------------------ mobile units
def skirmisher_aegis(f="aegis"):
    """Skirmisher: white/blue astronaut-police minifigure with a pulse rifle."""
    u = Unit("aegis_skirmisher", f, S=4.2)
    base = u.piece("base", pivot=(0, 0, 0))
    m = minifig(u, base, f, torso="hull", legs="hull2", arms="hull", visor="glow", helmet="hull", backpack="trim")
    weapon_rifle(u, m["gun"], m["gx"], m["gy"], m["gz"], 1.0, body="dark", barrel="steel", tip="glow", length=3.0)
    m["turret"].box(1.0, 0.7, 0.12, 0, 2.05, 0.56, "trim", bevel=0.03)            # chest badge
    m["turret"].box(0.5, 0.35, 0.12, 0, 2.9, 0.56, "team", bevel=0.02)
    return u


def gunner_vanta(f="vanta"):
    """Gunner: broad red/black trooper with a belt-fed autocannon."""
    u = Unit("vanta_gunner", f, S=4.2)
    base = u.piece("base", pivot=(0, 0, 0))
    m = minifig(u, base, f, torso="hull", legs="black", arms="hull2", helmet="black", backpack="dark", heavy=True)
    weapon_rifle(u, m["gun"], m["gx"], m["gy"], m["gz"], 1.0, body="black", barrel="steel", tip="glow", length=3.1, fat=0.5)
    t = m["turret"]
    t.box(1.0, 0.9, 0.12, 0, 2.0, 0.58, "trim", bevel=0.03)
    t.box(0.55, 0.5, 0.5, -1.35, 3.0, 0.0, "team", bevel=0.05)    # shoulder pad
    t.box(0.55, 0.5, 0.5, 1.35, 3.0, 0.0, "team", bevel=0.05)
    return u


def constructor(f):
    """Constructor: yellow-hard-hat builder minifigure with a nano-lathe arm and a tool backpack."""
    u = Unit("%s_constructor" % f, f, S=4.4)
    base = u.piece("base", pivot=(0, 0, 0))
    m = minifig(u, base, f, torso="hull2" if f == "vanta" else "hull", legs="dark", arms="hull", helmet="warn", backpack="dark")
    t = m["turret"]
    t.box(1.0, 0.35, 0.12, 0, 2.55, 0.56, "warn", bevel=0.02)       # hi-vis stripe
    t.box(1.0, 0.35, 0.12, 0, 2.1, 0.56, "warn", bevel=0.02)
    # arm-mounted nano lathe: a pipe with a glowing nozzle
    g = m["gun"]
    gx, gy, gz = m["gx"], m["gy"], m["gz"]
    g.rod((gx, gy, gz + 0.1), (gx, gy, gz + 1.9), 0.2, "steel", sides=8)
    g.cyl((gx, gy, gz + 1.9), (gx, gy, gz + 2.3), 0.3, 0.12, col="glow", sides=8)
    nano = u.piece("nano", parent=g, pivot=(gx, gy, gz + 2.3))
    nano.box(0.2, 0.2, 0.2, gx, gy, gz + 2.35, "glow", bevel=0.0)
    # tool backpack with a stud antenna
    t.rod((0.4, 3.0, -0.95), (0.4, 4.6, -0.95), 0.07, "dark", sides=6)
    t.stud(0.4, 4.6, -0.95, "team", r=0.2, h=0.2)
    return u


def scout_aegis(f="aegis"):
    """Scout: 4-stud white/blue speeder trike with a canopy and a light laser."""
    u = Unit("aegis_scout", f, S=3.6)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(3, 5, 1, 0, 1, 0, "hull")                    # chassis plates
    base.brick(2, 3, 1, 0, 2, -0.5, "trim")
    base.slope(3, 2, 3, 0, 1, 2.5, "hull", low=1, flat=0.0, facing="+z")        # nose
    base.slope(2, 2, 3, 0, 3, -1.5, "hull", low=1, flat=1.0, facing="-z")        # tail fin
    base.brick(1, 2, 1, 0, 3, 0.5, "glow", studs=False)                           # canopy
    base.brick(1, 1, 3, 0, 3, -0.3, "hull2")                                      # pilot seat
    base.cyl((0, 2.0, -0.3), (0, 2.5, -0.3), 0.42, col="skin", sides=10)          # tiny pilot head
    base.stud(0, 2.5, -0.3, "skin", r=0.2, h=0.18)
    base.box(3.4, 0.4, 0.35, 0, 1.0, -1.5, "team", bevel=0.04)                  # team stripe
    for i, (sx, sz) in enumerate(((-1, 1.8), (1, 1.8), (-1, -1.6), (1, -1.6))):
        wh = u.piece("wheel%d" % (i + 1), parent=base, pivot=(sx * 1.95, 0.7, sz))
        wh.tire(0.75, 0.55, sx * 1.95, 0.7, sz, side=sx)
    tur = u.piece("turret", parent=base, pivot=(0, 1.4, 1.0))
    tur.cyl((0, 1.4, 1.0), (0, 1.75, 1.0), 0.45, col="dark", sides=8)
    gun = u.piece("gun", parent=tur, pivot=(0, 1.8, 1.0))
    gun.rod((0, 1.8, 1.0), (0, 1.8, 2.9), 0.14, "steel", sides=8)
    gun.box(0.4, 0.4, 0.7, 0, 1.8, 1.2, "glow", bevel=0.03)
    fl = u.piece("flare", parent=gun, pivot=(0, 1.8, 2.9))
    fl.cyl((0, 1.8, 2.7), (0, 1.8, 3.0), 0.19, col="glow", sides=8)
    return u


def raider_vanta(f="vanta"):
    """Raider: red dune-buggy with a roll cage and a swivelling SMG."""
    u = Unit("vanta_raider", f, S=3.7)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(3, 6, 1, 0, 1, 0, "black")
    base.brick(3, 4, 3, 0, 2, -0.6, "hull")
    base.slope(3, 2, 3, 0, 2, 2.0, "hull", low=1, flat=0, facing="+z", studs=False)
    base.brick(2, 1, 1, 0, 5, -1.2, "dark")
    base.box(0.4, 1.7, 0.4, -1.3, 4.0, -1.4, "steel")                       # roll cage
    base.box(0.4, 1.7, 0.4, 1.3, 4.0, -1.4, "steel")
    base.box(3.0, 0.35, 0.4, 0, 4.85, -1.4, "team")
    base.box(0.4, 1.2, 0.4, -1.3, 3.6, 0.7, "steel")
    base.box(0.4, 1.2, 0.4, 1.3, 3.6, 0.7, "steel")
    base.box(3.0, 0.35, 0.4, 0, 4.25, 0.7, "steel")
    base.box(3.3, 0.35, 0.45, 0, 2.0, 2.45, "accent", bevel=0.04)         # bull bar
    for i, (sx, sz) in enumerate(((-1, 2.0), (1, 2.0), (-1, -1.9), (1, -1.9))):
        wh = u.piece("wheel%d" % (i + 1), parent=base, pivot=(sx * 2.1, 0.95, sz))
        wh.tire(0.95, 0.8, sx * 2.1, 0.95, sz, side=sx, hubr=0.5)
    tur = u.piece("turret", parent=base, pivot=(0, 3.4, 0.2))
    tur.cyl((0, 3.4, 0.2), (0, 3.9, 0.2), 0.45, col="dark", sides=8)
    gun = u.piece("gun", parent=tur, pivot=(0, 4.05, 0.2))
    gun.box(0.7, 0.55, 1.2, 0, 4.05, 0.6, "black")
    gun.rod((0, 4.05, 0.8), (0, 4.05, 2.7), 0.15, "steel", sides=8)
    fl = u.piece("flare", parent=gun, pivot=(0, 4.05, 2.7))
    fl.cyl((0, 4.05, 2.5), (0, 4.05, 2.8), 0.2, col="glow", sides=8)
    return u


def striker_aegis(f="aegis"):
    """Striker: bipedal LEGO mech walker with a twin-laser shoulder rack."""
    return _mech(f, "striker", S=4.4, hull="hull", sub="hull2", trim="trim", weapon="laser", fat=1.0)


def bruiser_vanta(f="vanta"):
    return _mech(f, "bruiser", S=4.4, hull="hull", sub="black", trim="trim", weapon="scatter", fat=1.2)


def _mech(f, kind, S, hull, sub, trim, weapon, fat):
    """Mid-tier biped mech. fat = body width multiplier."""
    u = Unit("%s_%s" % (f, kind), f, S=S)
    base = u.piece("base", pivot=(0, 0, 0))
    k = fat
    hip = 2.4
    # legs: boxy two-segment legs, hip pivots
    for name, sx in (("legl", -1), ("legr", 1)):
        pc = u.piece(name, parent=base, pivot=(sx * 1.0 * k, hip, 0))
        cx = sx * 1.0 * k
        pc.brick(1, 2, 3, cx, 0, 0.2, sub if kind == "bruiser" else "hull2")
        pc.brick(1, 1, 3, cx, 3, 0, sub if kind == "bruiser" else "hull2", studs=False)
        pc.box(1.3, 0.35, 2.4, cx, 0.17, 0.35, "black", bevel=0.05)          # foot
        pc.box(0.5, 0.9, 0.9, cx + sx * 0.7, 2.0, 0.1, "trim", bevel=0.04)      # knee guard
    # pelvis + torso
    base.brick(int(round(3 * k)), 2, 1, 0, 6, 0, "dark")
    tur = u.piece("turret", parent=base, pivot=(0, hip + 0.4, 0))
    tur.brick(int(round(4 * k)), 3, 3, 0, 7, 0, hull)
    tur.brick(int(round(3 * k)), 2, 3, 0, 10, -0.2, hull)
    tur.slope(int(round(3 * k)), 2, 3, 0, 10, 1.5, hull, low=0, flat=0, facing="+z", studs=False)   # chest plate
    tur.box(1.4, 0.7, 0.2, 0, 4.7, 1.55, "glow", bevel=0.02) if kind == "striker" else tur.box(1.6, 0.5, 0.2, 0, 4.7, 1.55, "trim", bevel=0.03)
    tur.box(1.0, 0.4, 0.3, 0, 5.5, 1.1, "team", bevel=0.03)                  # team badge on the head crest
    tur.box(1.2, 0.8, 1.2, 0, 6.6, 0.2, "dark", bevel=0.05)                   # head
    tur.box(0.9, 0.25, 0.2, 0, 6.65, 0.85, "glow", bevel=0.0)                  # visor
    tur.box(0.7, 1.1, 0.6, 0, 5.3, -1.4, "dark", bevel=0.05)                   # backpack
    # arms: left arm is a shield / fist, right arm = gun
    arml = u.piece("arml", parent=tur, pivot=(-2.3 * k, 5.0, 0.0))
    arml.box(0.9, 1.8, 1.0, -2.3 * k, 4.2, 0.0, hull, bevel=0.05)
    arml.box(1.0, 0.9, 1.1, -2.3 * k, 3.1, 0.2, "dark", bevel=0.05)
    gun = u.piece("gun", parent=tur, pivot=(2.3 * k, 5.0, 0.2))
    gun.box(0.9, 1.4, 1.0, 2.3 * k, 4.5, 0.2, hull, bevel=0.05)
    if weapon == "laser":
        for dx in (-0.25, 0.25):
            gun.rod((2.3 * k + dx, 4.1, 0.6), (2.3 * k + dx, 4.1, 3.6), 0.14, "steel", sides=8)
        gun.box(0.9, 0.35, 1.1, 2.3 * k, 4.1, 0.9, "glow", bevel=0.03)
        fl = u.piece("flare", parent=gun, pivot=(2.3 * k, 4.1, 3.6))
        fl.cyl((2.3 * k, 4.1, 3.4), (2.3 * k, 4.1, 3.75), 0.28, col="glow", sides=8)
    else:
        gun.rod((2.3 * k, 4.1, 0.6), (2.3 * k, 4.1, 3.0), 0.32, "steel", sides=8)
        gun.rod((2.3 * k, 4.1, 2.4), (2.3 * k, 4.1, 3.2), 0.4, "black", sides=8)
        gun.box(0.9, 0.9, 1.0, 2.3 * k, 4.1, 0.9, "black", bevel=0.04)
        fl = u.piece("flare", parent=gun, pivot=(2.3 * k, 4.1, 3.2))
        fl.cyl((2.3 * k, 4.1, 3.0), (2.3 * k, 4.1, 3.35), 0.38, col="glow", sides=8)
    # shoulder pads (team colour)
    tur.box(1.2, 0.5, 1.5, -2.3 * k, 5.7, 0.1, "team", bevel=0.06)
    tur.box(1.2, 0.5, 1.5, 2.3 * k, 5.7, 0.1, "team", bevel=0.06)
    return u


# ------------------------------------------------------------------ tracked vehicles
def _tracks(u, base, w_out, length, h, y0=0.0, col="black"):
    """two track units (left/right) with road wheels; returns nothing. Adds wheel pieces for the spin anim."""
    n = 0
    for sx in (-1, 1):
        cx = sx * w_out
        base.box(1.5, h, length, cx, y0 + h / 2, 0, col, bevel=0.2)
        for zz in (-length / 2 + 0.35, length / 2 - 0.35):
            base.cyl((cx - 0.77, y0 + h / 2, zz), (cx + 0.77, y0 + h / 2, zz), h / 2 + 0.05, col=col, sides=12)
        nw = max(2, int(length // 1.7))
        for i in range(nw):
            zz = -length / 2 + 0.9 + i * (length - 1.8) / max(1, nw - 1)
            n += 1
            wh = u.piece("wheel%d" % n, parent=base, pivot=(cx, y0 + h / 2, zz))
            wh.cyl((cx + sx * 0.72, y0 + h / 2, zz), (cx + sx * 0.86, y0 + h / 2, zz), h * 0.36, col="steel", sides=10)
            wh.cyl((cx + sx * 0.84, y0 + h / 2, zz), (cx + sx * 0.92, y0 + h / 2, zz), h * 0.16, col="sub" if False else "metal", sides=8)


def prism_aegis(f="aegis"):
    """Prism Tank: sleek white tank, prism crystal on the turret, lance barrel."""
    u = Unit("aegis_prism", f, S=5.0)
    base = u.piece("base", pivot=(0, 0, 0))
    _tracks(u, base, 2.5, 7.0, 1.4)
    base.brick(4, 6, 3, 0, 3, 0, "hull")
    base.slope(4, 2, 3, 0, 3, 3.2, "hull", low=0, flat=0, facing="+z", studs=False)
    base.brick(4, 1, 1, 0, 6, -2.5, "trim")
    base.box(4.2, 0.35, 0.35, 0, 2.0, 3.4, "trim", bevel=0.04)
    for sx in (-1, 1):
        base.box(0.3, 0.6, 5.5, sx * 2.05, 2.3, 0, "team", bevel=0.04)
    base.box(2.0, 0.5, 0.3, 0, 2.6, -3.35, "glow", bevel=0.0)
    tur = u.piece("turret", parent=base, pivot=(0, 2.5, -0.3))
    tur.round_brick(1.5, 3, 0, 6, -0.3, "hull2", stud=False)
    tur.brick(3, 3, 3, 0, 7, -0.3, "hull")
    tur.slope(3, 2, 3, 0, 7, 1.7, "hull", low=1, flat=0, facing="+z", studs=False)
    tur.crystal(0, 4.3, -0.5, 0.85, 1.2, "glow", sides=6, top=1.5, bottom=0.4)
    tur.box(1.0, 0.3, 0.5, 0, 3.05, -1.6, "team", bevel=0.03)
    gun = u.piece("gun", parent=tur, pivot=(0, 3.4, 0.9))
    gun.rod((0, 3.4, 0.9), (0, 3.4, 5.0), 0.28, "steel", sides=10)
    gun.cyl((0, 3.4, 4.0), (0, 3.4, 4.9), 0.45, 0.3, col="glow", sides=10)
    gun.box(0.8, 0.8, 1.6, 0, 3.4, 1.0, "dark", bevel=0.05)
    fl = u.piece("flare", parent=gun, pivot=(0, 3.4, 5.0))
    fl.cyl((0, 3.4, 4.8), (0, 3.4, 5.2), 0.34, col="glow", sides=10)
    loose_bricks(u, base, [(-1.4, 7, -2.5, 1, 1), (1.4, 7, -2.5, 1, 1)])
    return u


def howitzer_vanta(f="vanta"):
    """Howitzer: squat red tank with a huge elevated barrel and ammo crates."""
    u = Unit("vanta_howitzer", f, S=5.0)
    base = u.piece("base", pivot=(0, 0, 0))
    _tracks(u, base, 2.6, 7.0, 1.5)
    base.brick(4, 7, 3, 0, 3, 0, "hull")
    base.brick(4, 3, 3, 0, 6, -2, "black")
    base.slope(4, 2, 3, 0, 3, 3.6, "hull", low=0, flat=0, facing="+z", studs=False)
    for sx in (-1, 1):
        base.box(0.3, 0.8, 6.0, sx * 2.05, 2.4, 0, "team", bevel=0.04)
    base.box(1.0, 0.7, 0.9, -1.4, 3.1, -3.7, "warn", bevel=0.05)     # ammo crates
    base.box(1.0, 0.7, 0.9, 1.4, 3.1, -3.7, "warn", bevel=0.05)
    tur = u.piece("turret", parent=base, pivot=(0, 3.6, -0.5))
    tur.round_brick(1.5, 3, 0, 7, -0.5, "dark", stud=False)
    tur.brick(4, 3, 3, 0, 8, -0.5, "hull2")
    tur.brick(2, 2, 3, 0, 11, -0.8, "hull")
    tur.box(1.3, 0.4, 0.3, 0, 4.2, 1.0, "accent", bevel=0.03)
    gun = u.piece("gun", parent=tur, pivot=(0, 4.0, 0.6))
    gun.box(1.2, 1.1, 1.8, 0, 4.0, 0.7, "black", bevel=0.06)
    gun.rod((0, 4.0, 1.0), (0, 4.0, 5.6), 0.5, "steel", sides=10)
    gun.rod((0, 4.0, 4.8), (0, 4.0, 5.8), 0.62, "black", sides=10)
    fl = u.piece("flare", parent=gun, pivot=(0, 4.0, 5.8))
    fl.cyl((0, 4.0, 5.6), (0, 4.0, 5.95), 0.5, col="glow", sides=10)
    loose_bricks(u, base, [(-1.4, 6, 1.5, 1, 1), (1.4, 6, 1.5, 1, 1), (0.0, 14, -1.0, 1, 1)])
    return u


def heavy_aegis(f="aegis"):
    """Warden: tall, graceful heavy walker with a shoulder beam cannon."""
    return _heavy(f, "warden")


def heavy_vanta(f="vanta"):
    """Juggernaut: squat armoured heavy with twin autocannons."""
    return _heavy(f, "jug")


def _heavy(f, kind):
    aegis = f == "aegis"
    u = Unit("%s_heavy" % f, f, S=5.2 if aegis else 5.4)
    base = u.piece("base", pivot=(0, 0, 0))
    hip = 4.0
    leg_w = 1.4 if aegis else 2.0
    for name, sx in (("legl", -1), ("legr", 1)):
        cx = sx * (2.2 if aegis else 2.7)
        pc = u.piece(name, parent=base, pivot=(cx, hip, 0))
        pc.box(leg_w, 0.5, 3.4, cx, 0.25, 0.4, "black", bevel=0.1)
        pc.brick(int(round(leg_w)), 2, 3, cx, 1, 0, "hull2" if aegis else "black")
        hy = 1.0 * 0.4 + 3 * 0.4
        n_up = 2
        for j in range(n_up):
            pc.brick(int(round(leg_w)), 2, 3, cx, 4 + 3 * j, 0, "hull" if aegis else "hull2", studs=(j == n_up - 1))
        pc.box(0.4, 1.4, 2.2, cx + sx * (leg_w / 2 + 0.2), 2.0, 0, "team", bevel=0.05)
    base.brick(6 if aegis else 7, 3, 1, 0, int(hip / P), 0, "dark")
    tur = u.piece("turret", parent=base, pivot=(0, hip + 0.4, 0))
    wy = int(hip / P) + 1
    tur.brick(6 if aegis else 8, 4, 3, 0, wy, 0, "hull")
    tur.brick(6 if aegis else 8, 4, 3, 0, wy + 3, 0, "hull")
    tur.brick(4 if aegis else 6, 3, 3, 0, wy + 6, -0.3, "hull2")
    tur.slope(4 if aegis else 6, 2, 3, 0, wy + 6, 1.5, "hull", low=0, flat=0, facing="+z", studs=False)
    top = (wy + 9) * P
    tur.box(1.6, 0.9, 1.5, 0, top + 0.45, -0.3, "dark", bevel=0.06)          # head
    tur.box(1.2, 0.3, 0.2, 0, top + 0.5, 0.5, "glow", bevel=0.0)
    tur.box(1.6, 0.4, 0.4, 0, top + 1.05, -0.3, "team", bevel=0.05)
    tur.box(2.4, 1.6, 1.0, 0, hip + 3.2, -2.5, "dark", bevel=0.06)           # reactor backpack
    tur.box(1.6, 0.4, 0.2, 0, hip + 3.5, -3.05, "glow", bevel=0.0)
    xs = 3.6 if aegis else 4.8
    for sx in (-1, 1):
        tur.box(1.4, 0.7, 2.0, sx * xs, top - 0.2, 0, "team", bevel=0.07)    # shoulder pads
    arml = u.piece("arml", parent=tur, pivot=(-xs, top - 0.4, 0))
    arml.box(1.2, 2.6, 1.4, -xs, top - 1.8, 0.1, "hull2", bevel=0.06)
    arml.box(1.5, 1.0, 1.6, -xs, top - 3.5, 0.3, "dark", bevel=0.06)
    gun = u.piece("gun", parent=tur, pivot=(xs, top - 0.4, 0))
    gun.box(1.4, 1.4, 1.6, xs, top - 1.2, 0.2, "hull2", bevel=0.06)
    if aegis:
        gun.rod((xs, top - 1.2, 0.5), (xs, top - 1.2, 5.2), 0.4, "steel", sides=10)
        gun.cyl((xs, top - 1.2, 2.5), (xs, top - 1.2, 4.0), 0.6, 0.5, col="glow", sides=10)
        fl = u.piece("flare", parent=gun, pivot=(xs, top - 1.2, 5.2))
        fl.cyl((xs, top - 1.2, 5.0), (xs, top - 1.2, 5.4), 0.5, col="glow", sides=10)
    else:
        for dx in (-0.45, 0.45):
            gun.rod((xs + dx, top - 1.2, 0.5), (xs + dx, top - 1.2, 4.6), 0.4, "steel", sides=8)
            gun.rod((xs + dx, top - 1.2, 3.7), (xs + dx, top - 1.2, 4.8), 0.5, "black", sides=8)
        gun.box(1.8, 0.9, 1.2, xs, top - 1.2, 0.9, "black", bevel=0.05)
        fl = u.piece("flare", parent=gun, pivot=(xs, top - 1.2, 4.8))
        fl.cyl((xs - 0.45, top - 1.2, 4.6), (xs + 0.45, top - 1.2, 4.6), 0.2, col="glow", sides=6)
    return u


def mender_aegis(f="aegis"):
    """Mender: white support bot with a floating medic cross and a green repair emitter."""
    return _mender(f)


def mender_vanta(f="vanta"):
    return _mender(f)


def _mender(f):
    u = Unit("%s_mender" % f, f, S=4.2)
    base = u.piece("base", pivot=(0, 0, 0))
    m = minifig(u, base, f, torso="hull", legs="dark", arms="hull", helmet="hull" if f == "aegis" else "warn", backpack="dark")
    t = m["turret"]
    # medic cross backpack, spinning rotor on top
    t.box(0.35, 1.4, 0.2, 0, 3.0, -1.1, "red", bevel=0.03)
    t.box(1.4, 0.35, 0.2, 0, 3.0, -1.1, "red", bevel=0.03)
    t.box(1.0, 0.5, 0.12, 0, 2.25, 0.56, "team", bevel=0.02)
    rot = u.piece("spiny1", parent=t, pivot=(0, 4.75, -0.8))
    rot.cyl((0, 4.75, -0.8), (0, 4.85, -0.8), 0.18, col="dark", sides=6)
    rot.box(2.6, 0.1, 0.28, 0, 4.9, -0.8, "glow", bevel=0.0)
    rot.box(0.28, 0.1, 2.6, 0, 4.9, -0.8, "glow", bevel=0.0)
    g = m["gun"]
    gx, gy, gz = m["gx"], m["gy"], m["gz"]
    g.rod((gx, gy, gz + 0.1), (gx, gy, gz + 1.5), 0.2, "steel", sides=8)
    g.cyl((gx, gy, gz + 1.5), (gx, gy, gz + 1.95), 0.34, 0.14, col="green", sides=8)
    nano = u.piece("nano", parent=g, pivot=(gx, gy, gz + 2.0))
    nano.box(0.2, 0.2, 0.2, gx, gy, gz + 2.0, "green", bevel=0.0)
    return u


def breacher_vanta(f="vanta"):
    """Breacher: stubby siege mech with a big demolition cannon and a ram plate (siege unit)."""
    u = Unit("vanta_breacher", f, S=5.0)
    base = u.piece("base", pivot=(0, 0, 0))
    hip = 2.4
    for name, sx in (("legl", -1), ("legr", 1)):
        pc = u.piece(name, parent=base, pivot=(sx * 1.9, hip, 0))
        cx = sx * 1.9
        pc.box(1.7, 0.4, 3.0, cx, 0.2, 0.4, "black", bevel=0.08)
        pc.brick(2, 2, 3, cx, 1, 0, "black")
        pc.brick(2, 2, 3, cx, 4, 0, "hull2", studs=False)
    base.brick(6, 3, 1, 0, 6, 0, "dark")
    tur = u.piece("turret", parent=base, pivot=(0, 2.8, 0))
    tur.brick(6, 4, 3, 0, 7, 0, "hull")
    tur.slope(6, 2, 3, 0, 7, 3.0, "hull2", low=0, flat=0, facing="+z", studs=False)          # ram plate
    tur.brick(4, 3, 3, 0, 10, -0.6, "hull2")
    tur.box(3.0, 0.5, 0.4, 0, 4.1, 3.4, "warn", bevel=0.04)
    tur.box(1.4, 0.6, 1.4, 0, 5.2, 0.3, "dark", bevel=0.05)
    tur.box(1.0, 0.25, 0.2, 0, 5.3, 1.0, "glow", bevel=0.0)
    for sx in (-1, 1):
        tur.box(1.4, 0.5, 2.0, sx * 3.2, 4.0, 0, "team", bevel=0.06)
    gun = u.piece("gun", parent=tur, pivot=(0, 4.8, 0.4))
    gun.box(2.0, 1.2, 1.8, 0, 4.8, 1.0, "black", bevel=0.06)
    gun.rod((0, 4.8, 1.5), (0, 4.8, 4.8), 0.6, "steel", sides=10)
    gun.rod((0, 4.8, 3.9), (0, 4.8, 5.0), 0.78, "black", sides=10)
    fl = u.piece("flare", parent=gun, pivot=(0, 4.8, 5.0))
    fl.cyl((0, 4.8, 4.8), (0, 4.8, 5.15), 0.65, col="glow", sides=10)
    loose_bricks(u, base, [(-2.0, 10, -1.0, 1, 1), (2.0, 10, -1.0, 1, 1)])
    return u


# ------------------------------------------------------------------ commanders
def commander(f):
    """Hero minifigure: big, armoured, caped, with a jetpack and a heroic energy cannon.
    All six weapon slots share the aim pieces (turret yaw + gun pitch); flare1..6 are the muzzles."""
    aegis = f == "aegis"
    u = Unit("%s_commander" % f, f, S=4.6 if aegis else 4.8)
    base = u.piece("base", pivot=(0, 0, 0))
    kk = 1.45 if aegis else 1.6
    m = minifig(u, base, f, scale=kk, torso="hull", legs="hull2" if aegis else "black",
                arms="hull2" if aegis else "hull", helmet="hull" if aegis else "black",
                visor="glow" if aegis else "lens", backpack=None, heavy=not aegis)
    t, g = m["turret"], m["gun"]
    ty = 1.5 * kk + 0.5 * kk                      # hip height + hips = where the upper body starts
    wd = 2.0 * kk * (1.0 if aegis else 1.18)      # torso width
    # chest plate: team colour tabard with a glowing core
    t.box(wd * 0.65, 1.0 * kk, 0.14, 0, ty + 0.85 * kk, 0.58 * kk, "team", bevel=0.03)
    t.box(0.45 * kk, 0.45 * kk, 0.16, 0, ty + 0.85 * kk, 0.64 * kk, "glow", bevel=0.02)
    # armour: pauldrons (team colour) with a stud row, belt buckle
    for sx in (-1, 1):
        t.box(0.95 * kk, 0.5 * kk, 1.3 * kk, sx * (wd / 2 + 0.1 * kk), ty + 1.5 * kk, 0, "team", bevel=0.06)
        t.stud(sx * (wd / 2 + 0.1 * kk), ty + 1.75 * kk, 0.0, "team")
    t.box(0.5 * kk, 0.4 * kk, 0.15, 0, ty + 0.35 * kk, 0.58 * kk, "warn", bevel=0.02)
    # cape: a big team-colour plate hanging behind (angled out a little)
    with t.rotated((0, ty + 1.5 * kk, -0.55 * kk), rx=-10):
        t.box(wd * 0.9, 2.2 * kk, 0.1, 0, ty + 0.5 * kk, -0.62 * kk, "team", bevel=0.03)
    # jetpack with two glowing thrusters
    t.box(1.5 * kk, 1.2 * kk, 0.7 * kk, 0, ty + 1.0 * kk, -0.62 * kk - 0.25 * kk, "dark", bevel=0.06)
    for sx in (-1, 1):
        t.cyl((sx * 0.45 * kk, ty + 0.1 * kk, -0.95 * kk), (sx * 0.45 * kk, ty + 1.55 * kk, -0.95 * kk), 0.3 * kk, col="metal", sides=8)
        t.cyl((sx * 0.45 * kk, ty - 0.2 * kk, -0.95 * kk), (sx * 0.45 * kk, ty + 0.15 * kk, -0.95 * kk), 0.26 * kk, 0.36 * kk, col="glow", sides=8)
    # head gear
    hy = ty + 1.5 * kk
    if aegis:
        t.box(0.14, 0.7 * kk, 0.95 * kk, 0, hy + 1.35 * kk, -0.05 * kk, "trim", bevel=0.02)          # crest fin
        t.rod((-0.4 * kk, hy + 0.9 * kk, -0.5 * kk), (-0.4 * kk, hy + 2.3 * kk, -0.5 * kk), 0.05 * kk, "dark", sides=4)  # antenna
        t.stud(-0.4 * kk, hy + 2.3 * kk, -0.5 * kk, "glow", r=0.14 * kk, h=0.15 * kk)
    else:
        for sx in (-1, 1):   # horns
            t.cyl((sx * 0.5 * kk, hy + 1.05 * kk, 0), (sx * 0.62 * kk, hy + 1.6 * kk, 0.0), 0.14 * kk, 0.05 * kk, col="warn", sides=6)
            t.cyl((sx * 0.62 * kk, hy + 1.6 * kk, 0), (sx * 0.78 * kk, hy + 2.15 * kk, 0.0), 0.06 * kk, 0.03 * kk, col="warn", sides=6)
        t.box(0.75 * kk, 0.3 * kk, 0.14, 0, hy + 0.3 * kk, 0.56 * kk, "black", bevel=0.0)           # mask
    # weapon arm: big energy cannon
    gx, gy, gz = m["gx"], m["gy"], m["gz"]
    if aegis:
        g.box(0.85 * kk, 0.85 * kk, 1.7 * kk, gx, gy, gz + 0.7 * kk, "dark", bevel=0.05)
        g.rod((gx, gy, gz + 1.4 * kk), (gx, gy, gz + 3.6 * kk), 0.2 * kk, "steel", sides=10)
        g.cyl((gx, gy, gz + 1.7 * kk), (gx, gy, gz + 2.9 * kk), 0.46 * kk, 0.36 * kk, col="glow", sides=10)
        g.box(0.4 * kk, 0.4 * kk, 1.1 * kk, gx, gy + 0.55 * kk, gz + 1.0 * kk, "trim", bevel=0.04)
        tipz = gz + 3.6 * kk
    else:
        g.box(1.1 * kk, 1.0 * kk, 1.6 * kk, gx, gy, gz + 0.7 * kk, "black", bevel=0.05)
        g.rod((gx, gy, gz + 1.3 * kk), (gx, gy, gz + 3.2 * kk), 0.38 * kk, "steel", sides=10)
        g.rod((gx, gy, gz + 2.6 * kk), (gx, gy, gz + 3.5 * kk), 0.5 * kk, "black", sides=10)
        g.box(0.4 * kk, 0.45 * kk, 0.9 * kk, gx, gy + 0.65 * kk, gz + 1.0 * kk, "accent", bevel=0.04)
        tipz = gz + 3.5 * kk
    for i in range(6):
        fl = u.piece("flare%d" % (i + 1), parent=g, pivot=(gx, gy, tipz))
        if i == 0:
            fl.cyl((gx, gy, tipz - 0.2 * kk), (gx, gy, tipz + 0.1 * kk), (0.26 if aegis else 0.4) * kk, col="glow", sides=8)
        else:   # keep every muzzle piece a real (tiny) mesh so the engine never sees an empty piece
            fl.box(0.02, 0.02, 0.02, gx, gy, tipz, "glow", bevel=0.0)
    # nano emitter in the off hand (builds structures)
    arml = m["arml"]
    ax = -wd / 2 - 0.28 * kk
    sh_y = ty + 1.3 * kk
    nano = u.piece("nano", parent=arml, pivot=(ax, sh_y - 1.5 * kk, 0.45 * kk))
    nano.box(0.3 * kk, 0.3 * kk, 0.8 * kk, ax, sh_y - 1.5 * kk, 0.5 * kk, "glow", bevel=0.03)
    return u


# ------------------------------------------------------------------ structures
def pylon(f):
    """Pylon: tall stacked tower. Glowing lamp on top, spinning ring of studs (power field)."""
    aegis = f == "aegis"
    u = Unit("%s_pylon" % f, f, S=4.6)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(4, 4, 1, 0, 0, 0, "dark")                         # baseplate
    base.brick(2, 2, 3, 0, 1, 0, "hull")
    base.brick(2, 2, 3, 0, 4, 0, "hull2" if aegis else "black")
    base.round_brick(0.85, 3, 0, 7, 0, "hull", stud=False)
    base.round_brick(0.7, 3, 0, 10, 0, "trim", stud=False)
    base.round_brick(0.55, 3, 0, 13, 0, "hull", stud=False)
    if aegis:
        for k, sx in enumerate((-1, 1)):
            base.slope(1, 1, 3, sx * 1.35, 1, 0, "trim", low=0, flat=0, facing="+x" if sx < 0 else "-x", studs=False)
    else:
        base.box(3.8, 0.4, 0.5, 0, 5.2, 0, "warn", bevel=0.05)
        for sx in (-1, 1):
            base.box(0.5, 1.2, 0.5, sx * 1.5, 4.6, 0, "black", bevel=0.05)
    base.box(1.0, 0.35, 1.0, 0, 6.0, 0, "team", bevel=0.05) if False else None
    base.cyl((0, 5.4, 0), (0, 5.8, 0), 0.65, col="team", sides=10)
    base.round_brick(0.45, 1, 0, 14 + 3, 0, "metal", stud=False) if False else None
    # glowing lamp
    base.cyl((0, 5.6, 0), (0, 5.95, 0), 0.5, col="dark", sides=10)
    base.crystal(0, 6.6, 0, 0.55, 0.85, "glow", sides=6, top=1.0, bottom=0.5) if aegis else base.cyl((0, 5.95, 0), (0, 7.2, 0), 0.5, 0.35, col="glow", sides=10)
    base.stud(0, 7.2, 0, "glow2", r=0.2, h=0.25) if not aegis else None
    ring = u.piece("spiny1", parent=base, pivot=(0, 4.9, 0))
    n = 6
    for i in range(n):
        a = 2 * math.pi * i / n
        x, z = 1.7 * math.cos(a), 1.7 * math.sin(a)
        ring.cyl((x, 4.75, z), (x, 5.0, z), 0.26, col="glow", sides=8)
        with ring.rotated((0, 4.88, 0), ry=-math.degrees(a)):
            ring.box(1.3, 0.1, 0.16, 0.95, 4.88, 0, "dark", bevel=0.0)
        ring.box(0.12, 0.12, 0.8, x * 0.62, 4.88, z * 0.62, "dark", bevel=0.0) if False else None
    ring.cyl((0, 4.85, 0), (0, 4.95, 0), 1.55, 1.5, col="dark", sides=12, caps=False) if False else None
    loose_bricks(u, base, [(-1.4, 1, -1.4, 1, 1), (1.4, 1, 1.4, 1, 1)], ("warn", "team"))
    return u


def generator(f):
    """Generator: chunky battery bank with glowing cells and a spinning turbine fan."""
    aegis = f == "aegis"
    u = Unit("%s_generator" % f, f, S=4.8)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(6, 6, 1, 0, 0, 0, "dark")
    base.brick(5, 5, 3, 0, 1, 0, "hull")
    base.brick(5, 1, 1, 0, 4, 2.0, "trim", studs=False)
    for sx in (-1, 1):
        for sz in (-1, 1):
            base.round_brick(0.72, 6, sx * 1.6, 4, sz * 1.6, "hull2" if aegis else "black", stud=False)
            base.cyl((sx * 1.6, 4.0, sz * 1.6), (sx * 1.6, 4.2, sz * 1.6), 0.5, col="glow", sides=10)
            base.cyl((sx * 1.6, 4.2, sz * 1.6), (sx * 1.6, 4.45, sz * 1.6), 0.25, col="metal", sides=8)
    base.brick(2, 2, 3, 0, 4, 0, "hull2")
    base.box(2.4, 0.45, 0.35, 0, 2.4, 2.55, "glow", bevel=0.02)
    base.box(1.4, 0.7, 0.35, 0, 1.65, -2.55, "team", bevel=0.04)
    fan = u.piece("spiny1", parent=base, pivot=(0, 4.2, 0))
    for a in (0, 60, 120):
        with fan.rotated((0, 4.2, 0), ry=a):
            fan.box(2.4, 0.08, 0.5, 0, 4.25, 0, "glow" if aegis else "accent", bevel=0.0)
    fan.cyl((0, 4.1, 0), (0, 4.4, 0), 0.28, col="metal", sides=8)
    loose_bricks(u, base, [(-2.2, 1, -2.2, 1, 1), (2.2, 1, 2.2, 1, 1)], ("warn", "team"))
    return u


def siphon(f):
    """Metal siphon: derrick with a spinning drill head and a pipe + ore barrel."""
    aegis = f == "aegis"
    u = Unit("%s_siphon" % f, f, S=4.6)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(6, 6, 1, 0, 0, 0, "dark")
    base.brick(4, 4, 3, 0, 1, 0, "hull")
    base.round_brick(1.4, 3, 0, 4, 0, "hull2", stud=False)
    base.rod((-1.6, 1.2, -1.6), (-1.6, 3.8, -1.6), 0.14, "steel", sides=6)
    base.rod((1.6, 1.2, -1.6), (1.6, 3.8, -1.6), 0.14, "steel", sides=6)
    base.box(3.4, 0.35, 0.35, 0, 3.8, -1.6, "trim", bevel=0.03)
    base.box(1.2, 1.0, 1.0, 1.9, 1.7, 1.7, "warn", bevel=0.05)          # ore crate
    base.cyl((-1.9, 0.5, 1.8), (-1.9, 1.7, 1.8), 0.7, col="black", sides=10)   # barrel
    base.cyl((-1.9, 1.7, 1.8), (-1.9, 1.8, 1.8), 0.55, col="team", sides=10)
    base.box(1.6, 0.5, 0.2, 0, 2.5, 2.1, "team", bevel=0.03)
    drill = u.piece("spiny1", parent=base, pivot=(0, 2.4, 0))
    drill.cyl((0, 2.0, 0), (0, 2.7, 0), 0.5, col="metal", sides=10)
    drill.cyl((0, 2.7, 0), (0, 3.9, 0), 0.5, 0.12, col="steel", sides=6)
    for h_ in (2.9, 3.3, 3.7):
        drill.box(1.3 - (h_ - 2.9) * 0.9, 0.1, 0.25, 0, h_, 0, "glow" if aegis else "accent", bevel=0.0)
    loose_bricks(u, base, [(-2.3, 1, -2.3, 1, 1), (2.3, 1, -2.3, 1, 1)], ("warn", "team"))
    return u


def factory(f):
    """Weapon factory: a proper LEGO hangar. 8x8 studs, studded roof, rolling door, crane, flags."""
    aegis = f == "aegis"
    u = Unit("%s_factory" % f, f, S=5.2)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(8, 8, 1, 0, 0, 0, "dark")                                 # baseplate
    # walls
    base.brick(8, 1, 6, 0, 1, -3.5, "hull")
    base.brick(1, 6, 6, -3.5, 1, 0, "hull")
    base.brick(1, 6, 6, 3.5, 1, 0, "hull")
    base.brick(2, 1, 6, -3, 1, 3.5, "hull")
    base.brick(2, 1, 6, 3, 1, 3.5, "hull")
    base.brick(4, 1, 2, 0, 5, 3.5, "trim")                               # lintel above the door
    # hangar door (dark, ribbed) and the glowing opening
    base.box(4.0, 2.2, 0.2, 0, 1.0 + 1.1, 3.6, "black", bevel=0.03)
    for i in range(4):
        base.box(3.8, 0.1, 0.3, 0, 1.0 + 0.4 + i * 0.5, 3.62, "dark", bevel=0.0)
    base.box(4.4, 0.3, 0.45, 0, 3.4, 3.65, "warn" if not aegis else "glow", bevel=0.03)
    # roof: two layers of plates, studs on top
    base.brick(8, 8, 1, 0, 7, 0, "hull2")
    base.brick(6, 6, 3, 0, 8, -0.5, "hull")
    base.slope(6, 2, 3, 0, 8, 2.5, "hull2", low=0, flat=0, facing="+z", studs=False) if False else None
    # chimneys / vents
    if aegis:
        base.round_brick(0.8, 6, -2.2, 11, -2.2, "trim", stud=False)
        base.round_brick(0.8, 6, 2.2, 11, -2.2, "trim", stud=False)
        base.cyl((-2.2, 5.7, -2.2), (-2.2, 5.95, -2.2), 0.65, col="glow", sides=10)
        base.cyl((2.2, 5.7, -2.2), (2.2, 5.95, -2.2), 0.65, col="glow", sides=10)
    else:
        for sx in (-1, 1):
            base.round_brick(0.85, 9, sx * 2.4, 11, -2.2, "black", stud=False)
            base.cyl((sx * 2.4, 7.5, -2.2), (sx * 2.4, 7.75, -2.2), 0.95, col="accent", sides=10)
    # team flags
    for sx in (-1, 1):
        base.rod((sx * 3.6, 3.2, 3.6), (sx * 3.6, 7.6, 3.6), 0.08, "dark", sides=4)
        base.box(0.1, 0.8, 1.3, sx * 3.6, 7.2, 3.1, "team", bevel=0.0)
    # side stripes
    for sx in (-1, 1):
        base.box(0.2, 0.7, 5.0, sx * 4.05, 2.6, 0, "team", bevel=0.04)
    # crane on the roof with a nano head
    crane = u.piece("spiny1", parent=base, pivot=(0, 5.4, -0.5))
    crane.cyl((0, 5.4, -0.5), (0, 5.7, -0.5), 0.9, col="dark", sides=12)
    crane.box(0.6, 1.6, 0.6, 0, 6.5, -0.5, "hull2", bevel=0.05)
    crane.box(0.5, 0.5, 3.2, 0, 7.2, 0.9, "trim", bevel=0.05)
    crane.box(0.35, 0.8, 0.35, 0, 6.6, 2.3, "steel", bevel=0.03)
    nano = u.piece("nano", parent=crane, pivot=(0, 6.15, 2.3))
    nano.box(0.35, 0.35, 0.35, 0, 6.15, 2.3, "glow", bevel=0.0)
    # a few loose studded bricks lying around on the roof
    loose_bricks(u, base, [(-2.0, 11, 0.8, 2, 1), (2.0, 11, 0.8, 2, 1), (0.0, 11, 2.3, 1, 1)], ("warn", "accent", "team"))
    return u


def turret(f):
    """Sentry / Bastion: studded bunker with a spinning cannon head."""
    aegis = f == "aegis"
    u = Unit("%s_turret" % f, f, S=4.4)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(5, 5, 1, 0, 0, 0, "dark")
    base.brick(4, 4, 3, 0, 1, 0, "hull")
    base.slope(4, 1, 3, 0, 1, -1.6, "hull2", low=1, flat=0, facing="-z", studs=False) if False else None
    for sx in (-1, 1):
        base.box(0.5, 1.2, 4.2, sx * 2.1, 1.6, 0, "team", bevel=0.05) if False else None
    base.box(4.1, 0.35, 4.1, 0, 2.2, 0, "trim", bevel=0.04)
    base.box(1.6, 0.4, 0.2, 0, 1.3, 2.05, "team", bevel=0.02)
    tur = u.piece("turret", parent=base, pivot=(0, 1.8, 0))
    tur.round_brick(1.3, 3, 0, 4, 0, "hull2", stud=False)
    tur.brick(2, 3, 3, 0, 7, -0.1, "hull")
    tur.slope(2, 2, 3, 0, 7, 1.6, "hull", low=0, flat=0, facing="+z", studs=False) if False else None
    tur.box(1.0, 0.8, 0.3, 0, 3.0, 1.2, "glow" if aegis else "accent", bevel=0.02)
    tur.box(0.4, 0.4, 0.3, 0, 3.7, -0.7, "team", bevel=0.03)
    gun = u.piece("gun", parent=tur, pivot=(0, 2.95, 0.6))
    if aegis:
        gun.box(0.9, 0.9, 1.4, 0, 2.95, 0.9, "dark", bevel=0.05)
        gun.rod((0, 2.95, 1.4), (0, 2.95, 4.0), 0.26, "steel", sides=10)
        gun.cyl((0, 2.95, 2.0), (0, 2.95, 3.2), 0.42, 0.34, col="glow", sides=10)
        z = 4.0
    else:
        for dx in (-0.4, 0.4):
            gun.rod((dx, 2.95, 1.2), (dx, 2.95, 3.9), 0.28, "steel", sides=8)
            gun.rod((dx, 2.95, 3.1), (dx, 2.95, 4.0), 0.36, "black", sides=8)
        gun.box(1.5, 0.9, 1.4, 0, 2.95, 0.9, "black", bevel=0.05)
        z = 4.0
    fl = u.piece("flare", parent=gun, pivot=(0, 2.95, z))
    fl.cyl((0, 2.95, z - 0.2), (0, 2.95, z + 0.1), 0.3, col="glow", sides=8)
    loose_bricks(u, base, [(-1.7, 1, -1.7, 1, 1), (1.7, 1, -1.7, 1, 1)], ("warn", "team"))
    return u


def beacon(f):
    """Repair beacon: little white tower with a big red/white medical cross and a spinning light."""
    aegis = f == "aegis"
    u = Unit("%s_beacon" % f, f, S=4.4)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(5, 5, 1, 0, 0, 0, "dark")
    base.brick(3, 3, 3, 0, 1, 0, "hull")
    base.brick(3, 3, 3, 0, 4, 0, "hull")
    base.box(0.55, 1.9, 0.3, 0, 2.1, 1.55, "red", bevel=0.03)            # cross
    base.box(1.9, 0.55, 0.3, 0, 2.1, 1.55, "red", bevel=0.03)
    base.box(0.55, 1.9, 0.3, 0, 2.1, -1.55, "red", bevel=0.03)
    base.box(1.9, 0.55, 0.3, 0, 2.1, -1.55, "red", bevel=0.03)
    base.box(3.1, 0.35, 3.1, 0, 3.05, 0, "team", bevel=0.04)
    base.round_brick(0.9, 3, 0, 8, 0, "hull2", stud=False)
    for sx in (-1, 1):
        base.cyl((sx * 2.0, 0.4, 2.0), (sx * 2.0, 1.4, 2.0), 0.55, col="green", sides=10)
        base.stud(sx * 2.0, 1.4, 2.0, "green")
    lamp = u.piece("spiny1", parent=base, pivot=(0, 4.0, 0))
    lamp.cyl((0, 3.7, 0), (0, 4.3, 0), 0.62, col="glow", sides=10)
    lamp.box(1.5, 0.12, 0.2, 0, 4.0, 0, "white", bevel=0.0)
    lamp.box(0.2, 0.12, 1.5, 0, 4.0, 0, "white", bevel=0.0)
    lamp.cyl((0, 4.3, 0), (0, 4.5, 0), 0.4, col="white", sides=8)
    loose_bricks(u, base, [(-1.9, 1, -1.9, 1, 1)], ("warn",))
    return u


def mast(f):
    """Sensor mast: tall lattice tower with a spinning radar dish."""
    aegis = f == "aegis"
    u = Unit("%s_mast" % f, f, S=4.4)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(4, 4, 1, 0, 0, 0, "dark")
    base.brick(2, 2, 3, 0, 1, 0, "hull")
    for sx in (-1, 1):
        for sz in (-1, 1):
            base.rod((sx * 0.8, 1.2, sz * 0.8), (sx * 0.25, 9.0, sz * 0.25), 0.09, "steel", sides=6)
    for i, y in enumerate((2.4, 4.0, 5.6, 7.2)):
        w = 1.6 - i * 0.37
        base.box(w, 0.1, 0.1, 0, y, w / 2, "steel", bevel=0.0)
        base.box(w, 0.1, 0.1, 0, y, -w / 2, "steel", bevel=0.0)
        base.box(0.1, 0.1, w, w / 2, y, 0, "steel", bevel=0.0)
        base.box(0.1, 0.1, w, -w / 2, y, 0, "steel", bevel=0.0)
    base.brick(2, 2, 1, 0, 3, 0, "team", studs=False) if False else None
    base.box(1.0, 0.5, 1.0, 0, 1.9, 0.0, "team", bevel=0.05)
    base.cyl((0, 9.0, 0), (0, 9.5, 0), 0.5, col="hull2", sides=10)
    dish = u.piece("spiny1", parent=base, pivot=(0, 9.5, 0))
    dish.cyl((0, 9.5, 0), (0, 9.9, 0), 0.25, col="dark", sides=8)
    dish.box(0.2, 0.2, 2.4, 0, 10.0, 0.3, "metal", bevel=0.0) if False else None
    with dish.rotated((0, 10.0, 0), rx=-35):
        dish.cone((0, 10.0, -0.1), (0, 10.0, 0.5), 0.2, 1.3, col="metal", sides=12)
        dish.cyl((0, 10.0, 0.45), (0, 10.0, 0.52), 1.28, col="sub", sides=12, caps=True)
        dish.rod((0, 10.0, 0.5), (0, 10.0, 1.25), 0.07, "dark", sides=4)
        dish.cyl((0, 10.0, 1.2), (0, 10.0, 1.4), 0.17, col="glow", sides=6)
    loose_bricks(u, base, [(-1.4, 1, -1.4, 1, 1), (1.4, 1, 1.4, 1, 1)], ("warn", "team"))
    return u


def barrier(f):
    """Barrier: a staggered LEGO wall, 3 studs wide... 6 long, 3 bricks tall with a team-colour cap."""
    aegis = f == "aegis"
    u = Unit("%s_barrier" % f, f, S=4.0)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(6, 2, 1, 0, 0, 0, "dark")
    rows = [("hull", [(-2, 2), (0, 2), (2, 2)]), ("hull2", [(-3, 1), (-1, 2), (1, 2), (3, 1)]), ("hull", [(-2, 2), (0, 2), (2, 2)])]
    y = 1
    for r, (col, bricks) in enumerate(rows):
        for x, w in bricks:
            c = col
            if r == 1 and x in (-1, 1):
                c = "trim"
            base.brick(w - 0.04, 1.6, 3, x, y, 0, c, studs=False)
        y += 3
    base.brick(6, 2, 1, 0, y, 0, "team")
    for sx in (-1, 1):
        base.box(0.5, 1.2, 1.9, sx * 2.8, 2.9, 0, "dark", bevel=0.05) if False else None
    loose_bricks(u, base, [(-2.2, y + 1, 0.0, 1, 1)], ("warn",))
    return u


def obelisk(f):
    """Obelisk: tall tapering tower topped with a floating crystal that spins (Aegis long beam)."""
    u = Unit("aegis_obelisk", f, S=4.6)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(5, 5, 1, 0, 0, 0, "dark")
    base.brick(4, 4, 3, 0, 1, 0, "hull")
    base.brick(3, 3, 3, 0, 4, 0, "hull2")
    base.brick(2, 2, 3, 0, 7, 0, "hull")
    base.cyl((0, 3.6, 0), (0, 5.8, 0), 0.9, 0.55, col="hull", sides=4) if False else None
    for y in (1.9, 3.0, 4.2):
        base.box(4.1 - (y - 1.9) * 0.5, 0.25, 4.1 - (y - 1.9) * 0.5, 0, y, 0, "trim", bevel=0.03)
    base.box(1.2, 0.5, 0.2, 0, 1.7, 2.05, "team", bevel=0.02)
    base.cyl((0, 3.6, 0), (0, 3.75, 0), 0.75, col="glow", sides=10)
    tur = u.piece("turret", parent=base, pivot=(0, 4.0, 0))
    tur.cyl((0, 3.6, 0), (0, 4.2, 0), 0.7, 0.5, col="dark", sides=8)
    gun = u.piece("gun", parent=tur, pivot=(0, 5.0, 0))
    gun.crystal(0, 5.0, 0, 0.7, 0.8, "glow", sides=6, top=1.4, bottom=0.8)
    gun.box(0.9, 0.35, 0.9, 0, 4.6, 0, "team", bevel=0.04)
    gun.rod((0, 5.0, 0.4), (0, 5.0, 2.8), 0.13, "steel", sides=6)
    fl = u.piece("flare", parent=gun, pivot=(0, 5.0, 2.8))
    fl.cyl((0, 5.0, 2.6), (0, 5.0, 2.9), 0.2, col="glow", sides=6)
    spin = u.piece("spiny1", parent=base, pivot=(0, 4.2, 0))
    for a in range(4):
        x, z = 1.15 * math.cos(a * math.pi / 2), 1.15 * math.sin(a * math.pi / 2)
        spin.cyl((x, 3.7, z), (x, 4.3, z), 0.2, col="glow", sides=6)
    loose_bricks(u, base, [(-1.8, 1, -1.8, 1, 1), (1.8, 1, -1.8, 1, 1)], ("warn", "team"))
    return u


def mortar(f):
    """Mortar battery: low studded bunker with a fat elevated mortar tube and ammo."""
    u = Unit("vanta_mortar", f, S=4.6)
    base = u.piece("base", pivot=(0, 0, 0))
    base.brick(6, 6, 1, 0, 0, 0, "dark")
    base.brick(5, 5, 3, 0, 1, 0, "hull")
    base.brick(5, 1, 1, 0, 4, 2.0, "trim", studs=False)
    base.box(0.8, 0.8, 0.8, -1.8, 2.0, -1.8, "warn", bevel=0.05)
    base.box(0.8, 0.8, 0.8, -1.0, 2.0, -1.8, "warn", bevel=0.05)
    base.box(1.6, 0.4, 0.2, 1.4, 1.9, 2.55, "team", bevel=0.02)
    tur = u.piece("turret", parent=base, pivot=(0, 2.0, 0))
    tur.round_brick(1.5, 3, 0, 4, 0, "dark", stud=False)
    tur.box(2.4, 0.6, 2.4, 0, 2.5, 0, "black", bevel=0.06)
    gun = u.piece("gun", parent=tur, pivot=(0, 3.0, 0))
    with gun.rotated((0, 3.0, 0), rx=-35):
        gun.rod((0, 3.0, -0.5), (0, 3.0, 3.6), 0.75, "steel", sides=10)
        gun.rod((0, 3.0, 3.0), (0, 3.0, 3.9), 0.92, "black", sides=10)
        gun.rod((0, 3.0, -0.8), (0, 3.0, 0.3), 0.9, "hull", sides=10)
    ang = math.radians(35)
    tz, ty = 3.9 * math.cos(ang), 3.0 + 3.9 * math.sin(ang)
    fl = u.piece("flare", parent=gun, pivot=(0, ty, tz))
    fl.cyl((0, ty - 0.1, tz - 0.15), (0, ty + 0.1, tz + 0.1), 0.6, col="glow", sides=10)
    loose_bricks(u, base, [(-2.1, 1, 2.1, 1, 1), (2.1, 1, -2.1, 1, 1)], ("warn", "team"))
    return u


# ------------------------------------------------------------------ registry
def build_all():
    out = {}
    for f in ("aegis", "vanta"):
        for kind, fn in (("pylon", pylon), ("generator", generator), ("siphon", siphon), ("factory", factory),
                         ("turret", turret), ("beacon", beacon), ("mast", mast), ("barrier", barrier),
                         ("commander", commander), ("constructor", constructor)):
            u = fn(f)
            u.name = "%s_%s" % (f, kind)
            out[u.name] = u
    out["aegis_skirmisher"] = skirmisher_aegis()
    out["vanta_gunner"] = gunner_vanta()
    out["aegis_scout"] = scout_aegis()
    out["vanta_raider"] = raider_vanta()
    out["aegis_striker"] = striker_aegis()
    out["vanta_bruiser"] = bruiser_vanta()
    out["aegis_prism"] = prism_aegis()
    out["vanta_howitzer"] = howitzer_vanta()
    out["aegis_heavy"] = heavy_aegis()
    out["vanta_heavy"] = heavy_vanta()
    out["aegis_mender"] = mender_aegis()
    out["vanta_breacher"] = breacher_vanta()
    out["aegis_obelisk"] = obelisk("aegis")
    out["vanta_mortar"] = mortar("vanta")
    return out
