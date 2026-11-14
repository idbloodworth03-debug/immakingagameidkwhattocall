"""Builds and renders the menu's toy props: the cages, coins, gems, the
trophy and the tab icons, in the same flat toy style as the animals.

    python tools/props/props.py                 # every prop
    python tools/props/props.py cage_twig coin  # some
    python tools/props/props.py --list

Writes game/art/menu/<name>.webp. (Blender's Python, as for tools/packs.)

A prop is a few chunky shapes built by code here (no outside art): rounded
boxes, balls, bars bent along a path, shapes turned on a lathe. Each takes
one flat color. They are lit and drawn exactly as the toy animals' card
portraits are (tools/packs/render.py: the two-tone toon shading, the big
soft key light, one clean dark outline), so a cage on the home screen and
the animal next to it look like toys from the same box.

The cages take their colors from game/data/cages.json, the rest from
PALETTE below (the game's own colors, data/ui_style.json).
"""
import argparse
import json
import math
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(HERE, "..", "packs"))
sys.path.insert(0, os.path.join(HERE, "..", "creatures"))
sys.path.insert(0, os.path.join(HERE, "..", "creatures", "species"))

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector
from PIL import Image

import render as R
import scene as S
import sprites as SP

OUT = os.path.join(ROOT, "game", "art", "menu")
CAGES = {c["id"]: c for c in json.load(open(os.path.join(ROOT, "game", "data", "cages.json")))}
STYLE = json.load(open(os.path.join(ROOT, "game", "data", "ui_style.json")))["colors"]

PALETTE = {
    "gold": "#ffc93d", "gold_dark": "#e79a14", "gold_light": "#ffe27a",
    "gem": STYLE["gem"], "gem_light": "#a8ffcf", "gem_dark": "#1fae5e",
    "wood": "#c9823f", "wood_dark": "#8a5226", "wood_light": "#e9ab66",
    "red": STYLE["danger"], "red_dark": "#b8301f", "white": "#fff8ec", "cream": "#ffe9c4",
    "blue": STYLE["secondary"], "blue_dark": "#1f6fc0", "green": STYLE["primary"], "green_dark": "#2f8f1a",
    "steel": "#c9d6e6", "steel_dark": "#8195ad", "dark": "#2a1a12", "ink": "#3a2414",
    "pink": "#ff8fa3", "purple": STYLE["tool"], "orange": "#ff9a3d", "brass": "#f2b331",
}


# --- Colors -------------------------------------------------------------------------

def rgb(color):
    """A color name (PALETTE) or "#rrggbb" as linear RGB (what the vertex
    colors hold; the render turns it back)."""
    h = PALETTE.get(color, color).lstrip("#")
    return [S.srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]


def shade(color, k):
    """`color` lighter (k > 0) or darker (k < 0), as "#rrggbb"."""
    h = PALETTE.get(color, color).lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    c = [v + (1.0 - v) * k if k > 0 else v * (1.0 + k) for v in c]
    return "#" + "".join("%02x" % int(round(min(1.0, max(0.0, v)) * 255)) for v in c)


# --- Shapes ---------------------------------------------------------------------------

def _finish(ob, color, smooth=True):
    """Gives an object its flat color (the "Col" attribute the toon shader
    reads) and smooth shading."""
    me = ob.data
    for poly in me.polygons:
        poly.use_smooth = smooth
    attr = me.color_attributes.get("Col") or me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    values = np.tile(np.array(rgb(color) + [1.0]), len(me.loops))
    attr.data.foreach_set("color", values)
    me.color_attributes.active_color = attr
    return ob


def _place(ob, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.scale = scale if isinstance(scale, (tuple, list)) else (scale, scale, scale)
    return ob


def ball(r, loc, color, scale=(1, 1, 1), rot=(0, 0, 0), segments=40):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=segments, ring_count=segments // 2)
    return _place(_finish(bpy.context.object, color), loc, rot, scale)


def cylinder(r, h, loc, color, rot=(0, 0, 0), r_top=None, bevel=0.0, segments=48, scale=(1, 1, 1)):
    """A cylinder (a cone or a tapered one with r_top), standing on z, its
    middle at `loc`; `bevel` rounds its rims."""
    if r_top is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=segments)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r_top, depth=h, vertices=segments)
    ob = bpy.context.object
    if bevel > 0.0:
        mod = ob.modifiers.new("round", "BEVEL")
        mod.width = bevel
        mod.segments = 4
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.harden_normals = True
    return _place(_finish(ob, color), loc, rot, scale)


