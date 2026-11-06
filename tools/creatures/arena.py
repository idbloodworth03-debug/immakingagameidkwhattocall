"""Renders the battle arenas: an open field the herds fight on, with a
fence around it and scenery outside, one picture per arena, in the same 3D
cartoon style as the animals.

    python arena.py [--only whispering_woods] [--ppt 56] [--samples 32]

Writes game/art/arenas/<arena>.webp and arenas.json (what part of the
field each picture covers).

The game draws the field flat, one square per tile, while the animals are
rendered from a camera 50 degrees up. The arena uses that same camera, with
the ground stretched away from it (by 1 / sin 50) so the tiles still come
out square. Trees, rocks and the fence are seen from the same angle as the
animals, and every tile lands exactly where the game puts it.

The ground's colors (grass, tile stripes, the worn middle line and ring,
flowers) are painted into a texture with numpy; Blender adds the fence and
scenery, and the light and shadows.
"""
import argparse
import json
import math
import os
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image
from scipy import ndimage

import scene as S
from sdf import cone, ellipsoid
from sprites import ELEVATION
from treehouse import _mat, _shade, box, cylinder, organic, roof

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "game", "art", "arenas")
SIN = math.sin(math.radians(ELEVATION))

# The field, in tiles (as in battle_sim.gd): 16 wide, 20 long, y = 0 at the
# far end.
FIELD_W, FIELD_H = 16.0, 20.0
# The picture covers these tiles: wide margins all around (phones show more
# or less of them).
X0, X1 = -6.0, 22.0
T0, T1 = -4.5, 24.0
# The ground mesh and its color texture reach a bit past the picture.
GX0, GX1, GT0, GT1 = X0 - 2.0, X1 + 2.0, T0 - 4.0, T1 + 2.0
TEX_PPT = 32
# Life round the arenas (data/arena_life.json): its set pieces are built
# into the picture here, and a strip behind the far fence is kept clear for
# the crowd that watches from there.
LIFE = json.load(open(os.path.join(ROOT, "game", "data", "arena_life.json")))
CROWD_STRIP = (-0.6, 16.6, -1.7, -0.3)
# Set-piece names that are an existing kind of scenery at a size.
ALIASES = {"snowbank": ("snow_mound", 1.0), "snow_hill": ("snow_mound", 2.6), "ice_block": ("ice_rock", 1.0),
           "ice_post": ("ice_rock", 0.6)}


def wy(t):
    """World y of field row t (tiles): the far end is away from the camera."""
    return (FIELD_H / 2 - t) / SIN


def hexa(h):
    """Hex color to sRGB 0-1 (for painting textures, which are sRGB)."""
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


# --- Themes ------------------------------------------------------------------------------

