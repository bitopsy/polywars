#!/usr/bin/env python3
"""bricklib - a tiny LEGO-style model kit that writes Spring S3O files (pure stdlib).

Everything is designed in *stud space*: 1 unit = 1 stud pitch (8 mm on a real brick).
A plate is 0.4 studs tall, a brick is 3 plates = 1.2 studs. Each unit chooses how many
elmos a stud is worth (`Unit.S`).

    u = Unit("aegis_demo", "aegis", S=4)
    base = u.piece("base")                        # root piece, pivot at the origin
    base.brick(4, 6, 3, 0, 0, 0, "main")          # w, d (studs), height (plates), x, y (plates), z
    tur  = u.piece("turret", parent=base, pivot=(0, 1.2, 0))
    tur.cyl((0, 1.2, 0), (0, 2, 0), 0.8, col="accent")
    open("aegis_demo.s3o", "wb").write(u.s3o())

All geometry is given in absolute stud coordinates (relative to the unit origin); the piece
pivot only decides what the piece rotates around and where its local origin sits in the file.
Bricks get real studs (hidden automatically when another brick sits on top), bevelled edges
(that is what makes plastic look like plastic under a light), slopes, cylinders, cones,
tyres, crystals and a ready-made minifigure.
"""
import math
import struct

PLATE = 0.4              # plate height in studs
BRICK = 3 * PLATE        # brick height
STUD_R = 0.31            # stud radius (slightly exaggerated so studs read from RTS zoom)
STUD_H = 0.26            # stud height
STUD_SIDES = 8
BEVEL = 0.055            # default edge bevel in studs

# ------------------------------------------------------------------ palette / texture atlas
# 8 x 8 cells of 16 px = 128 x 128. Colour names are shared by both factions so unit
# definitions can be written once; each faction just maps the names to different plastic.
CELL = 16
GRID = 8
TEX = CELL * GRID


def _pal(**kw):
    return kw


# name: (rgb, team_mask 0..255, glow 0..255, specular 0..255)
def faction_palette(faction):
    if faction == "aegis":   # clean white / blue / cyan "sci-fi police" bricks
        c = dict(
            main=(238, 240, 242),     # hull white
            sub=(176, 184, 196),      # light bluish grey
            dark=(88, 96, 108),       # dark bluish grey
            black=(34, 38, 44),
            accent=(0, 108, 214),     # royal blue
            accent2=(10, 52, 128),    # dark blue
            glow=(120, 235, 255),     # trans light blue (emissive)
            glow2=(255, 255, 255),
            warn=(250, 200, 10),      # bright yellow
            skin=(250, 200, 10),
            metal=(200, 206, 216),
            lens=(70, 200, 255),
            red=(200, 30, 30),
            green=(40, 170, 90),
            steel=(120, 128, 140),
            tan=(215, 190, 140),
        )
    else:                    # Vanta: dark red / black / hazard orange, tougher looking
        c = dict(
            main=(174, 22, 22),       # hull red
            sub=(104, 14, 18),        # dark red
            dark=(62, 66, 72),        # dark grey
            black=(28, 28, 30),
            accent=(255, 130, 20),    # hazard orange
            accent2=(200, 90, 10),
            glow=(255, 150, 40),      # glowing orange
            glow2=(255, 230, 150),
            warn=(250, 200, 10),
            skin=(250, 200, 10),
            metal=(150, 154, 160),
            lens=(255, 90, 40),
            red=(214, 40, 30),
            green=(70, 140, 70),
            steel=(90, 96, 104),
            tan=(190, 160, 120),
            )
    pal = {}
    for k, rgb in c.items():
        glow = 255 if k in ("glow", "glow2", "lens") else 0
        spec = 215 if k in ("metal", "steel") else (60 if k in ("black", "dark") else 130)
        pal[k] = (rgb, 0, glow, spec)
    # team colour mask: alpha 255 -> the engine paints the player colour here
    pal["team"] = ((225, 225, 225), 255, 0, 150)
    pal["team2"] = ((40, 40, 40), 150, 0, 120)       # darker team tint (mix of dark grey and team)
    pal["white"] = ((246, 246, 246), 0, 0, 130)
    return pal