def box(size, loc, color, rot=(0, 0, 0), bevel=0.05):
    """A box with rounded edges, `size` (x, y, z) across."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.object
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = ob.modifiers.new("round", "BEVEL")
        mod.width = bevel
        mod.segments = 4
        mod.harden_normals = True
    return _place(_finish(ob, color), loc, rot)


def torus(R_, r, loc, color, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R_, minor_radius=r, major_segments=48, minor_segments=16)
    return _place(_finish(bpy.context.object, color), loc, rot, scale)


def _smooth_path(points, steps=10):
    """A smooth curve through `points` (Catmull-Rom), as many more points."""
    p = [np.array(q, float) for q in points]
    p = [p[0]] + p + [p[-1]]
    out = []
    for i in range(1, len(p) - 2):
        for s in range(steps):
            t = s / steps
            out.append(0.5 * ((2 * p[i]) + (-p[i - 1] + p[i + 1]) * t
                              + (2 * p[i - 1] - 5 * p[i] + 4 * p[i + 1] - p[i + 2]) * t * t
                              + (-p[i - 1] + 3 * p[i] - 3 * p[i + 1] + p[i + 2]) * t * t * t))
    out.append(p[-2])
    return out


def tube(points, r, color, loc=(0, 0, 0), rot=(0, 0, 0), smooth_path=True, caps=True):
    """A round bar of radius `r` bent along `points`."""
    path = _smooth_path(points) if smooth_path and len(points) > 2 else [np.array(q, float) for q in points]
    curve = bpy.data.curves.new("bar", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = r
    curve.bevel_resolution = 6
    curve.use_fill_caps = caps
    spline = curve.splines.new("POLY")
    spline.points.add(len(path) - 1)
    for point, q in zip(spline.points, path):
        point.co = (q[0], q[1], q[2], 1.0)
    ob = bpy.data.objects.new("bar", curve)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for other in bpy.context.selected_objects:
        other.select_set(False)
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.object
    return _place(_finish(ob, color), loc, rot)


def lathe(profile, color, loc=(0, 0, 0), rot=(0, 0, 0), segments=56, scale=(1, 1, 1)):
    """`profile`: (radius, height) pairs from the bottom up, turned round z."""
    prof = np.array(profile, float)
    n = len(prof)
    angles = np.linspace(0, 2 * math.pi, segments, endpoint=False)
    verts = [(r * math.cos(a), r * math.sin(a), z) for r, z in prof for a in angles]
    faces = []
    for i in range(n - 1):
        for j in range(segments):
            a, b = i * segments + j, i * segments + (j + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    # Closed at both ends.
    verts.append((0, 0, prof[0][1]))
    verts.append((0, 0, prof[-1][1]))
    bottom, top = len(verts) - 2, len(verts) - 1
    for j in range(segments):
        faces.append((bottom, (j + 1) % segments, j))
        faces.append((top, (n - 1) * segments + j, (n - 1) * segments + (j + 1) % segments))
    me = bpy.data.meshes.new("turned")
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new("turned", me)
    bpy.context.scene.collection.objects.link(ob)
    return _place(_finish(ob, color), loc, rot, scale)


def ring(r_in, r_out, h, color, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.02, segments=56):
    """A flat ring round z (a coin's raised rim), `h` tall, its middle at `loc`."""
    prof = [(r_in, -h / 2), (r_out, -h / 2), (r_out, h / 2), (r_in, h / 2)]
    n = len(prof)
    angles = np.linspace(0, 2 * math.pi, segments, endpoint=False)
    verts = [(r * math.cos(a), r * math.sin(a), z) for r, z in prof for a in angles]
    faces = []
    for i in range(n):
        k = (i + 1) % n
        for j in range(segments):
            j2 = (j + 1) % segments
            faces.append((i * segments + j, i * segments + j2, k * segments + j2, k * segments + j))
    me = bpy.data.meshes.new("ring")
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new("ring", me)
    bpy.context.scene.collection.objects.link(ob)
    if bevel > 0.0:
        mod = ob.modifiers.new("round", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.harden_normals = True
    return _place(_finish(ob, color), loc, rot)


def prism(outline, depth, color, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.03, scale=(1, 1, 1), smooth=True):
    """A flat shape (`outline`: (x, z) points, counter-clockwise seen from
    the front) `depth` thick along y, its edges rounded."""
    outline = list(outline)
    area = sum(outline[i][0] * outline[(i + 1) % len(outline)][1] - outline[(i + 1) % len(outline)][0] * outline[i][1] for i in range(len(outline)))
    if area < 0:
        outline.reverse()
    n = len(outline)
    verts = [(x, -depth / 2, z) for x, z in outline] + [(x, depth / 2, z) for x, z in outline]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, i + n, j + n, j))
    me = bpy.data.meshes.new("flat")
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new("flat", me)
    bpy.context.scene.collection.objects.link(ob)
    if bevel > 0.0:
        mod = ob.modifiers.new("round", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30)
        mod.harden_normals = True
    return _place(_finish(ob, color, smooth), loc, rot, scale)