# grass: light and dark ground colors; edge: the ground outside the fence;
# path: worn ground (the middle line and ring); props: scenery kinds and how
# often they show up; flowers: colors dotted in the grass.
THEMES = {
    "rescue_center": dict(grass=("#78b84f", "#5c9a3c"), edge="#4f8a35", path="#c9a46a", bank="#a88a5a",
                          water=("#3f9fd8", "#6fc4ee"), fence="#b07a45",
                          props={"round_tree": 3, "bush": 4, "rock": 2, "crate": 1, "flower_bed": 2},
                          flowers=["#ffffff", "#ffd84a", "#ff8fb0"]),
    "city_park": dict(grass=("#7cc055", "#5ea040"), edge="#56923a", path="#d9c9a8", bank="#a59070",
                      water=("#3d9ad6", "#72c6f0"), fence="#8a8f99",
                      props={"round_tree": 5, "bush": 4, "lamp": 1, "flower_bed": 3, "rock": 1},
                      flowers=["#ff6b6b", "#ffd84a", "#ffffff", "#c58bff"]),
    "prairie_fields": dict(grass=("#c8c060", "#a8a044"), edge="#a39a40", path="#d8b878", bank="#b09060",
                           water=("#4aa0cc", "#7ac8e8"), fence="#a8763e",
                           props={"hay": 3, "tall_grass": 5, "round_tree": 1, "rock": 1, "bush": 2},
                           flowers=["#ffe25a", "#ffffff", "#ff9d4a"]),
    "whispering_woods": dict(grass=("#4f9a48", "#3a7a38"), edge="#2f6430", path="#9c7a50", bank="#7a6040",
                             water=("#2f7fb8", "#5aaedc"), fence="#7a5230",
                             props={"pine": 6, "log": 2, "mushroom": 2, "bush": 3, "rock": 2},
                             flowers=["#ffffff", "#c8e86a"]),
    "misty_marsh": dict(grass=("#5e9a72", "#477e5c"), edge="#3c6e52", path="#8a8058", bank="#6a6448",
                        water=("#3a8a8a", "#64b4ae"), fence="#6e5a3e",
                        props={"reeds": 6, "willow": 3, "rock": 2, "log": 1, "bush": 2},
                        flowers=["#e8f0a0", "#ffffff"]),
    "sunbaked_savanna": dict(grass=("#d8bc5c", "#bc9e42"), edge="#b09040", path="#d8a868", bank="#b88a50",
                             water=("#3f9cc8", "#72c2e2"), fence="#9a6838",
                             props={"acacia": 4, "tall_grass": 4, "rock": 3, "bush": 2},
                             flowers=["#ffffff", "#ff9d4a"]),
    "red_rock_canyon": dict(grass=("#d88e5a", "#bc7044"), edge="#a8603a", path="#e8b07a", bank="#b87048",
                            water=("#3a9ac4", "#6cc0e0"), fence="#8a5a34",
                            props={"cactus": 4, "red_rock": 5, "bush": 1}, bank_props=["red_rock"],
                            flowers=["#ffd84a", "#ff6b9a"]),
    "frozen_tundra": dict(grass=("#e2f0f9", "#bdd6e8"), edge="#a6c2d8", path="#8eb0cc", bank="#8aa8c0",
                          water=("#5aa8d8", "#a8dcf4"), fence="#8a6a4a",
                          props={"snow_pine": 6, "ice_rock": 3, "snow_mound": 3}, bank_props=["ice_rock", "snow_mound"],
                          flowers=["#ffffff", "#bfe4ff"]),
    "emerald_jungle": dict(grass=("#3fae5a", "#2a8a44"), edge="#227a3a", path="#a88a58", bank="#7e6a44",
                           water=("#2a9aa8", "#5ccad0"), fence="#7a5a30",
                           props={"palm": 4, "big_leaf": 4, "round_tree": 2, "flower_bed": 2, "rock": 1},
                           flowers=["#ff5ab0", "#ffd84a", "#ff8a3a"]),
    "cloudpeak_mountains": dict(grass=("#8fae78", "#6e8e5c"), edge="#66805a", path="#b8b0a0", bank="#8e8676",
                                water=("#4a98d0", "#86c8ee"), fence="#7a6048",
                                props={"boulder": 5, "pine": 3, "snow_mound": 1, "rock": 2},
                                flowers=["#ffffff", "#c8b8ff"]),
    "coral_coast": dict(grass=("#86c86a", "#68aa50"), edge="#e8d49a", path="#f0dca8", bank="#e8d29a",
                        water=("#25b0c8", "#78e0e8"), fence="#c0a070",
                        props={"palm": 5, "shell_rock": 3, "bush": 2}, bank_props=["shell_rock"],
                        flowers=["#ffffff", "#ff8a8a", "#ffd84a"]),
    "last_sanctuary": dict(grass=("#86c45a", "#64a044"), edge="#4f8a3a", path="#e0c88a", bank="#b0985c",
                           water=("#3aa4dc", "#7cd0f4"), fence="#c8a040",
                           props={"round_tree": 3, "pine": 2, "flower_bed": 4, "bush": 2, "lamp": 1},
                           flowers=["#ffd84a", "#ffffff", "#ff8fb0", "#9fd8ff"]),
}
TALL = {"round_tree", "pine", "snow_pine", "palm", "acacia", "willow", "cactus", "lamp", "big_leaf"}


# --- The ground texture -------------------------------------------------------------------

def _noise(shape, cells, rng, octaves=3):
    """Smooth random values (about -1 to 1) at the texture's resolution."""
    total = np.zeros(shape)
    amp = 1.0
    for o in range(octaves):
        n = (int(shape[0] / cells) + 2, int(shape[1] / cells) + 2)
        grid = rng.uniform(-1, 1, n)
        up = ndimage.zoom(grid, (shape[0] / (n[0] - 1), shape[1] / (n[1] - 1)), order=3)[:shape[0], :shape[1]]
        total += up * amp
        amp *= 0.5
        cells = max(2, cells / 2.2)
    return total / 1.6


def _smooth(x, edge, width):
    t = np.clip((x - edge) / width, 0, 1)
    return t * t * (3 - 2 * t)


def _segment(x, t, a, b):
    """Distance from every point to the line from a to b."""
    ax, at = a
    dx, dt = b[0] - ax, b[1] - at
    k = np.clip(((x - ax) * dx + (t - at) * dt) / (dx * dx + dt * dt), 0, 1)
    return np.hypot(x - ax - k * dx, t - at - k * dt)