def palette_order(faction):
    return list(faction_palette(faction).keys())


_ORDER = {}


ALIAS = {"hull": "main", "hull2": "sub", "trim": "accent", "trim2": "accent2"}


def uv_of(faction, name):
    name = ALIAS.get(name, name)
    order = _ORDER.get(faction) or _ORDER.setdefault(faction, palette_order(faction))
    i = order.index(name)
    cx, cy = i % GRID, i // GRID
    return ((cx + 0.5) / GRID, (cy + 0.5) / GRID)


def texture_rows(faction):
    """returns (rows_tex1_rgba, rows_tex2_rgba) lists of bytes; 128 x 128 each."""
    pal = faction_palette(faction)
    order = list(pal.keys())
    rows1, rows2 = [], []
    for y in range(TEX):
        r1, r2 = bytearray(), bytearray()
        for x in range(TEX):
            i = (y // CELL) * GRID + (x // CELL)
            if i < len(order):
                rgb, team, glow, spec = pal[order[i]]
            else:
                rgb, team, glow, spec = (128, 128, 128), 0, 0, 100
            # tiny stud-like shading inside each cell (+/- 6%) so large flat areas are not dead flat
            lx, ly = x % CELL, y % CELL
            edge = min(lx, ly, CELL - 1 - lx, CELL - 1 - ly)
            k = 1.0 if edge > 1 else 0.96
            r1 += bytes((min(255, int(rgb[0] * k)), min(255, int(rgb[1] * k)), min(255, int(rgb[2] * k)), team))
            r2 += bytes((glow, spec, 0, 255))
        rows1.append(bytes(r1))
        rows2.append(bytes(r2))
    return rows1, rows2


# ------------------------------------------------------------------ vector helpers
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def mul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def length(a): return math.sqrt(dot(a, a))
def norm(a):
    l = length(a)
    return (a[0] / l, a[1] / l, a[2] / l) if l > 1e-12 else (0.0, 1.0, 0.0)


def rotate(p, rx=0.0, ry=0.0, rz=0.0):
    """rotate vector p by degrees about fixed X, then Y, then Z axes."""
    x, y, z = p
    if rx:
        c, s = math.cos(math.radians(rx)), math.sin(math.radians(rx))
        y, z = y * c - z * s, y * s + z * c
    if ry:
        c, s = math.cos(math.radians(ry)), math.sin(math.radians(ry))
        x, z = x * c + z * s, -x * s + z * c
    if rz:
        c, s = math.cos(math.radians(rz)), math.sin(math.radians(rz))
        x, y = x * c - y * s, x * s + y * c
    return (x, y, z)


class Quad:
    __slots__ = ("v", "n", "col", "dead")

    def __init__(self, v, n, col):
        self.v, self.n, self.col, self.dead = v, n, col, False


# ------------------------------------------------------------------ pieces
class Piece:
    def __init__(self, unit, name, parent, pivot):
        self.unit, self.name, self.parent, self.pivot = unit, name, parent, tuple(pivot)
        self.children = []
        self.quads = []
        self.bricks = []        # (x0, x1, z0, z1, ybottom, ytop) for stud hiding
        self.studs = []         # (x, z, ybase, [quads])
        self._rot = 0
        if parent:
            parent.children.append(self)

    # -- raw quad emission ------------------------------------------------
    def quad(self, p0, p1, p2, p3, col, n=None, ns=None):
        """add a quad. `n` = intended outward normal (flips the winding if needed);
        `ns` = optional 4 per-vertex normals (smooth shading)."""
        pts = [p0, p1, p2, p3]
        g = cross(sub(p1, p0), sub(p2, p1))
        if length(g) < 1e-9:
            g = cross(sub(p2, p0), sub(p3, p2))
        ref = n if n is not None else (ns[0] if ns else g)
        flip = dot(g, ref) < 0
        if flip:
            pts.reverse()
            if ns:
                ns = list(reversed(ns))
        gn = norm(g) if not flip else norm(mul(g, -1))
        if ns is None:
            ns = [norm(n) if n is not None else gn] * 4
        q = Quad(tuple(pts), tuple(ns), col)
        self.quads.append(q)
        return q

    def rotated(self, pivot=(0, 0, 0), rx=0.0, ry=0.0, rz=0.0):
        return _RotCtx(self, pivot, rx, ry, rz)

    # -- boxes / bricks ---------------------------------------------------
    def box(self, sx, sy, sz, cx, cy, cz, col, bevel=BEVEL):
        """axis-aligned bevelled box, size and centre in studs."""
        return self._box_abs(cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2, col, bevel)

    def _box_abs(self, x0, x1, y0, y1, z0, z1, col, bevel):
        c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        h = ((x1 - x0) / 2, (y1 - y0) / 2, (z1 - z0) / 2)
        b = min(bevel, min(h) * 0.9) if bevel else 0.0

        def P(v):
            return (c[0] + v[0], c[1] + v[1], c[2] + v[2])

        E = [(1, 0, 0), (0, 1, 0), (0, 0, 1)]
        out = []
        # faces
        for a in range(3):
            for s in (-1, 1):
                t1, t2 = [i for i in range(3) if i != a]
                pts = []
                for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    vec = [0, 0, 0]
                    vec[a] = s * h[a]
                    vec[t1] = u * (h[t1] - b)
                    vec[t2] = v * (h[t2] - b)
                    pts.append(P(vec))
                out.append(self.quad(*pts, col, n=mul(E[a], s)))
        if b > 0:
            # edges
            for a in range(3):
                for a2 in range(a + 1, 3):
                    e = 3 - a - a2
                    for s in (-1, 1):
                        for s2 in (-1, 1):
                            def pt(inset_a, inset_a2, ev):
                                vec = [0, 0, 0]
                                vec[a] = s * (h[a] - (b if inset_a else 0))
                                vec[a2] = s2 * (h[a2] - (b if inset_a2 else 0))
                                vec[e] = ev * (h[e] - b)
                                return P(vec)
                            n = norm(add(mul(E[a], s), mul(E[a2], s2)))
                            out.append(self.quad(pt(0, 1, -1), pt(0, 1, 1), pt(1, 0, 1), pt(1, 0, -1), col, n=n))
            # corners
            for s0 in (-1, 1):
                for s1 in (-1, 1):
                    for s2 in (-1, 1):
                        p_a = P((s0 * h[0], s1 * (h[1] - b), s2 * (h[2] - b)))
                        p_b = P((s0 * (h[0] - b), s1 * h[1], s2 * (h[2] - b)))
                        p_c = P((s0 * (h[0] - b), s1 * (h[1] - b), s2 * h[2]))
                        out.append(self.quad(p_a, p_b, p_c, p_c, col, n=norm((s0, s1, s2))))
        return out

    def brick(self, w, d, hp, x, yp, z, col, studs=True, bevel=BEVEL, stud_col=None):
        """a studded brick. w,d in studs, hp = height in plates, (x,z) centre in studs,
        yp = bottom height in PLATES."""
        y0, y1 = yp * PLATE, (yp + hp) * PLATE
        self._box_abs(x - w / 2, x + w / 2, y0, y1, z - d / 2, z + d / 2, col, bevel)
        if not self._rot:
            self._cover(x - w / 2, x + w / 2, z - d / 2, z + d / 2, y0, y1)
            self.bricks.append((x - w / 2, x + w / 2, z - d / 2, z + d / 2, y0, y1))
        if studs:
            nx, nz = int(round(w)), int(round(d))
            for i in range(nx):
                for j in range(nz):
                    sx = x - w / 2 + 0.5 + i * (w / nx)
                    sz = z - d / 2 + 0.5 * (d / nz) + j * (d / nz)
                    self.stud(sx, y1, sz, stud_col or col)

    def plate(self, w, d, x, yp, z, col, hp=1, **kw):
        self.brick(w, d, hp, x, yp, z, col, **kw)

    def tile(self, w, d, hp, x, yp, z, col, **kw):
        self.brick(w, d, hp, x, yp, z, col, studs=False, **kw)

    def stud(self, x, ybase, z, col, r=STUD_R, h=STUD_H):
        if not self._rot:
            for b in self.bricks:   # already covered by something sitting on top?
                if abs(b[4] - ybase) < 1e-4 and b[0] - 1e-4 <= x <= b[1] + 1e-4 and b[2] - 1e-4 <= z <= b[3] + 1e-4:
                    return
        qs = self.cyl((x, ybase, z), (x, ybase + h, z), r, col=col, sides=STUD_SIDES, bottom=False)
        if not self._rot:
            self.studs.append((x, z, ybase, qs))

    def _cover(self, x0, x1, z0, z1, ybot, ytop):
        for sx, sz, sy, qs in self.studs:
            if abs(sy - ybot) < 1e-4 and x0 - 1e-4 <= sx <= x1 + 1e-4 and z0 - 1e-4 <= sz <= z1 + 1e-4:
                for q in qs:
                    q.dead = True

    def round_brick(self, r, hp, x, yp, z, col, stud=True, sides=12, hollow_top=False):
        y0, y1 = yp * PLATE, (yp + hp) * PLATE
        self.cyl((x, y0, z), (x, y1, z), r, col=col, sides=sides, bevel_top=True)
        if stud:
            self.stud(x, y1, z, col)

    # -- slopes ----------------------------------------------------------------
    def slope(self, w, d, hp, x, yp, z, col, low=0, flat=1.0, facing="+z", studs=True, side_col=None):
        """sloped brick: full height `hp` plates at the back, `low` plates at the front, a flat
        top of `flat` studs at the back (studded), then the slope. facing = direction of the low end."""
        yaw = {"+z": 0, "+x": 90, "-z": 180, "-x": 270}[facing]
        y0, yH, yL = yp * PLATE, (yp + hp) * PLATE, (yp + low) * PLATE
        x0, x1, z0, z1 = x - w / 2, x + w / 2, z - d / 2, z + d / 2
        zf = min(z1, z0 + flat) if flat > 0 else z0
        sc = side_col or col
        with self.rotated((x, 0, z), ry=yaw):
            self.quad((x0, y0, z0), (x1, y0, z0), (x1, yH, z0), (x0, yH, z0), col, n=(0, 0, -1))
            if flat > 0:
                self.quad((x0, yH, z0), (x1, yH, z0), (x1, yH, zf), (x0, yH, zf), col, n=(0, 1, 0))
            sn = norm((0, (z1 - zf), (yH - yL)))
            self.quad((x0, yH, zf), (x1, yH, zf), (x1, yL, z1), (x0, yL, z1), col, n=sn)
            if yL > y0 + 1e-6:
                self.quad((x0, y0, z1), (x1, y0, z1), (x1, yL, z1), (x0, yL, z1), col, n=(0, 0, 1))
            for xs, nx in ((x0, -1), (x1, 1)):
                # side profile = rectangle under the flat part + trapezoid under the slope
                self.quad((xs, y0, z0), (xs, y0, zf), (xs, yH, zf), (xs, yH, z0), sc, n=(nx, 0, 0))
                self.quad((xs, y0, zf), (xs, y0, z1), (xs, yL, z1), (xs, yH, zf), sc, n=(nx, 0, 0))
            self.quad((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1), col, n=(0, -1, 0))
            if studs and flat > 0:
                nx = int(round(w))
                for i in range(nx):
                    sx = x0 + 0.5 * (w / nx) + i * (w / nx)
                    for j in range(int(flat + 1e-6)):
                        self.stud(sx, yH, z0 + 0.5 + j, col)

    def wedge(self, w, d, h, x, y, z, col, facing="+z"):
        """simple triangular-profile wedge (flat vehicle noses), h in studs"""
        self.slope(w, d, int(round(h / PLATE)), x, int(round(y / PLATE)), z, col, low=0, flat=0, facing=facing, studs=False)

    # -- cylinders / cones --------------------------------------------------------
    def cyl(self, p1, p2, r1, r2=None, col="main", sides=12, caps=True, bottom=True, bevel_top=False):
        """cylinder / cone frustum from p1 (radius r1) to p2 (radius r2)."""
        if r2 is None:
            r2 = r1
        ax = norm(sub(p2, p1))
        ref = (0, 1, 0) if abs(ax[1]) < 0.9 else (1, 0, 0)
        u = norm(cross(ax, ref))
        v = cross(ax, u)
        slope = (r1 - r2) / max(1e-9, length(sub(p2, p1)))

        def ring(c, r, k):
            a = 2 * math.pi * k / sides
            return add(c, add(mul(u, r * math.cos(a)), mul(v, r * math.sin(a))))

        out = []
        for k in range(sides):
            a0, a1 = 2 * math.pi * k / sides, 2 * math.pi * (k + 1) / sides
            n0 = norm(add(add(mul(u, math.cos(a0)), mul(v, math.sin(a0))), mul(ax, slope)))
            n1 = norm(add(add(mul(u, math.cos(a1)), mul(v, math.sin(a1))), mul(ax, slope)))
            nm = norm(add(n0, n1))
            out.append(self.quad(ring(p1, r1, k), ring(p1, r1, k + 1), ring(p2, r2, k + 1), ring(p2, r2, k), col,
                                 n=nm, ns=[n0, n1, n1, n0]))
        if caps:
            half = sides // 2
            for end, c, r, sgn in ((1, p2, r2, 1), (0, p1, r1, -1)):
                if end == 0 and not bottom:
                    continue
                if r < 1e-6:
                    continue
                for k in range(0, sides, 2):
                    out.append(self.quad(c, ring(c, r, k), ring(c, r, k + 1), ring(c, r, k + 2), col, n=mul(ax, sgn)))
        return out

    def rod(self, p1, p2, r, col="dark", sides=6):
        return self.cyl(p1, p2, r, col=col, sides=sides)

    def cone(self, p1, p2, r1, r2, col, sides=12):
        return self.cyl(p1, p2, r1, r2, col=col, sides=sides)

    def tire(self, r, width, cx, cy, cz, side=1, col="black", hub="sub", sides=12, hubr=0.55):
        """wheel with its axle along X: tyre + hub. side = which way the hub cap faces (+1 / -1)."""
        a = (cx - width / 2, cy, cz)
        b = (cx + width / 2, cy, cz)
        self.cyl(a, b, r, col=col, sides=sides)
        hx = cx + side * (width / 2 + 0.02)
        self.cyl((cx + side * width / 2 * 0.5, cy, cz), (hx + side * 0.06, cy, cz), r * hubr, col=hub, sides=sides)

    def crystal(self, cx, cy, cz, r, h, col, sides=6, top=None, bottom=None):
        """bipyramid gem (degenerate quads are fine for S3O)"""
        top = h if top is None else top
        bottom = h if bottom is None else bottom
        ring = [(cx + r * math.cos(2 * math.pi * k / sides), cy, cz + r * math.sin(2 * math.pi * k / sides))
                for k in range(sides)]
        tp, bp = (cx, cy + top, cz), (cx, cy - bottom, cz)
        for k in range(sides):
            a, b = ring[k], ring[(k + 1) % sides]
            m = norm(sub(mul(add(a, b), 0.5), (cx, cy, cz)))
            self.quad(a, b, tp, tp, col, n=norm(add(mul(m, top), (0, r, 0))))
            self.quad(a, b, bp, bp, col, n=norm(add(mul(m, bottom), (0, -r, 0))))

    def dome(self, cx, cy, cz, r, col, sides=10, rings=3, squash=1.0):
        pts = []
        for i in range(rings + 1):
            el = (math.pi / 2) * i / rings
            pts.append([(cx + r * math.cos(el) * math.cos(2 * math.pi * k / sides),
                         cy + r * math.sin(el) * squash,
                         cz + r * math.cos(el) * math.sin(2 * math.pi * k / sides)) for k in range(sides)])
        for i in range(rings):
            for k in range(sides):
                k2 = (k + 1) % sides
                p0, p1, p2, p3 = pts[i][k], pts[i][k2], pts[i + 1][k2], pts[i + 1][k]
                nn = [norm(sub(p, (cx, cy, cz))) for p in (p0, p1, p2, p3)]
                self.quad(p0, p1, p2, p3, col, n=norm(add(nn[0], nn[2])), ns=nn)

    # -- finishing ------------------------------------------------------------------
    def alive(self):
        return [q for q in self.quads if not q.dead]


class _RotCtx:
    def __init__(self, piece, pivot, rx, ry, rz):
        self.p, self.pivot, self.r = piece, pivot, (rx, ry, rz)

    def __enter__(self):
        self.start = len(self.p.quads)
        self.p._rot += 1
        return self

    def __exit__(self, *a):
        self.p._rot -= 1
        pv = self.pivot
        rx, ry, rz = self.r
        for q in self.p.quads[self.start:]:
            q.v = tuple(add(rotate(sub(v, pv), rx, ry, rz), pv) for v in q.v)
            q.n = tuple(norm(rotate(n, rx, ry, rz)) for n in q.n)


# ------------------------------------------------------------------ unit / S3O
class Unit:
    def __init__(self, name, faction, S=4.0):
        self.name, self.faction, self.S = name, faction, S
        self.pieces = []
        self.root = None

    def piece(self, name, parent=None, pivot=(0, 0, 0)):
        if parent is None and self.root is not None:
            parent = self.root
        p = Piece(self, name, parent, pivot)
        if self.root is None:
            self.root = p
        self.pieces.append(p)
        return p

    # world (rest pose) position of a vertex in studs: stored absolute already.
    def all_vertices(self):
        for p in self.pieces:
            for q in p.alive():
                for v in q.v:
                    yield v

    def s3o(self, tex1=None, tex2=None):
        S = self.S
        tex1 = tex1 or (self.faction + "_tex1.png")
        tex2 = tex2 or (self.faction + "_tex2.png")
        verts_all = [tuple(c * S for c in v) for v in self.all_vertices()]
        ymax = max(v[1] for v in verts_all)
        ymin = min(v[1] for v in verts_all)
        mid = ((max(v[0] for v in verts_all) + min(v[0] for v in verts_all)) / 2, (ymax + ymin) / 2,
               (max(v[2] for v in verts_all) + min(v[2] for v in verts_all)) / 2)
        radius = max(math.sqrt((v[0] - mid[0]) ** 2 + (v[1] - mid[1]) ** 2 + (v[2] - mid[2]) ** 2) for v in verts_all)

        # --- layout: header | pieces (depth first) | strings | vertex/index blocks
        order = []

        def walk(p):
            order.append(p)
            for c in p.children:
                walk(c)
        walk(self.root)
        header_size, piece_size = 52, 52
        off = header_size
        piece_off = {}
        for p in order:
            piece_off[p] = off
            off += piece_size
        # child tables
        child_tab = {}
        for p in order:
            if p.children:
                child_tab[p] = off
                off += 4 * len(p.children)
        names_off = {}
        for p in order:
            names_off[p] = off
            off += len(p.name.encode()) + 1
        t1 = tex1.encode() + b"\0"
        t2 = tex2.encode() + b"\0"
        off_t1 = off
        off += len(t1)
        off_t2 = off
        off += len(t2)
        off = (off + 3) & ~3
        blocks = {}
        for p in order:
            qs = p.alive()
            vlist = []
            for q in qs:
                for v, n in zip(q.v, q.n):
                    u, w = uv_of(self.faction, q.col)
                    loc = tuple((v[i] - p.pivot[i]) * S for i in range(3))
                    vlist.append(loc + tuple(n) + (u, w))
            blocks[p] = (off, vlist)
            off += 32 * len(vlist)
            blocks[p] += (off,)
            off += 4 * len(vlist)

        out = bytearray()
        out += b"Spring unit\0"
        out += struct.pack("<I", 0)
        out += struct.pack("<fffff", radius, ymax, mid[0], mid[1], mid[2])
        out += struct.pack("<IIII", piece_off[self.root], 0, off_t1, off_t2)
        assert len(out) == header_size
        for p in order:
            voff, vlist, ioff = blocks[p]
            rel = (0.0, 0.0, 0.0) if p.parent is None else tuple((p.pivot[i] - p.parent.pivot[i]) * S for i in range(3))
            if p.parent is None:
                rel = tuple(p.pivot[i] * S for i in range(3))
            out += struct.pack("<10I", names_off[p], len(p.children), child_tab.get(p, 0), len(vlist),
                               voff if vlist else 0, 0, 2, len(vlist), ioff if vlist else 0, 0)
            out += struct.pack("<fff", *rel)
        for p in order:
            if p in child_tab:
                assert len(out) == child_tab[p], (len(out), child_tab[p])
                for c in p.children:
                    out += struct.pack("<I", piece_off[c])
        for p in order:
            assert len(out) == names_off[p]
            out += p.name.encode() + b"\0"
        out += t1 + t2
        out += b"\0" * (blocks[order[0]][0] - len(out))
        for p in order:
            voff, vlist, ioff = blocks[p]
            assert len(out) == voff, (p.name, len(out), voff)
            for v in vlist:
                out += struct.pack("<8f", *v)
            out += struct.pack("<%dI" % len(vlist), *range(len(vlist)))
        return bytes(out)


# ------------------------------------------------------------------ S3O reader (for validation + previews)
def read_s3o(data):
    """returns dict(name -> piece dict(offset, children, verts[list of 8-tuples], parent)) + header info"""
    assert data[:12] == b"Spring unit\0", "bad magic"
    ver, radius, height, mx, my, mz, root, coll, o1, o2 = struct.unpack_from("<IfffffIIII", data, 12)
    assert ver == 0

    def cstr(o):
        e = data.index(b"\0", o)
        return data[o:e].decode()

    pieces = {}

    def piece(o, parent):
        (name_o, nchild, child_o, nv, v_o, vtype, ptype, tsize, t_o, cd) = struct.unpack_from("<10I", data, o)
        ox, oy, oz = struct.unpack_from("<fff", data, o + 40)
        name = cstr(name_o)
        verts = [struct.unpack_from("<8f", data, v_o + 32 * i) for i in range(nv)]
        idx = list(struct.unpack_from("<%dI" % tsize, data, t_o)) if tsize else []
        assert ptype == 2 and all(0 <= i < nv for i in idx)
        assert tsize % 4 == 0
        d = dict(name=name, offset=(ox, oy, oz), verts=verts, index=idx, parent=parent, children=[])
        pieces[name] = d
        for i in range(nchild):
            co = struct.unpack_from("<I", data, child_o + 4 * i)[0]
            d["children"].append(piece(co, name))
        return name
    r = piece(root, None)
    return dict(radius=radius, height=height, mid=(mx, my, mz), tex1=cstr(o1), tex2=cstr(o2), root=r, pieces=pieces)