def star_outline(r_out, r_in, points=5, turn=0.0):
    out = []
    for i in range(points * 2):
        a = math.pi / 2 + turn + i * math.pi / points
        r = r_out if i % 2 == 0 else r_in
        out.append((r * math.cos(a), r * math.sin(a)))
    return out


def blob_outline(rx, rz, n=40, squash=1.0):
    return [(rx * math.cos(2 * math.pi * i / n), rz * math.sin(2 * math.pi * i / n) * squash) for i in range(n)]


def group(objects, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    """Moves a few shapes together (as one piece)."""
    parent = bpy.data.objects.new("group", None)
    bpy.context.scene.collection.objects.link(parent)
    for ob in objects:
        ob.parent = parent
    _place(parent, loc, rot, scale)
    return parent


def eyes(at, gap, r, look=(0.0, 0.0)):
    """Two toy button eyes looking out toward -y, centered on `at`."""
    out = []
    for side in (-1, 1):
        c = (at[0] + side * gap / 2, at[1], at[2])
        out.append(ball(r, c, "white", scale=(1, 0.55, 1)))
        out.append(ball(r * 0.52, (c[0] + look[0] * r, c[1] - r * 0.42, c[2] + look[1] * r), "dark", scale=(1, 0.5, 1)))
        out.append(ball(r * 0.17, (c[0] + look[0] * r - r * 0.18, c[1] - r * 0.62, c[2] + look[1] * r + r * 0.2), "white", scale=(1, 0.5, 1)))
    return out


# --- The props --------------------------------------------------------------------------

def coin(loc=(0, 0, 0), rot=(0, 0, 0), r=0.5, paw=True):
    """A thick gold coin lying flat on z (turn it with `rot`), a paw on it."""
    k = r / 0.5
    parts = [cylinder(r * 0.84, 0.13 * k, (0, 0, 0), "gold"),
             ring(r * 0.8, r, 0.19 * k, "gold_light", bevel=0.035 * k)]
    if paw:
        for z in (0.066 * k, -0.066 * k):
            parts.append(ball(0.2 * k, (0, -0.08 * k, z), "gold_dark", scale=(1.12, 0.88, 0.2)))
            for x, y, s in ((-0.235, 0.085, 0.085), (-0.09, 0.2, 0.09), (0.09, 0.2, 0.09), (0.235, 0.085, 0.085)):
                parts.append(ball(s * k, (x * k, y * k, z), "gold_dark", scale=(1, 1.15, 0.3)))
    return group(parts, loc, rot)


def build_coin():
    coin((0, 0, 0.5), rot=(78, 0, -24))
    return {"shadow": False, "view": (0.0, -1.0, 0.12)}


def build_coins_small():
    coin((0, 0, 0.09), rot=(0, 0, 20))
    coin((0.07, -0.03, 0.27), rot=(0, 0, 75))
    coin((0.72, -0.3, 0.33), rot=(64, 0, 38), r=0.42)
    return {"view": (0.25, -1.0, 0.5)}


def build_coins_medium():
    for i in range(4):
        coin((-0.35 + 0.03 * math.sin(i * 2.1), 0.1 + 0.03 * math.cos(i * 1.7), 0.09 + 0.18 * i), rot=(0, 0, 37 * i))
    for i in range(2):
        coin((0.62 + 0.03 * i, 0.22, 0.09 + 0.18 * i), rot=(0, 0, 50 * i + 15))
    coin((0.3, -0.62, 0.09), rot=(0, 0, 10))
    coin((0.95, -0.42, 0.36), rot=(58, 0, 32), r=0.44)
    coin((-0.62, -0.62, 0.3), rot=(66, 0, -30), r=0.4)
    return {"view": (0.25, -1.0, 0.5)}


def build_coins_large():
    """A wooden chest, open and heaped with coins."""
    w, d, h = 1.7, 1.1, 0.72
    box((w, d, h), (0, 0, h / 2), "wood", bevel=0.07)
    for x in (-w / 2 + 0.16, w / 2 - 0.16):
        box((0.16, d + 0.06, h + 0.04), (x, 0, h / 2), "brass", bevel=0.03)
    box((w + 0.06, d + 0.06, 0.13), (0, 0, h - 0.02), "wood_dark", bevel=0.04)
    # The lid, thrown back.
    lid = [cylinder(d / 2, w, (0, 0, 0), "wood", rot=(0, 90, 0), bevel=0.05, scale=(0.62, 1, 1))]
    for x in (-w / 2 + 0.16, w / 2 - 0.16):
        lid.append(cylinder(d / 2 + 0.03, 0.16, (x, 0, 0), "brass", rot=(0, 90, 0), bevel=0.02, scale=(0.64, 1, 1)))
    group(lid, (0, d / 2 + 0.2, h + 0.38), rot=(-62, 0, 0))
    # The lock plate.
    box((0.26, 0.08, 0.3), (0, -d / 2 - 0.02, h - 0.2), "brass", bevel=0.03)
    ball(0.05, (0, -d / 2 - 0.07, h - 0.2), "dark")
    # The heap.
    ball(0.62, (0, 0.0, h - 0.12), "gold", scale=(1.2, 0.74, 0.62))
    rng = np.random.default_rng(7)
    for i in range(16):
        a = rng.uniform(0, 2 * math.pi)
        rad = rng.uniform(0.05, 0.62)
        z = h + 0.26 - 0.28 * (rad / 0.62) ** 2 + rng.uniform(-0.02, 0.05)
        coin((1.1 * rad * math.cos(a), 0.6 * rad * math.sin(a), z), rot=(rng.uniform(-28, 28), rng.uniform(-28, 28), rng.uniform(0, 360)), r=0.24, paw=False)
    coin((0.1, -0.12, h + 0.42), rot=(66, 0, 22), r=0.3)
    coin((-0.5, -0.05, h + 0.33), rot=(58, 12, -34), r=0.27)
    # A few spilled in front.
    coin((-0.95, -0.85, 0.05), rot=(0, 0, 12), r=0.26)
    coin((0.62, -0.92, 0.05), rot=(0, 0, 80), r=0.26)
    coin((0.72, -0.86, 0.15), rot=(0, 0, 30), r=0.26)
    return {"view": (0.3, -1.0, 0.55)}


def gem(loc=(0, 0, 0), rot=(0, 0, 0), size=1.0, color="gem"):
    """A cut gem with clear, flat facets: a table, a crown, a point."""
    n = 8
    rings = [(0.0, -0.62), (0.56, 0.06), (0.6, 0.12), (0.36, 0.4)]
    verts = [(0.0, 0.0, rings[0][1])]
    for r, z in rings[1:]:
        for i in range(n):
            a = 2 * math.pi * (i + 0.5) / n
            verts.append((r * math.cos(a), r * math.sin(a), z))
    verts.append((0.0, 0.0, rings[-1][1]))
    faces = []
    ring = lambda k, i: 1 + k * n + i % n
    for i in range(n):
        faces.append((0, ring(0, i + 1), ring(0, i)))
        for k in range(2):
            faces.append((ring(k, i), ring(k, i + 1), ring(k + 1, i + 1), ring(k + 1, i)))
        faces.append((len(verts) - 1, ring(2, i), ring(2, i + 1)))
    me = bpy.data.meshes.new("gem")
    me.from_pydata([tuple(size * c for c in v) for v in verts], [], faces)
    me.update()
    ob = bpy.data.objects.new("gem", me)
    bpy.context.scene.collection.objects.link(ob)
    _finish(ob, color, smooth=False)
    # The facets in three tones, as light catches a cut stone.
    attr = me.color_attributes["Col"]
    tones = {"table": rgb(shade(color, 0.55)), "crown": rgb(shade(color, 0.22)), "girdle": rgb(color), "point": rgb(shade(color, -0.2))}
    values = []
    for poly in me.polygons:
        z = poly.center.z / size
        tone = tones["table"] if z > 0.39 else tones["crown"] if z > 0.15 else tones["girdle"] if z > 0.05 else tones["point"]
        # Every other facet a touch lighter, so the cut reads.
        k = 1.0 if (int(round(math.atan2(poly.center.y, poly.center.x) / (2 * math.pi / n))) % 2 == 0 or z > 0.39) else 0.86
        for _ in poly.loop_indices:
            values.extend([tone[0] * k, tone[1] * k, tone[2] * k, 1.0])
    attr.data.foreach_set("color", values)
    return _place(ob, loc, rot)


def build_gem():
    gem((0, 0, 0.7), rot=(-22, 0, 22))
    return {"shadow": False, "view": (0.0, -1.0, 0.2), "creases": True}


def build_gems_pile():
    gem((0, 0, 0.62), rot=(-14, 6, 20), size=1.0)
    gem((-0.78, -0.3, 0.34), rot=(-30, -24, -10), size=0.58)
    gem((0.74, -0.34, 0.36), rot=(-24, 26, 40), size=0.62)
    gem((0.1, -0.78, 0.26), rot=(-38, 4, 12), size=0.44)
    return {"view": (0.15, -1.0, 0.42), "creases": True}


def build_trophy():
    lathe([(0.0, 0.0), (0.5, 0.0), (0.52, 0.04), (0.52, 0.2), (0.46, 0.26), (0.0, 0.26)], "wood_dark")
    lathe([(0.0, 0.24), (0.3, 0.24), (0.32, 0.3), (0.18, 0.4), (0.12, 0.52), (0.12, 0.66), (0.2, 0.72), (0.0, 0.72)], "gold_dark")
    lathe([(0.0, 0.7), (0.16, 0.7), (0.4, 0.84), (0.56, 1.08), (0.62, 1.42), (0.66, 1.5), (0.6, 1.52), (0.54, 1.44), (0.0, 1.4)], "gold")
    torus(0.62, 0.05, (0, 0, 1.5), "gold_light")
    for side in (-1, 1):
        tube([(side * 0.56, 0, 1.36), (side * 0.9, 0, 1.38), (side * 0.98, 0, 1.12), (side * 0.78, 0, 0.9), (side * 0.46, 0, 0.92)], 0.06, "gold")
    prism(star_outline(0.2, 0.09), 0.08, "gold_light", (0, -0.57, 1.2), rot=(8, 0, 0), bevel=0.015)
    box((0.5, 0.06, 0.12), (0, -0.5, 0.12), "brass", bevel=0.02)
    return {"view": (0.2, -1.0, 0.3)}


def _cage(color, topper="ring", peek=True, door=True, bars=8):
    """A toy cage: a round tray, chunky bars bent into a dome, a cap with a
    topper, a brass padlock on the tray, and (peek) someone's eyes in the
    dark inside, looking out between the bars."""
    light, dark = shade(color, 0.35), shade(color, -0.3)
    r, z0, z1, z2 = 0.6, 0.2, 0.86, 1.3
    inside = r - 0.08
    cylinder(r + 0.14, 0.2, (0, 0, 0.1), dark, bevel=0.06)
    torus(r + 0.02, 0.06, (0, 0, z0 + 0.01), light)
    # The dark inside.
    cylinder(inside, z1 - z0, (0, 0, (z0 + z1) / 2), "dark")
    ball(inside, (0, 0, z1), "dark", scale=(1, 1, (z2 - z1 - 0.06) / inside))
    for i in range(bars):
        # (A gap, not a bar, faces the front.)
        a = 2 * math.pi * (i + 0.5) / bars - math.pi / 2
        c, s = math.cos(a), math.sin(a)
        path = [(r * c, r * s, z0), (r * c, r * s, z1 - 0.1), (r * 0.96 * c, r * 0.96 * s, z1 + 0.08),
                (r * 0.76 * c, r * 0.76 * s, z1 + 0.28), (r * 0.42 * c, r * 0.42 * s, z2 - 0.03), (0.06 * c, 0.06 * s, z2)]
        tube(path, 0.066, color)
    torus(r, 0.058, (0, 0, z1 - 0.04), light)
    ball(0.17, (0, 0, z2 + 0.02), light, scale=(1, 1, 0.7))
    top = z2 + 0.1
    if topper == "ring":
        torus(0.13, 0.045, (0, 0, top + 0.13), light, rot=(90, 0, 0))
    elif topper == "leaf":
        for side in (-1, 1):
            ball(0.17, (side * 0.14, 0, top + 0.12), "green", scale=(1.25, 0.4, 0.62), rot=(0, -side * 32, 0))
        cylinder(0.03, 0.14, (0, 0, top + 0.03), "wood_dark")
    elif topper == "star":
        prism(star_outline(0.24, 0.11), 0.1, "gold_light", (0, 0, top + 0.2), bevel=0.02)
    elif topper == "gem":
        gem((0, 0, top + 0.22), rot=(-10, 0, 22), size=0.36, color="#7fe9ff")
    elif topper == "crown":
        lathe([(0.0, 0.0), (0.2, 0.0), (0.22, 0.05), (0.22, 0.16), (0.0, 0.16)], "gold", (0, 0, top))
        for i in range(5):
            a = 2 * math.pi * i / 5 - math.pi / 2
            cylinder(0.06, 0.16, (0.19 * math.cos(a), 0.19 * math.sin(a), top + 0.22), "gold", r_top=0.0, segments=16)
            ball(0.04, (0.19 * math.cos(a), 0.19 * math.sin(a), top + 0.31), "red")
    elif topper == "heart":
        heart = []
        for i in range(40):
            t = 2 * math.pi * i / 40
            heart.append((0.0135 * 16 * math.sin(t) ** 3, 0.0135 * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))))
        heart = heart[::-1]
        prism(heart, 0.12, "pink", (0, 0, top + 0.22), bevel=0.03)
    elif topper == "moon":
        big, tip = 0.25, math.radians(52)
        tips = (big * math.cos(tip), big * math.sin(tip))
        cx = 0.13
        small = math.hypot(tips[0] - cx, tips[1])
        inner = math.atan2(tips[1], tips[0] - cx)
        crescent = []
        for i in range(28):
            a = tip + (2 * math.pi - 2 * tip) * i / 27
            crescent.append((big * math.cos(a), big * math.sin(a)))
        for i in range(1, 27):
            a = -inner + (2 * inner - 2 * math.pi) * i / 27
            crescent.append((cx + small * math.cos(a), small * math.sin(a)))
        prism(crescent, 0.11, "gold_light", (0.02, 0, top + 0.27), rot=(0, -18, 0), bevel=0.02)
    if door:
        # A padlock on the tray.
        front = -(r + 0.14)
        box((0.24, 0.1, 0.2), (0, front - 0.03, 0.15), "brass", bevel=0.035)
        torus(0.075, 0.028, (0, front - 0.03, 0.28), "steel", rot=(90, 0, 0))
        ball(0.032, (0, front - 0.085, 0.15), "dark")
    if peek:
        eyes((0.0, -inside - 0.005, 0.56), 0.27, 0.12, look=(0.1, 0.06))
    return {"view": (0.2, -1.0, 0.36)}