def paint_ground(theme, rng):
    """The ground's colors (sRGB, H x W x 3) over [GX0, GX1] x [GT0, GT1]."""
    w = int((GX1 - GX0) * TEX_PPT)
    h = int((GT1 - GT0) * TEX_PPT)
    xs = GX0 + (np.arange(w) + 0.5) / TEX_PPT
    ts = GT0 + (np.arange(h) + 0.5) / TEX_PPT
    x, t = np.meshgrid(xs, ts)
    light, dark = hexa(theme["grass"][0]), hexa(theme["grass"][1])
    n1 = _noise((h, w), TEX_PPT * 3, rng)
    n2 = _noise((h, w), TEX_PPT * 0.7, rng)
    mix = np.clip(0.5 + 0.45 * n1 + 0.2 * n2, 0, 1)[..., None]
    img = dark * (1 - mix) + light * mix

    inside = (x >= 0) & (x <= FIELD_W) & (t >= 0) & (t <= FIELD_H)
    # Faint tile stripes on the field, like a mown pitch, so tiles read.
    checker = ((np.floor(x) + np.floor(t)) % 2 == 0) & inside
    img = np.where(checker[..., None], img * 1.035, img * 0.985)
    # Outside the fence: the edge color, rougher.
    edge = hexa(theme["edge"])
    out_mix = (~inside)[..., None] * (0.55 + 0.25 * np.clip(n2, -1, 1)[..., None])
    img = img * (1 - out_mix) + edge * out_mix

    # Worn grass across the middle and in a ring around the center spot, so
    # each side's half is easy to see.
    n3 = _noise((h, w), TEX_PPT * 0.9, rng) * 0.22
    line = np.abs(t - FIELD_H / 2) < 0.12 + n3 * 0.25
    ring = np.abs(np.hypot(x - FIELD_W / 2, t - FIELD_H / 2) - 2.2) < 0.13 + n3 * 0.25
    marks = ndimage.gaussian_filter(((line | ring) & inside).astype(float), TEX_PPT * 0.05)
    path_col = hexa(theme["path"]) * (1 + 0.08 * n2[..., None])
    img = img * (1 - marks[..., None] * 0.6) + path_col * marks[..., None] * 0.6

    # Flowers and little tufts: sparse on the field, thicker outside.
    colors = [hexa(c) for c in theme["flowers"]]
    count = int((GX1 - GX0) * (GT1 - GT0) * 1.6)
    fx = rng.uniform(GX0, GX1, count)
    ft = rng.uniform(GT0, GT1, count)
    for i in range(count):
        ins = 0 <= fx[i] <= FIELD_W and 0 <= ft[i] <= FIELD_H
        if ins and rng.random() > 0.35:
            continue
        cx, cy = int((fx[i] - GX0) * TEX_PPT), int((ft[i] - GT0) * TEX_PPT)
        r = max(1, int(TEX_PPT * rng.uniform(0.04, 0.07)))
        col = colors[rng.integers(len(colors))] if rng.random() < 0.6 else light * 1.12
        for k in range(rng.integers(2, 5)):
            ox, oy = cx + rng.integers(-5, 6), cy + rng.integers(-5, 6)
            y0, y1, x0, x1 = max(oy - r, 0), min(oy + r + 1, h), max(ox - r, 0), min(ox + r + 1, w)
            yy, xx = np.ogrid[y0:y1, x0:x1]
            dot = (yy - oy) ** 2 + (xx - ox) ** 2 <= r * r
            img[y0:y1, x0:x1][dot] = col
    return np.clip(img, 0, 1)


def _image(name, pixels):
    path = os.path.join(tempfile.gettempdir(), f"_{name}.png")
    Image.fromarray((pixels * 255).astype(np.uint8)).save(path)
    return bpy.data.images.load(path)


def _textured(name, image, roughness=0.85, specular=0.25):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    bsdf = nodes["Principled BSDF"]
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = specular
    return mat


