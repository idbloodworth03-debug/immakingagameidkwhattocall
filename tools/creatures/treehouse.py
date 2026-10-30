"""Renders the dens: cartoon treehouses in the animals' style (3D, lit,
outlined), from the game's camera angle.

    python treehouse.py [--out game/art/towers] [--samples 48]

Writes side_blue, side_red, main_blue, main_red, side_ruin and main_ruin
(.webp) and towers.json (each picture's anchor, the point under the
tower's middle, and how high it reaches, in pixels at pixels_per_tile).

The side dens are a stout tree with a round deck and a little cabin under
a roof in the team's color. The main den is bigger and grander: a huge
tree holding a two-story lodge with gold trim, a crown over the door,
lanterns and a tall flag.
"""
import argparse
import json
import math
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy
import numpy as np
from PIL import Image

import scene as S
from sdf import build_mesh, cone, ellipsoid
from sprites import ELEVATION, clean_alpha

PIXELS_PER_TILE = 100      # dens are big on screen, so finer than the animals
TEAMS = {"blue": "#2f6fd0", "red": "#c62f36"}
GOLD = "#f2c230"


# --- Materials -------------------------------------------------------------------------

def _mat(name, color, roughness=0.6, bands=None, seam=0.55, emission=0.0, metallic=0.0, use_vertex_color=False):
    """A plain material, optionally with plank or shingle bands: `bands` is
    (axis, bands per meter)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    base = S.hex_color(color) if isinstance(color, str) else color
    if use_vertex_color:
        col = nodes.new("ShaderNodeVertexColor")
        col.layer_name = "Col"
        source = col.outputs["Color"]
    else:
        rgb = nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*base, 1)
        source = rgb.outputs[0]
    if bands:
        axis, per_meter = bands
        coord = nodes.new("ShaderNodeTexCoord")
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(coord.outputs["Object"], sep.inputs[0])
        scaled = nodes.new("ShaderNodeMath")
        scaled.operation = "MULTIPLY"
        links.new(sep.outputs[axis], scaled.inputs[0])
        scaled.inputs[1].default_value = per_meter
        frac = nodes.new("ShaderNodeMath")
        frac.operation = "FRACT"
        links.new(scaled.outputs[0], frac.inputs[0])
        line = nodes.new("ShaderNodeMath")
        line.operation = "LESS_THAN"
        links.new(frac.outputs[0], line.inputs[0])
        line.inputs[1].default_value = 0.12
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        links.new(line.outputs[0], mix.inputs["Factor"])
        links.new(source, mix.inputs[6])
        mix.inputs[7].default_value = (*[c * seam for c in base], 1)
        source = mix.outputs[2]
    links.new(source, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*base, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


# --- Building blocks -------------------------------------------------------------------

def _finish(obj, mat, bevel=0.0, smooth=False):
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    if smooth:
        bpy.ops.object.shade_smooth()
    return obj


def box(center, size, mat, bevel=0.025, rot_z=0.0, rot_x=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=(rot_x, 0, rot_z))
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, mat, bevel)


def cylinder(center, radius, depth, mat, rot=(0, 0, 0), vertices=24, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center, rotation=rot)
    return _finish(bpy.context.object, mat, bevel, smooth=True)


def sphere(center, radius, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=center, segments=20, ring_count=10)
    return _finish(bpy.context.object, mat, smooth=True)


def roof(center, width, depth, height, mat):
    """A four-sided pyramid roof, `width` x `depth` at the eaves."""
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.0, radius2=0.0, depth=height,
                                    location=(center[0], center[1], center[2] + height / 2), rotation=(0, 0, math.pi / 4))
    obj = bpy.context.object
    bpy.ops.object.transform_apply(rotation=True)
    obj.scale = (width / math.sqrt(2), depth / math.sqrt(2), 1.0)
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, mat, bevel=0.03)


def torus(center, major, minor, mat):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=center,
                                     major_segments=40, minor_segments=8)
    return _finish(bpy.context.object, mat, smooth=True)


def organic(name, shapes, paint, voxel=0.03):
    """A blobby mesh (trunk and roots, leaves) from blended shapes, colored
    per vertex by paint(mesh) -> N x 3 linear colors."""
    mesh = build_mesh(shapes, voxel=voxel, padding=voxel * 4)
    me = bpy.data.meshes.new(name)
    me.from_pydata(mesh.verts.tolist(), [], mesh.faces.tolist())
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    S._set_colors(me, paint(mesh))
    return obj, mesh


def _shade(mesh, top, bottom, low=-0.4, high=0.7):
    """Lighter on top, darker underneath."""
    n = mesh.normals / np.maximum(np.linalg.norm(mesh.normals, axis=1, keepdims=True), 1e-9)
    t = np.clip((n[:, 2] - low) / (high - low), 0, 1)[:, None]
    return np.asarray(S.hex_color(bottom)) * (1 - t) + np.asarray(S.hex_color(top)) * t


# --- The tree --------------------------------------------------------------------------

def tree(trunk_r, deck_z, roots=6, root_len=1.0, canopy=None, seed=1, broken=False):
    """Trunk with flaring roots up to the deck, then a leafy crown behind
    and above the house (north, +Y, so it never hides the door)."""
    rng = np.random.default_rng(seed)
    top = deck_z * (0.55 if broken else 1.02)
    shapes = [cone((0, 0, 0), (0, 0, top), trunk_r, trunk_r * 0.78, "bark", "trunk", blend=0.05)]
    for i in range(roots):
        a = i / roots * math.tau + rng.uniform(-0.25, 0.25)
        reach = root_len * rng.uniform(0.75, 1.1)
        end = (math.cos(a) * (trunk_r + reach), math.sin(a) * (trunk_r + reach), 0.02)
        shapes.append(cone((math.cos(a) * trunk_r * 0.5, math.sin(a) * trunk_r * 0.5, trunk_r * 0.7), end,
                           trunk_r * 0.42, trunk_r * 0.1, "bark", "trunk", blend=0.12))
    if broken:
        # Jagged splinters around the break.
        for i in range(5):
            a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
            base = (math.cos(a) * trunk_r * 0.55, math.sin(a) * trunk_r * 0.55, top * 0.9)
            tip = (math.cos(a) * trunk_r * 0.6, math.sin(a) * trunk_r * 0.6, top + rng.uniform(0.15, 0.4))
            shapes.append(cone(base, tip, trunk_r * 0.3, 0.02, "bark", "trunk", blend=0.03))
    trunk, _ = organic("trunk", shapes, lambda m: _shade(m, "#8a5a33", "#5c3a20", low=-0.6, high=0.6))
    trunk.data.materials.append(_mat("bark", "#7a4f2e", roughness=0.8, bands=("X", 9.0), seam=0.75,
                                     use_vertex_color=True))
    if canopy:
        leaves = [ellipsoid(c, r, "leaves", "tree", blend=0.08) for c, r in canopy]
        crown, _ = organic("leaves", leaves, lambda m: _shade(m, "#6cc04a", "#2f7a2a", low=-0.5, high=0.8),
                           voxel=0.035)
        crown.data.materials.append(_mat("leaves", "#5cae3c", roughness=0.7, use_vertex_color=True))


def _leaves(seed, center, spread, size, count):
    """A cloud of leafy clumps behind the house."""
    rng = np.random.default_rng(seed)
    blobs = []
    for i in range(count):
        a = i / count * math.tau
        offset = np.array([math.cos(a) * spread[0], rng.uniform(-1, 1) * spread[1], math.sin(a) * spread[2]])
        offset *= rng.uniform(0.55, 1.0)
        r = size * rng.uniform(0.75, 1.15)
        blobs.append((tuple(np.asarray(center) + offset), (r, r * 0.9, r * 0.85)))
    blobs.append((tuple(center), (spread[0] * 0.8, spread[1] + size * 0.6, spread[2] * 0.8)))
    return blobs


def deck(z, radius, wood, rail_mat, posts=12):
    cylinder((0, 0, z), radius, 0.14, wood, vertices=40, bevel=0.03)
    for i in range(posts):
        a = i / posts * math.tau
        cylinder((math.cos(a) * (radius - 0.07), math.sin(a) * (radius - 0.07), z + 0.2), 0.035, 0.3, rail_mat,
                 vertices=8)
    torus((0, 0, z + 0.34), radius - 0.07, 0.03, rail_mat)


def ladder(x, y_front, z_top, rope, rung):
    for side in (-0.13, 0.13):
        cylinder((x + side, y_front, z_top / 2), 0.018, z_top, rope, vertices=8)
    steps = int(z_top / 0.22)
    for i in range(1, steps):
        box((x, y_front, i * z_top / steps), (0.3, 0.04, 0.035), rung, bevel=0.008)


def cabin(center, size, walls, trim, roof_mat, roof_h, window, door=True, overhang=0.18):
    cx, cy, cz = center
    w, d, h = size
    box((cx, cy, cz + h / 2), (w, d, h), walls, bevel=0.04)
    # Corner posts.
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((cx + sx * w / 2, cy + sy * d / 2, cz + h / 2), (0.09, 0.09, h + 0.02), trim, bevel=0.015)
    roof((cx, cy, cz + h), w + overhang * 2, d + overhang * 2, roof_h, roof_mat)
    front = cy - d / 2 - 0.02
    if door:
        box((cx - w * 0.22, front, cz + 0.3), (0.28, 0.06, 0.56), trim, bevel=0.03)
    # A round glowing window.
    wx = cx + (w * 0.2 if door else 0.0)
    cylinder((wx, front, cz + h * 0.58), 0.17, 0.08, trim, rot=(math.pi / 2, 0, 0))
    cylinder((wx, front - 0.02, cz + h * 0.58), 0.125, 0.08, window, rot=(math.pi / 2, 0, 0))


def flag(base, height, team_mat, pole_mat, size=(0.7, 0.42)):
    x, y, z = base
    cylinder((x, y, z + height / 2), 0.03, height, pole_mat, vertices=10)
    sphere((x, y, z + height + 0.04), 0.06, pole_mat)
    box((x + size[0] / 2 + 0.02, y, z + height - size[1] / 2 - 0.04), (size[0], 0.03, size[1]), team_mat, bevel=0.01)


def crown(center, gold, jewel, size=1.0):
    """A gold crown: a band with five points, each tipped with a ball, and
    a jewel on the front."""
    x, y, z = center
    k = size
    cylinder((x, y, z + 0.09 * k), 0.24 * k, 0.18 * k, gold, vertices=32, bevel=0.01)
    for i in range(5):
        a = i / 5 * math.tau + math.pi / 2
        px, py = x + math.cos(a) * 0.2 * k, y + math.sin(a) * 0.2 * k
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.09 * k, radius2=0.0, depth=0.22 * k,
                                        location=(px, py, z + 0.29 * k), rotation=(0, 0, a + math.pi / 4))
        _finish(bpy.context.object, gold)
        sphere((px, py, z + 0.41 * k), 0.035 * k, gold)
    sphere((x, y - 0.24 * k, z + 0.09 * k), 0.055 * k, jewel)


def lantern(at, glow, iron):
    x, y, z = at
    cylinder((x, y, z + 0.28), 0.02, 0.5, iron, vertices=8)
    sphere((x, y, z + 0.58), 0.1, glow)


# --- The dens --------------------------------------------------------------------------

def side_den(team):
    wood, walls = _mat("deck", "#b9824c", bands=("X", 7.0)), _mat("walls", "#d9a066", bands=("Z", 6.0))
    trim, rope = _mat("trim", "#7a4a26"), _mat("rope", "#c9a46a", roughness=0.9)
    roof_mat = _mat("roof", TEAMS[team], roughness=0.5, bands=("Z", 7.0), seam=0.7)
    window = _mat("window", "#ffc860", emission=1.2)
    deck_z = 1.45
    tree(0.5, deck_z, roots=6, root_len=0.85, seed=3, canopy=_leaves(seed=3, center=(0, 1.35, 2.75), spread=(1.25, 0.45, 0.8),
                                                                     size=0.5, count=11))
    deck(deck_z, 1.2, wood, trim)
    cabin((0, 0.0, deck_z + 0.07), (1.15, 0.95, 1.0), walls, trim, roof_mat, 0.95, window)
    ladder(0.55, -1.12, deck_z, rope, wood)
    flag((0.0, 0.0, deck_z + 0.07 + 1.0 + 0.85), 0.55, roof_mat, trim, size=(0.45, 0.28))


def main_den(team):
    wood, walls = _mat("deck", "#b9824c", bands=("X", 7.0)), _mat("walls", "#e0aa6c", bands=("Z", 6.0))
    trim, gold = _mat("trim", "#6e4222"), _mat("gold", GOLD, roughness=0.3, metallic=0.6)
    roof_mat = _mat("roof", TEAMS[team], roughness=0.5, bands=("Z", 7.0), seam=0.7)
    window = _mat("window", "#ffc860", emission=1.4)
    glow = _mat("lantern", "#ffd36b", emission=3.0)
    rope = _mat("rope", "#c9a46a", roughness=0.9)
    deck_z = 1.55
    tree(0.75, deck_z, roots=8, root_len=1.15, seed=7, canopy=_leaves(seed=7, center=(0, 1.75, 3.4), spread=(1.75, 0.55, 1.1),
                                                                      size=0.62, count=15))
    deck(deck_z, 1.65, wood, trim, posts=16)
    floor1 = deck_z + 0.07
    cabin((0, 0.12, floor1), (1.75, 1.3, 1.0), walls, trim, roof_mat, 0.45, window)
    # Second story with its own tall roof, and gold trim along the eaves.
    floor2 = floor1 + 1.0 + 0.2
    box((0, 0.12, floor2 - 0.1), (1.5, 1.05, 0.2), wood, bevel=0.03)
    cabin((0, 0.15, floor2), (1.15, 0.85, 0.75), walls, trim, roof_mat, 0.95, window, door=False)
    for z, w, d in ((floor1 + 1.0, 1.75 + 0.36, 1.3 + 0.36), (floor2 + 0.75, 1.15 + 0.36, 0.85 + 0.36)):
        box((0, 0.12, z + 0.02), (w, d, 0.06), gold, bevel=0.015)
    crown((0.0, 0.15, floor2 + 0.75 + 0.95 - 0.12), gold, _mat("jewel", TEAMS[team], roughness=0.15), size=1.6)
    flag((1.3, -0.75, deck_z + 0.07), 2.4, roof_mat, gold, size=(0.85, 0.5))
    for a in (math.radians(215), math.radians(325)):
        lantern((math.cos(a) * 1.5, math.sin(a) * 1.5, deck_z + 0.07), glow, trim)
    ladder(0.85, -1.58, deck_z, rope, wood)


def ruin(kind):
    big = kind == "main"
    wood, trim = _mat("deck", "#8a6440", bands=("X", 7.0)), _mat("trim", "#5a3a20")
    tree(0.75 if big else 0.5, 1.55 if big else 1.45, roots=8 if big else 6, root_len=1.15 if big else 0.85,
         seed=7 if big else 3, broken=True)
    # The fallen roof, faded, and a broken piece of deck leaning on the stump.
    fallen = roof((0, 0, 0), 1.3 if big else 1.0, 1.1 if big else 0.9, 0.7 if big else 0.55,
                  _mat("old_roof", "#857265", roughness=0.7, bands=("Z", 7.0), seam=0.7))
    fallen.location = (-0.75 if big else -0.6, -0.55, 0.1)
    fallen.rotation_euler = (0.35, -0.5, 0.4)
    piece = box((0.55, -0.35, 0.45), (1.1 if big else 0.85, 0.5, 0.1), wood, bevel=0.02)
    piece.rotation_euler = (0.2, -0.75, -0.3)
    rng = np.random.default_rng(11)
    for i in range(7 if big else 5):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.8, 1.6 if big else 1.25)
        box((math.cos(a) * r, math.sin(a) * r, 0.04), (rng.uniform(0.5, 0.9), 0.16, 0.06), wood if i % 2 else trim,
            bevel=0.01, rot_z=rng.uniform(0, math.pi))


# --- Rendering -------------------------------------------------------------------------

def render(build, out_path, samples):
    sc = S.reset()
    sc.cycles.samples = samples
    build()
    S.lights(1.05)
    S.shadow_catcher(12)
    S.outline(3.0)
    points = np.concatenate([np.array([o.matrix_world @ v.co for v in o.data.vertices])
                             for o in bpy.context.scene.objects if o.type == "MESH" and o.name != "ground"])
    lo, hi = points.min(axis=0), points.max(axis=0)
    height = float(hi[2])
    extent = float(max(hi[0] - lo[0], hi[1] - lo[1], height))
    side = int(math.ceil(extent * 1.45 * PIXELS_PER_TILE / 2)) * 2
    target_z = height * 0.42
    S.ortho_camera(ELEVATION, side / PIXELS_PER_TILE, target=(0, 0, target_z))
    sc.render.resolution_x = sc.render.resolution_y = side
    tmp = os.path.join(tempfile.gettempdir(), "_den.png")
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    im = clean_alpha(np.asarray(Image.open(tmp).convert("RGBA")))
    os.remove(tmp)
    anchor = (side / 2, side / 2 + target_z * math.cos(math.radians(ELEVATION)) * PIXELS_PER_TILE)
    ys, xs = np.nonzero(im[:, :, 3] > 6)
    x0, x1, y0, y1 = max(xs.min() - 2, 0), min(xs.max() + 3, side), max(ys.min() - 2, 0), min(ys.max() + 3, side)
    Image.fromarray(im[y0:y1, x0:x1]).save(out_path, "WEBP", quality=92, method=6)
    solid = np.nonzero((im[:, :, 3] > 60).any(axis=1))[0]
    return {"anchor": [round(anchor[0] - x0, 1), round(anchor[1] - y0, 1)],
            "top": round(float(anchor[1] - solid[0]), 1)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=os.path.join(HERE, "..", "..", "game", "art", "towers"))
    parser.add_argument("--samples", type=int, default=48)
    parser.add_argument("--only", help="comma-separated names, e.g. main_blue")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    jobs = {f"{kind}_{team}": (lambda k=kind, t=team: (side_den if k == "side" else main_den)(t))
            for kind in ("side", "main") for team in TEAMS}
    jobs.update({f"{kind}_ruin": (lambda k=kind: ruin(k)) for kind in ("side", "main")})
    meta_path = os.path.join(args.out, "towers.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta["pixels_per_tile"] = PIXELS_PER_TILE
    for name, build in jobs.items():
        if args.only and name not in args.only.split(","):
            continue
        meta[name] = render(build, os.path.join(args.out, name + ".webp"), args.samples)
        print(name, meta[name], flush=True)
    with open(meta_path, "w") as fh:
        json.dump(meta, fh, indent=1)


if __name__ == "__main__":
    main()