CAGE_TOPPERS = {"twig": "leaf", "iron": "ring", "golden": "star", "crystal": "gem", "grand_enclosure": "crown",
                "sanctuary": "heart", "moonlit": "moon"}


def build_cage_empty():
    """An empty slot's cage: gray, nobody home, its lock off."""
    return _cage("#a7b0bf", "ring", peek=False, door=False)


def build_tab_shop():
    """A market stall: a counter, two posts and a striped awning."""
    box((1.5, 0.8, 0.62), (0, 0, 0.31), "wood", bevel=0.06)
    box((1.62, 0.92, 0.1), (0, 0, 0.64), "wood_light", bevel=0.04)
    for x in (-0.66, 0.66):
        cylinder(0.055, 0.8, (x, 0.28, 1.06), "wood_dark")
    stripes = 6
    for i in range(stripes):
        x = -0.75 + 1.5 * (i + 0.5) / stripes
        col = "red" if i % 2 == 0 else "white"
        box((1.5 / stripes + 0.012, 1.02, 0.1), (x, -0.1, 1.56), col, rot=(24, 0, 0), bevel=0.02)
        ball(1.5 / stripes / 2 + 0.006, (x, -0.58, 1.32), col, scale=(1, 0.5, 0.8))
    # Wares on the counter.
    ball(0.15, (-0.42, -0.1, 0.83), "orange")
    ball(0.15, (-0.12, -0.14, 0.83), "green")
    ball(0.15, (0.2, -0.1, 0.83), "orange")
    coin((0.52, -0.18, 0.74), r=0.16, paw=False)
    return {"shadow": False, "view": (0.3, -1.0, 0.4)}