def _grid(name, x_range, t_range, per_tile, height_fn):
    """A ground mesh over the given tiles, raised or lowered by height_fn(x, t),
    UV-mapped onto the ground texture."""
    nx = int((x_range[1] - x_range[0]) * per_tile) + 1
    nt = int((t_range[1] - t_range[0]) * per_tile) + 1
    xs = np.linspace(x_range[0], x_range[1], nx)
    ts = np.linspace(t_range[0], t_range[1], nt)
    x, t = np.meshgrid(xs, ts)
    z = height_fn(x, t)
    verts = np.stack([x.ravel(), wy(t).ravel(), z.ravel()], axis=1)
    idx = np.arange(nx * nt).reshape(nt, nx)
    faces = np.stack([idx[:-1, :-1], idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:]], axis=-1).reshape(-1, 4)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.update()
    uv = me.uv_layers.new()
    u = (x.ravel() - x_range[0]) / (x_range[1] - x_range[0])
    v = (t_range[1] - t.ravel()) / (t_range[1] - t_range[0])
    loop_v = np.zeros(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", loop_v)
    uv.data.foreach_set("uv", np.stack([u[loop_v], v[loop_v]], axis=1).ravel())
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --- Scenery -----------------------------------------------------------------------------

def _place(objs, x, t, scale=1.0, turn=0.0, z=0.0):
    for o in objs:
        o.location = (x, wy(t), z)
        o.scale = (scale, scale, scale)
        o.rotation_euler = (0, 0, turn)


class Library:
    """Builds each kind of scenery once (a few variants), then hands out
    copies that share the meshes."""

    def __init__(self, theme, rng):
        self.theme = theme
        self.rng = rng
        self.made = {}
        self.hidden = bpy.data.collections.new("library")
        bpy.context.scene.collection.children.link(self.hidden)

    def copy(self, kind):
        variants = self.made.get(kind)
        if variants is None:
            variants = [self._build(kind, seed) for seed in range(3)]
            self.made[kind] = variants
        group = variants[self.rng.integers(len(variants))]
        copies = []
        for o in group:
            c = o.copy()
            bpy.context.scene.collection.objects.link(c)
            copies.append(c)
        return copies

    def _build(self, kind, seed):
        before = set(bpy.data.objects)
        getattr(self, kind)(np.random.default_rng(seed + zlib.crc32(kind.encode()) % 1000))
        made = [o for o in bpy.data.objects if o not in before]
        for o in made:
            # Bake where it stands into the mesh, so copies can be moved freely.
            o.data.transform(o.matrix_world)
            o.matrix_world = o.matrix_world.Identity(4)
            for col in o.users_collection:
                col.objects.unlink(o)
            self.hidden.objects.link(o)
        return made

    # Each builder makes one piece of scenery standing at the origin, in tiles.

    def round_tree(self, rng, leaf=("#7fca52", "#3c8a32")):
        h = rng.uniform(1.4, 1.9)
        organic("trunk", [cone((0, 0, 0), (0, 0, h * 0.6), 0.16, 0.11, "bark", "t", blend=0.04)],
                lambda m: _shade(m, "#8a5a33", "#5c3a20"))[0].data.materials.append(self._vc("bark", 0.8))
        blobs = [ellipsoid((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), h * rng.uniform(0.75, 1.0)),
                           (r, r, r * 0.85), "leaf", "t", blend=0.12)
                 for r in rng.uniform(0.45, 0.65, 5)]
        organic("crown", blobs, lambda m: _shade(m, leaf[0], leaf[1], low=-0.5, high=0.8), voxel=0.04)[0] \
            .data.materials.append(self._vc("leaf", 0.75))

    def willow(self, rng):
        self.round_tree(rng, leaf=("#86b86a", "#3f6e44"))

    def pine(self, rng, snow=False):
        h = rng.uniform(1.6, 2.3)
        organic("trunk", [cone((0, 0, 0), (0, 0, h * 0.35), 0.12, 0.09, "bark", "t", blend=0.03)],
                lambda m: _shade(m, "#7a4f2e", "#4e321c"))[0].data.materials.append(self._vc("bark", 0.8))
        tiers = [cone((0, 0, h * (0.2 + 0.24 * i)), (0, 0, h * (0.62 + 0.2 * i)), 0.62 - 0.15 * i, 0.03, "leaf", "t",
                      blend=0.06) for i in range(3)]
        top, low = ("#ffffff", "#3c7a4a") if snow else ("#4fa05a", "#22553a")
        paint = (lambda m: _shade(m, top, low, low=0.1, high=0.75)) if snow else \
            (lambda m: _shade(m, top, low, low=-0.4, high=0.8))
        organic("needles", tiers, paint, voxel=0.035)[0].data.materials.append(self._vc("needles", 0.8))

    def snow_pine(self, rng):
        self.pine(rng, snow=True)

    def palm(self, rng):
        lean = rng.uniform(-0.35, 0.35)
        h = rng.uniform(1.7, 2.2)
        organic("trunk", [cone((0, 0, 0), (lean * 0.5, 0, h * 0.5), 0.13, 0.11, "bark", "t", blend=0.04),
                          cone((lean * 0.5, 0, h * 0.5), (lean, 0, h), 0.11, 0.08, "bark", "t", blend=0.04)],
                lambda m: _shade(m, "#b08a5a", "#6e5434"))[0].data.materials.append(self._vc("bark", 0.8))
        fronds = []
        for i in range(7):
            a = i / 7 * math.tau + rng.uniform(-0.2, 0.2)
            c = (lean + math.cos(a) * 0.55, math.sin(a) * 0.55, h - 0.12)
            fronds.append(ellipsoid(c, (0.62, 0.2, 0.07), "leaf", "t", blend=0.05, yaw=a))
        organic("fronds", fronds, lambda m: _shade(m, "#7ed25a", "#2f8a3a", low=-0.6, high=0.9), voxel=0.03)[0] \
            .data.materials.append(self._vc("frond", 0.7))

    def big_leaf(self, rng):
        leaves = []
        for i in range(5):
            a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
            leaves.append(ellipsoid((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.35), (0.48, 0.2, 0.06), "leaf", "t",
                                    blend=0.05, yaw=a))
        organic("leaves", leaves, lambda m: _shade(m, "#5ad06a", "#1f7a3a", low=-0.6, high=0.9), voxel=0.03)[0] \
            .data.materials.append(self._vc("bigleaf", 0.6))

    def acacia(self, rng):
        h = rng.uniform(1.4, 1.8)
        organic("trunk", [cone((0, 0, 0), (0.1, 0, h * 0.7), 0.12, 0.08, "bark", "t", blend=0.03),
                          cone((0.1, 0, h * 0.6), (0.5, 0.1, h), 0.07, 0.04, "bark", "t", blend=0.03),
                          cone((0.1, 0, h * 0.6), (-0.4, -0.1, h), 0.07, 0.04, "bark", "t", blend=0.03)],
                lambda m: _shade(m, "#8a6040", "#5a3e24"))[0].data.materials.append(self._vc("bark", 0.8))
        organic("crown", [ellipsoid((0.05, 0, h + 0.05), (1.0, 0.8, 0.22), "leaf", "t", blend=0.1)],
                lambda m: _shade(m, "#9cc04a", "#5a7a2a", low=-0.6, high=0.8), voxel=0.04)[0] \
            .data.materials.append(self._vc("acacia", 0.75))

    def cactus(self, rng):
        h = rng.uniform(1.0, 1.5)
        parts = [cone((0, 0, 0), (0, 0, h), 0.17, 0.15, "cactus", "t", blend=0.03)]
        for side in (1, -1):
            if rng.random() < 0.8:
                z = h * rng.uniform(0.35, 0.55)
                parts.append(cone((0, 0, z), (side * 0.35, 0, z + 0.05), 0.09, 0.09, "cactus", "t", blend=0.05))
                parts.append(cone((side * 0.35, 0, z), (side * 0.35, 0, z + h * 0.35), 0.09, 0.08, "cactus", "t",
                                  blend=0.05))
        organic("cactus", parts, lambda m: _shade(m, "#7cc062", "#3e7a3a"), voxel=0.03)[0] \
            .data.materials.append(self._vc("cactus", 0.6))

    def bush(self, rng):
        blobs = [ellipsoid((rng.uniform(-0.25, 0.25), rng.uniform(-0.2, 0.2), 0.2), (r, r, r * 0.8), "leaf", "t",
                           blend=0.1) for r in rng.uniform(0.25, 0.4, 4)]
        top, low = self.theme.get("bush", ("#6cc04a", "#2f7a2a"))
        organic("bush", blobs, lambda m: _shade(m, top, low, low=-0.5, high=0.8), voxel=0.035)[0] \
            .data.materials.append(self._vc("bush", 0.75))

    def _rock_shape(self, rng, size, top, low, name):
        blobs = [ellipsoid((rng.uniform(-0.15, 0.15) * size, rng.uniform(-0.15, 0.15) * size, 0.05),
                           tuple(np.array([r, r * rng.uniform(0.7, 1.0), r * rng.uniform(0.5, 0.75)]) * size),
                           "rock", "t", blend=0.06) for r in rng.uniform(0.25, 0.4, 3)]
        organic(name, blobs, lambda m: _shade(m, top, low), voxel=0.03)[0].data.materials.append(self._vc(name, 0.85))

    def rock(self, rng):
        self._rock_shape(rng, 1.0, "#b8b8b0", "#6e6e6a", "rock")

    def boulder(self, rng):
        self._rock_shape(rng, 1.8, "#a8acb4", "#5e6270", "boulder")

    def red_rock(self, rng):
        self._rock_shape(rng, rng.uniform(1.3, 2.2), "#e08a5a", "#8a4a30", "redrock")

    def ice_rock(self, rng):
        self._rock_shape(rng, 1.3, "#e8f6ff", "#8ab8d8", "ice")

    def shell_rock(self, rng):
        self._rock_shape(rng, 0.9, "#f4e8d8", "#b8a080", "shell")

    def snow_mound(self, rng):
        organic("snow", [ellipsoid((0, 0, 0), (0.6, 0.5, 0.25), "snow", "t", blend=0.1)],
                lambda m: _shade(m, "#ffffff", "#b8d4ea"), voxel=0.04)[0].data.materials.append(self._vc("snow", 0.6))

    def tall_grass(self, rng):
        blades = []
        for i in range(9):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0, 0.25)
            base = (math.cos(a) * r, math.sin(a) * r, 0)
            tip = (base[0] + rng.uniform(-0.15, 0.15), base[1] + rng.uniform(-0.15, 0.15), rng.uniform(0.35, 0.6))
            blades.append(cone(base, tip, 0.05, 0.01, "grass", "t", blend=0.02))
        top, low = self.theme.get("blades", ("#d8d070", "#8a8a3a"))
        organic("grass", blades, lambda m: _shade(m, top, low), voxel=0.02)[0].data.materials.append(self._vc("grass", 0.8))

    def reeds(self, rng):
        parts = []
        for i in range(7):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0, 0.25)
            base = (math.cos(a) * r, math.sin(a) * r, 0)
            h = rng.uniform(0.6, 0.95)
            parts.append(cone(base, (base[0], base[1], h), 0.035, 0.02, "stem", "t", blend=0.01))
            if rng.random() < 0.6:
                parts.append(ellipsoid((base[0], base[1], h - 0.1), (0.05, 0.05, 0.12), "tail", "t", blend=0.01))
        organic("reeds", parts, lambda m: np.where((m.verts[:, 2] > 0.5)[:, None] & (np.abs(m.normals[:, 2]) < 0.9)[:, None],
                                                 S.hex_color("#7a5030"), S.hex_color("#6aa04a")),
                voxel=0.018)[0].data.materials.append(self._vc("reeds", 0.8))

    def log(self, rng):
        organic("log", [cone((-0.5, 0, 0.12), (0.5, 0, 0.12), 0.14, 0.13, "bark", "t", blend=0.02)],
                lambda m: _shade(m, "#9a6a40", "#5a3a20"), voxel=0.025)[0].data.materials.append(self._vc("log", 0.85))

    def mushroom(self, rng):
        organic("stem", [cone((0, 0, 0), (0, 0, 0.25), 0.06, 0.05, "stem", "t", blend=0.02)],
                lambda m: _shade(m, "#f4ead8", "#c8b89a"), voxel=0.02)[0].data.materials.append(self._vc("stem", 0.7))
        organic("cap", [ellipsoid((0, 0, 0.27), (0.17, 0.17, 0.09), "cap", "t", blend=0.02)],
                lambda m: _shade(m, "#ff5a4a", "#a82a2a"), voxel=0.02)[0].data.materials.append(self._vc("cap", 0.5))

    def hay(self, rng):
        cylinder((0, 0, 0.28), 0.28, 0.6, _mat("hay", "#e8c860", roughness=0.9, bands=("X", 14), seam=0.8),
                 rot=(0, math.pi / 2, 0), vertices=20)

    def crate(self, rng):
        box((0, 0, 0.2), (0.4, 0.4, 0.4), _mat("crate", "#c08a50", roughness=0.8, bands=("Z", 9), seam=0.6),
            bevel=0.03, rot_z=rng.uniform(0, 1))

    def flower_bed(self, rng):
        top, low = ("#6cc04a", "#2f7a2a")
        organic("bed", [ellipsoid((0, 0, 0.05), (0.55, 0.4, 0.15), "leaf", "t", blend=0.05)],
                lambda m: _shade(m, top, low), voxel=0.035)[0].data.materials.append(self._vc("bed", 0.8))
        colors = self.theme["flowers"]
        for i in range(9):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0, 0.4)
            c = colors[i % len(colors)]
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(math.cos(a) * r, math.sin(a) * r * 0.7, 0.18),
                                                 segments=10, ring_count=6)
            bpy.context.object.data.materials.append(_mat(f"petal{i}", c, roughness=0.5))

    # Set pieces (arena_life.json "pieces"): the front faces the field (-Y).

    def ranger_station(self, rng):
        wall = _mat("cabin", "#a8743f", roughness=0.85, bands=("Z", 9), seam=0.62)
        box((0, 0, 0.55), (2.1, 1.4, 1.1), wall, bevel=0.04)
        roof((0, 0, 1.1), 2.5, 1.8, 0.75, _mat("roof", "#3f8a4a", roughness=0.7, bands=("Z", 7), seam=0.7))
        trim = _mat("trim", "#f2e6c8", roughness=0.6)
        box((-0.45, -0.71, 0.42), (0.42, 0.04, 0.78), _mat("door", "#6b4424", roughness=0.7, bands=("X", 10), seam=0.7))
        for x in (0.35, 0.8):
            box((x, -0.71, 0.66), (0.34, 0.04, 0.3), _mat("window", "#9fdcff", roughness=0.2, emission=0.3))
            box((x, -0.73, 0.66), (0.4, 0.02, 0.06), trim)
        # A porch and a sign over the door.
        box((0, -0.95, 0.05), (2.3, 0.5, 0.1), _mat("porch", "#8a5a33", roughness=0.85, bands=("X", 10), seam=0.65))
        for x in (-1.05, 1.05):
            cylinder((x, -1.15, 0.5), 0.05, 0.9, trim, vertices=10)
        box((0, -0.74, 1.0), (1.1, 0.04, 0.22), _mat("plaque", "#2f8f4a", roughness=0.5))

    def jeep(self, rng):
        paint = _mat("jeep", "#6f8a3a", roughness=0.45)
        dark = _mat("tire", "#2a2a2e", roughness=0.8)
        box((0, 0, 0.46), (1.6, 0.86, 0.34), paint, bevel=0.07)
        box((0.3, 0, 0.74), (0.85, 0.82, 0.22), paint, bevel=0.05)
        box((-0.2, 0, 0.86), (0.05, 0.8, 0.3), _mat("glass", "#bfe8ff", roughness=0.15), bevel=0.01)
        for x in (-0.5, 0.52):
            for y in (-0.44, 0.44):
                cylinder((x, y, 0.24), 0.24, 0.18, dark, rot=(math.pi / 2, 0, 0), vertices=20)
                cylinder((x, y * 1.06, 0.24), 0.11, 0.04, _mat("hub", "#d8d8d0", roughness=0.4), rot=(math.pi / 2, 0, 0),
                         vertices=14)
        cylinder((0.85, 0, 0.56), 0.22, 0.14, dark, rot=(0, math.pi / 2, 0), vertices=20)
        for y in (-0.38, 0.38):
            cylinder((0.62, y, 1.0), 0.03, 0.55, dark, vertices=8)
        box((0.62, 0, 1.27), (0.05, 0.8, 0.05), dark)
        for y in (-0.28, 0.28):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(-0.81, y, 0.52), segments=12, ring_count=6)
            bpy.context.object.data.materials.append(_mat("headlight", "#fff6c0", emission=1.5))

    def igloo(self, rng):
        organic("igloo", [ellipsoid((0, 0, 0), (0.95, 0.95, 0.8), "snow", "t", blend=0.05),
                          ellipsoid((0, -0.9, 0.0), (0.38, 0.45, 0.42), "snow", "t", blend=0.08)],
                lambda m: _shade(m, "#ffffff", "#9cc4e4"), voxel=0.03)[0].data.materials.append(
            _mat("igloo", "#ffffff", roughness=0.6, bands=("Z", 4), seam=0.82, use_vertex_color=True))
        organic("door", [ellipsoid((0, -1.32, 0.1), (0.22, 0.06, 0.26), "door", "t", blend=0.01)],
                lambda m: _shade(m, "#2a3e6a", "#18243e"), voxel=0.02)[0].data.materials.append(self._vc("door", 0.7))

    def lamp(self, rng):
        iron = _mat("iron", "#3a3f4a", roughness=0.4, metallic=0.6)
        cylinder((0, 0, 0.6), 0.05, 1.2, iron, vertices=12)
        cylinder((0, 0, 0.05), 0.12, 0.1, iron, vertices=12)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(0, 0, 1.28), segments=14, ring_count=8)
        bpy.context.object.data.materials.append(_mat("glow", "#ffe8a0", emission=2.5))

    def _vc(self, name, roughness):
        return _mat(name, "#ffffff", roughness=roughness, use_vertex_color=True)