def build_tab_animals():
    """A paw print, pads up."""
    prism(blob_outline(0.86, 0.86), 0.16, "orange", (0, 0, 0.86), bevel=0.05)
    ball(0.4, (0, -0.1, 0.62), "cream", scale=(1.25, 0.32, 0.95))
    for x, z, s in ((-0.5, 0.98, 0.17), (-0.19, 1.24, 0.19), (0.19, 1.24, 0.19), (0.5, 0.98, 0.17)):
        ball(s, (x, -0.1, z), "cream", scale=(1, 0.42, 1.2))
    return {"shadow": False, "view": (0.16, -1.0, 0.1)}


def _sword(turn, blade="steel"):
    parts = [prism([(-0.17, 0.0), (0.17, 0.0), (0.17, 0.86), (0.0, 1.12), (-0.17, 0.86)], 0.13, blade, (0, 0, 0.2), bevel=0.04),
             box((0.05, 0.145, 0.74), (0, 0, 0.64), "steel_dark", bevel=0.015),
             box((0.66, 0.2, 0.17), (0, 0, 0.2), "gold", bevel=0.06),
             cylinder(0.085, 0.36, (0, 0, -0.03), "wood_dark", bevel=0.03),
             ball(0.13, (0, 0, -0.26), "gold")]
    return group(parts, (0, 0, 0.75), rot=(0, turn, 0))


def build_tab_battle():
    """Two toy swords, crossed."""
    a = _sword(40)
    a.location.y = 0.1
    _sword(-40)
    return {"shadow": False, "view": (0.0, -1.0, 0.0)}


def build_tab_clan():
    """A shield with a paw on it."""
    outline = []
    for i in range(13):
        a = math.radians(180 - 180 * i / 12)
        outline.append((0.74 * math.cos(a), 1.5 + 0.16 * math.sin(a) * 0.0))
    shape = [(-0.74, 1.52), (-0.74, 0.86)]
    for i in range(1, 12):
        t = i / 12
        a = math.radians(180 + 180 * t)
        shape.append((0.74 * math.cos(a), 0.86 + 0.82 * math.sin(a)))
    shape += [(0.74, 0.86), (0.74, 1.52), (0.36, 1.62), (0.0, 1.54), (-0.36, 1.62)]
    prism(shape, 0.2, "gold", (0, 0, 0), bevel=0.05)
    inner = [(x * 0.84, 0.9 + (z - 0.9) * 0.84) for x, z in shape]
    prism(inner, 0.2, "blue", (0, -0.05, 0.0), bevel=0.04)
    ball(0.21, (0, -0.16, 0.74), "white", scale=(1.25, 0.3, 0.95))
    for x, z, s in ((-0.27, 0.93, 0.09), (-0.1, 1.07, 0.1), (0.1, 1.07, 0.1), (0.27, 0.93, 0.09)):
        ball(s, (x, -0.16, z), "white", scale=(1, 0.42, 1.2))
    return {"shadow": False, "view": (0.16, -1.0, 0.08)}