def scatter(lib, theme, rng, pieces=(), keep_clear=False):
    """Scenery in the margins outside the fence. Tall pieces stay out of
    the near end, where they would stand in front of the player's herd;
    nothing goes where a set piece stands or (keep_clear) in the crowd's
    strip behind the far fence."""
    kinds = list(theme["props"].keys())
    weights = np.array([theme["props"][k] for k in kinds], float)
    weights /= weights.sum()
    low_kinds = [k for k in kinds if k not in TALL] or ["bush"]
    spots = []
    tries = 0
    while tries < 4000 and len(spots) < 120:
        tries += 1
        x = rng.uniform(X0 - 1, X1 + 1)
        t = rng.uniform(T0 - 2.5, T1 + 0.5)
        side = x < -0.9 or x > FIELD_W + 0.9
        beyond = t < -0.8 or t > FIELD_H + 0.8
        if not (side or beyond):
            continue
        if keep_clear and CROWD_STRIP[0] < x < CROWD_STRIP[1] and CROWD_STRIP[2] < t < CROWD_STRIP[3]:
            continue
        if any((x - float(p[1])) ** 2 + (t - float(p[2])) ** 2 < (1.3 * float(p[3]) + 0.4) ** 2 for p in pieces):
            continue
        kind = kinds[rng.choice(len(kinds), p=weights)]
        tall = kind in TALL
        if tall and (t > FIELD_H - 3.0 or (not beyond and min(abs(x + 0.9), abs(x - FIELD_W - 0.9)) < 1.0)):
            kind = low_kinds[rng.integers(len(low_kinds))]
            tall = False
        gap = 1.5 if tall else 0.9
        if any((x - sx) ** 2 + (t - st) ** 2 < gap * gap for sx, st, _ in spots):
            continue
        spots.append((x, t, kind))
    for x, t, kind in spots:
        _place(lib.copy(kind), x, t, scale=rng.uniform(0.85, 1.2), turn=rng.uniform(0, math.tau))


def fence(theme):
    """A low wooden fence all the way around the field."""
    wood = _mat("fence", theme["fence"], roughness=0.8)
    left, right, top, bottom = -0.3, FIELD_W + 0.3, -0.3, FIELD_H + 0.3
    for x in (left, right):
        n = int(round(bottom - top)) + 1
        for i in range(n):
            box((x, wy(top + (bottom - top) * i / (n - 1)), 0.2), (0.11, 0.11, 0.42), wood, bevel=0.02)
        for z in (0.17, 0.33):
            box((x, wy((top + bottom) / 2), z), (0.07, (bottom - top) / SIN, 0.07), wood, bevel=0.015)
    for t in (top, bottom):
        n = int(round(right - left)) + 1
        for i in range(n):
            box((left + (right - left) * i / (n - 1), wy(t), 0.2), (0.11, 0.11, 0.42), wood, bevel=0.02)
        for z in (0.17, 0.33):
            box(((left + right) / 2, wy(t), z), (right - left, 0.07, 0.07), wood, bevel=0.015)


# --- Rendering -----------------------------------------------------------------------------

def render_arena(arena_id, ppt, samples, out_dir):
    theme = THEMES[arena_id]
    rng = np.random.default_rng(zlib.crc32(arena_id.encode()))
    sc = S.reset()
    sc.cycles.samples = samples
    sc.render.film_transparent = False
    # Plain color handling keeps the painted greens vivid; the softer
    # contrast the animals use washes a big sunny field out.
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.7, 0.8, 1.0)

    keep_flat = bpy.data.collections.new("no_outline")
    sc.collection.children.link(keep_flat)
    ground = _grid("ground", (GX0, GX1), (GT0, GT1), 2, lambda x, t: np.zeros_like(x))
    ground.data.materials.append(_textured("ground", _image(f"ground_{arena_id}", paint_ground(theme, rng))))
    for col in ground.users_collection:
        col.objects.unlink(ground)
    keep_flat.objects.link(ground)

    lib = Library(theme, rng)
    life = LIFE.get(arena_id, {})
    pieces = life.get("pieces", [])
    for kind, x, t, size, turn in pieces:
        base, k = ALIASES.get(kind, (kind, 1.0))
        _place(lib.copy(base), float(x), float(t), scale=float(size) * k, turn=math.radians(float(turn)))
    scatter(lib, theme, rng, pieces, keep_clear=bool(life.get("actors")))
    fence(theme)
    lib.hidden.hide_render = True

    S.lights(0.62)
    S.outline(max(1.2, ppt / 32.0))
    cam = S.ortho_camera(ELEVATION, T1 - T0, target=((X0 + X1) / 2, wy((T0 + T1) / 2), 0.0), distance=80.0)
    cam.data.clip_end = 300.0
    sc.render.resolution_x = int(round((X1 - X0) * ppt))
    sc.render.resolution_y = int(round((T1 - T0) * ppt))
    tmp = os.path.join(tempfile.gettempdir(), f"_arena_{arena_id}.png")
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    im = Image.open(tmp).convert("RGB")
    os.remove(tmp)
    path = os.path.join(out_dir, f"{arena_id}.webp")
    # Lossless: the game compresses it once, on import (set_import.py).
    im.save(path, "WEBP", lossless=True, quality=100, method=4)
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", nargs="*")
    parser.add_argument("--ppt", type=int, default=64)
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--out", default=OUT)
    args = parser.parse_args(argv)
    os.makedirs(args.out, exist_ok=True)
    for arena_id in args.only or list(THEMES):
        path = render_arena(arena_id, args.ppt, args.samples, args.out)
        print("arena", arena_id, path, os.path.getsize(path) // 1024, "KB", flush=True)
    # What part of the field every picture covers (the same for all), and
    # each one's resolution.
    old = os.path.join(args.out, "arenas.json")
    meta = json.load(open(old)) if os.path.exists(old) else {}
    sizes = meta.get("pixels_per_arena", {})
    for arena_id in args.only or list(THEMES):
        sizes[arena_id] = args.ppt
    meta = {"pixels_per_tile": args.ppt, "x": [X0, X1], "y": [T0, T1], "pixels_per_arena": sizes}
    with open(os.path.join(args.out, "arenas.json"), "w") as f:
        json.dump(meta, f, indent=1)


if __name__ == "__main__":
    main()