def build_tab_events():
    """A star medal on its ribbon."""
    for side in (-1, 1):
        prism([(-0.17, 0.0), (0.0, 0.16), (0.17, 0.0), (0.17, 0.74), (-0.17, 0.74)], 0.07, "red" if side < 0 else "red_dark",
              (side * 0.2, 0.06, 0.02), rot=(0, side * 16, 0), bevel=0.02)
    n = 18
    rosette = []
    for i in range(n * 2):
        a = 2 * math.pi * i / (n * 2)
        r = 0.72 if i % 2 == 0 else 0.62
        rosette.append((r * math.cos(a), r * math.sin(a)))
    prism(rosette, 0.14, "red", (0, 0, 1.12), bevel=0.03)
    prism(blob_outline(0.54, 0.54), 0.16, "gold", (0, -0.05, 1.12), bevel=0.04)
    prism(star_outline(0.4, 0.18), 0.12, "gold_light", (0, -0.13, 1.12), bevel=0.025)
    return {"shadow": False, "view": (0.12, -1.0, 0.06)}


def build_lock():
    box((0.9, 0.42, 0.74), (0, 0, 0.37), "brass", bevel=0.12)
    tube([(-0.26, 0, 0.7), (-0.26, 0, 1.0), (-0.16, 0, 1.2), (0.16, 0, 1.2), (0.26, 0, 1.0), (0.26, 0, 0.7)], 0.085, "steel")
    ball(0.1, (0, -0.2, 0.42), "dark", scale=(1, 0.5, 1))
    box((0.07, 0.1, 0.2), (0, -0.2, 0.3), "dark", bevel=0.02)
    return {"shadow": False, "view": (0.2, -1.0, 0.12)}


def build_sign_post():
    """A trail sign on its post (for a page that isn't open yet)."""
    cylinder(0.09, 1.5, (0, 0, 0.75), "wood_dark", bevel=0.03)
    prism([(-0.86, 0.0), (0.62, 0.0), (0.92, 0.24), (0.62, 0.48), (-0.86, 0.48)], 0.12, "wood_light", (0, -0.1, 0.9), rot=(0, -4, 0), bevel=0.035)
    for x in (-0.66, 0.5):
        ball(0.04, (x, -0.17, 1.13), "wood_dark")
    for x, r in ((-0.3, 0.26), (0.26, 0.22), (0.0, 0.17)):
        ball(r, (x, -0.08 if r < 0.2 else 0.04, r * 0.75), "green", scale=(1.0, 0.9, 0.9))
    return {"view": (0.25, -1.0, 0.25)}


PROPS = {
    "coin": build_coin, "coins_small": build_coins_small, "coins_medium": build_coins_medium, "coins_large": build_coins_large,
    "gem": build_gem, "gems_pile": build_gems_pile, "trophy": build_trophy, "cage_empty": build_cage_empty,
    "tab_shop": build_tab_shop, "tab_animals": build_tab_animals, "tab_battle": build_tab_battle, "tab_clan": build_tab_clan,
    "tab_events": build_tab_events, "lock": build_lock, "sign_post": build_sign_post,
}
for _id, _cage_info in CAGES.items():
    PROPS["cage_" + _id] = (lambda info=_cage_info, cid=_id: _cage(info["color"], CAGE_TOPPERS.get(cid, "ring")))

# How big each is rendered (pixels on a side): big for what is shown big.
SIZES = {"coin": 256, "gem": 256, "lock": 256, "tab_shop": 320, "tab_animals": 320, "tab_battle": 320, "tab_clan": 320, "tab_events": 320}


# --- Rendering ----------------------------------------------------------------------------

def render(name, out_dir, size=None, samples=None):
    started = time.time()
    sc = S.reset()
    info = PROPS[name]() or {}
    size = size or SIZES.get(name, 512)
    sc.cycles.samples = samples or int(R.LOOK["portrait_samples"])
    mat = R._material()
    for ob in sc.objects:
        if ob.type == "MESH":
            ob.data.materials.clear()
            ob.data.materials.append(mat)
    bpy.context.view_layer.update()
    R._lights(1.1)
    if info.get("shadow", True):
        R._shadow(12)
    S.outline(float(R.LOOK["outline"]["portrait_pixels"]) * size / 512.0, color=R.LOOK["outline"]["color"])
    if info.get("creases"):
        # A cut stone shows its facets' edges too.
        lineset = sc.view_layers[0].freestyle_settings.linesets[0]
        lineset.select_crease = True
        sc.view_layers[0].freestyle_settings.crease_angle = math.radians(150)
        lineset.linestyle.thickness = float(R.LOOK["outline"]["portrait_pixels"]) * size / 512.0
    pts = SP._scene_points()
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    center = (lo + hi) / 2
    radius = float(np.linalg.norm(hi - lo)) / 2
    d = np.array(info.get("view", (0.25, -1.0, 0.4)), float)
    d /= np.linalg.norm(d)
    cam = S.perspective_camera(tuple(center + d * radius * 3.4), tuple(center), lens=float(info.get("lens", 85)))
    sc.render.resolution_x = sc.render.resolution_y = size
    SP._fit_camera(cam, pts, fill=float(info.get("fill", 0.9)))
    path = os.path.join(tempfile.gettempdir(), f"_prop_{name}.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = Image.fromarray(SP.clean_alpha(np.asarray(Image.open(path).convert("RGBA"))))
    os.makedirs(out_dir, exist_ok=True)
    im.save(os.path.join(out_dir, name + ".webp"), "WEBP", lossless=True, quality=100, method=4)
    os.remove(path)
    print(f"[props] {name}: {size}x{size} in {time.time() - started:.1f} s")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("names", nargs="*")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--out", default=OUT)
    parser.add_argument("--size", type=int, default=0)
    parser.add_argument("--samples", type=int, default=0)
    args = parser.parse_args()
    if args.list:
        print(" ".join(sorted(PROPS)))
        return
    for name in args.names or sorted(PROPS):
        if name not in PROPS:
            raise SystemExit(f"No prop '{name}' (see --list)")
        render(name, args.out, args.size or None, args.samples or None)


if __name__ == "__main__":
    main()
