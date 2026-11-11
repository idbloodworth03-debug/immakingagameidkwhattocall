"""Our own animals in the art packs' flat toy style, built by code.

A toy is a few round shapes melted into one smooth body (the shape kit of
tools/creatures: sdf.py), painted in flat colors whose patches end in crisp
edges, with button eyes that can blink, a nose, and the skeleton and
animations our animals already have (tools/creatures: anatomy.py,
motion.py). The art packs are the reference for the style: big simple
forms, stick legs, a few bold color patches, a button eye. No pack mesh is
copied or traced: every shape here is written out in the animal's design
file (animals/<id>.py).

build.py writes each toy as glTF files (mesh, rig, clips, eye blendshapes,
a flat material per color; one file per level of detail) into
art_sources/own/, and from there it comes into the game the same way a
pack animal does (tools/packs: packs.json has a pack "own").

Coordinates match tools/creatures: the animal faces +Y with +Z up, meters.
"""
import math
import os
import sys
from dataclasses import dataclass, field

HERE = os.path.dirname(os.path.abspath(__file__))
CREATURES = os.path.normpath(os.path.join(HERE, "..", "creatures"))
for path in (CREATURES, os.path.join(CREATURES, "species")):
    if path not in sys.path:
        sys.path.insert(0, path)

import bpy
import numpy as np

import export_gltf as X
import motion
import scene as S
from sdf import Mesh, attribute, bone_weights, build_mesh, field_normals, rotation, surface_point

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "art_sources", "own"))
# The blendshapes the game's faces use (game/data/viewer.json "toon_look"
# "faces"), named as the first pack's so one table serves both.
BLINK, ANNOYED, SLEEP, SHRINK, HAPPY = "eyes.blink", "eyes.annoyed", "eyes.sleep", "eyes.shrink", "eyes.happy"
SPIN = ("eyes.spin-1", "eyes.spin-2", "eyes.spin-3")


@dataclass
class Eye:
    """A button eye on the body's surface: a white disc with a big dark
    pupil and a glint. `toward`: the way from `origin` (inside the head) to
    where it sits; the other eye mirrors it across x."""
    origin: tuple
    toward: tuple
    radius: float
    pupil: float = 0.68          # the pupil's size, a share of the white's
    glint: float = 0.3           # the glint's size, a share of the pupil's (0: none)
    bulge: float = 0.3           # how far the disc domes out, a share of its radius
    bone: str = "head"
    white: str = "eye_white"
    dark: str = "pupil"


@dataclass
class Piece:
    """A solid little part of its own: a nose."""
    center: tuple
    radii: tuple
    color: str
    bone: str = "head"
    yaw: float = 0.0
    pitch: float = 0.0


@dataclass
class Toy:
    name: str                    # its files in art_sources/own: <name>_LOD<n>.glb
    creature: object             # tools/creatures Creature: joints, bones, shapes, how it moves
    colors: dict                 # name -> "#rrggbb"
    base: str                    # the color the whole body starts as
    patches: list = field(default_factory=list)   # (color, field): painted in order, each with a crisp edge
    eyes: list = field(default_factory=list)
    pieces: list = field(default_factory=list)
    # Per level of detail (0: the 3D viewer and the renders; 1: fights):
    # the body's triangles before the patches' edges are cut in, and the
    # longest edge a patch's edge may cross (meters).
    triangles: tuple = (9000, 2600)
    longest: tuple = (0.03, 0.05)
    voxel: float = 0.006


class Surface:
    """Points on the body, for a patch's field: `v` (their positions),
    `n` (the way the surface faces there) and part(...) (0-1: how much each
    point belongs to those of the body's shapes' regions). A field returns
    a number per point, above 0 inside the patch; its edge is where it
    crosses 0."""

    def __init__(self, shapes, points, softness):
        self.shapes = shapes
        self.v = np.asarray(points, float)
        self._softness = softness
        self._mesh = None
        self._n = None

    @property
    def n(self):
        if self._n is None:
            self._n = field_normals(self.shapes, self.v, self._softness / 3.0)
        return self._n

    def part(self, *regions):
        if self._mesh is None:
            self._mesh = Mesh(self.v, np.zeros((0, 3), int), None, shapes=self.shapes)
            attribute(self._mesh, self._softness)
        return sum(self._mesh.region_weight(r) for r in regions)

    def within(self, center, radii, yaw=0.0, pitch=0.0):
        """Above 0 inside an ellipsoid (1 at its center, 0 on its skin)."""
        local = (self.v - np.asarray(center, float)) @ rotation(yaw, pitch)
        return 1.0 - np.linalg.norm(local / np.asarray(radii, float), axis=1)

    def beyond(self, point, direction):
        """Above 0 past the plane through `point` facing `direction` (meters)."""
        d = np.asarray(direction, float)
        return (self.v - np.asarray(point, float)) @ (d / np.linalg.norm(d))


# --- The body: meshing, crisp patches ------------------------------------------

def _decimate(verts, faces, triangles):
    """The mesh cut down to about `triangles` triangles (marching cubes
    makes far more, and far smaller, than a toy needs), with its doubled
    points and empty triangles cleaned away first."""
    import bmesh
    me = bpy.data.meshes.new("_toy_cut")
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me)
    count = len(bm.faces)
    bm.free()
    ob = bpy.data.objects.new("_toy_cut", me)
    bpy.context.scene.collection.objects.link(ob)
    if count > triangles:
        mod = ob.modifiers.new("cut", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = triangles / count
        mod.use_collapse_triangulate = True
    deps = bpy.context.evaluated_depsgraph_get()
    cut_me = ob.evaluated_get(deps).to_mesh()
    v = np.empty(len(cut_me.vertices) * 3)
    cut_me.vertices.foreach_get("co", v)
    cut_me.calc_loop_triangles()
    f = np.empty(len(cut_me.loop_triangles) * 3, int)
    cut_me.loop_triangles.foreach_get("vertices", f)
    ob.evaluated_get(deps).to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.meshes.remove(me)
    return _solid(v.reshape(-1, 3).copy(), f.reshape(-1, 3).copy())


def _solid(verts, faces):
    """Without triangles that have no area."""
    a, b, c = (verts[faces[:, i]] for i in range(3))
    area = np.linalg.norm(np.cross(b - a, c - a), axis=1)
    return verts, faces[area > 1e-14]


def split(verts, faces, marked):
    """Halves every edge in `marked` (pairs of vertex numbers, the lower
    first), splitting the triangles on it so the mesh stays whole. Returns
    the new vertices and faces."""
    if not marked:
        return verts, faces
    mid = {}
    new_verts = [verts]
    count = len(verts)
    for key in marked:
        mid[key] = count
        new_verts.append(((verts[key[0]] + verts[key[1]]) / 2)[None, :])
        count += 1
    out = []
    keep = np.ones(len(faces), bool)
    for index, tri in enumerate(faces):
        A, B, C = (int(i) for i in tri)
        m = [mid.get((min(p, q), max(p, q))) for p, q in ((A, B), (B, C), (C, A))]
        n = sum(k is not None for k in m)
        if n == 0:
            continue
        keep[index] = False
        if n == 3:
            out += [(A, m[0], m[2]), (m[0], B, m[1]), (m[2], m[1], C), (m[0], m[1], m[2])]
        elif n == 1:
            k = next(i for i in range(3) if m[i] is not None)
            P, Q, R = (A, B, C)[k], (A, B, C)[(k + 1) % 3], (A, B, C)[(k + 2) % 3]
            out += [(P, m[k], R), (m[k], Q, R)]
        else:
            # Two halved edges meet at one corner: it keeps a small
            # triangle, the rest is split from the first midpoint.
            k = next(i for i in range(3) if m[i] is None)
            P, Q, R = (A, B, C)[(k + 2) % 3], (A, B, C)[k], (A, B, C)[(k + 1) % 3]
            pq, rp = m[(k + 2) % 3], m[(k + 1) % 3]
            out += [(P, pq, rp), (pq, Q, R), (pq, R, rp)]
    faces = np.concatenate([faces[keep], np.array(out, int).reshape(-1, 3)])
    return np.concatenate(new_verts), faces


def refine(verts, faces, patch, shapes, softness, longest, rounds=6):
    """Halves edges until the mesh is fine enough for a patch's edge to be
    cut into it well: an edge the patch's edge crosses is no longer than
    `longest` (a curved edge cut across big triangles would come out in
    straight stretches), and no edge or triangle hides a piece of the
    patch between corners that are all outside it (or all inside)."""
    for _ in range(rounds):
        f = patch(Surface(shapes, verts, softness))
        edges = np.unique(np.sort(np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]), axis=1), axis=0)
        a, b = edges[:, 0], edges[:, 1]
        length = np.linalg.norm(verts[a] - verts[b], axis=1)
        middle = patch(Surface(shapes, (verts[a] + verts[b]) / 2, softness))
        crossing = (f[a] > 0) != (f[b] > 0)
        hidden = ~crossing & ((middle > 0) != (f[a] > 0))
        marked = {(int(p), int(q)) for p, q in edges[(crossing & (length > longest)) | (hidden & (length > longest * 0.5))]}
        center = patch(Surface(shapes, verts[faces].mean(axis=1), softness))
        inside = f[faces] > 0
        odd = (inside.all(axis=1) & (center <= 0)) | (~inside.any(axis=1) & (center > 0))
        for tri in faces[odd]:
            for p, q in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
                if np.linalg.norm(verts[p] - verts[q]) > longest * 0.5:
                    marked.add((int(min(p, q)), int(max(p, q))))
        if not marked:
            break
        verts, faces = split(verts, faces, marked)
    return verts, faces


def cut(verts, faces, values, snap=0.06):
    """Splits every triangle that the line where `values` (one number per
    vertex) crosses 0 runs through, along that line, so the line becomes
    edges of the mesh: a color can then end exactly on it. A vertex the
    line passes within `snap` of an edge's length of counts as on it (no
    sliver triangles). Returns the new vertices and faces."""
    f = np.array(values, float)
    edges = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]])
    a, b = edges[:, 0], edges[:, 1]
    crossing = f[a] * f[b] < 0
    t = np.where(crossing, f[a] / np.where(crossing, f[a] - f[b], 1.0), 0.5)
    f[a[crossing & (t < snap)]] = 0.0
    f[b[crossing & (t > 1.0 - snap)]] = 0.0
    new_verts = [verts]
    made = {}
    count = len(verts)

    def split(i, j):
        """The vertex where the line crosses the edge i-j."""
        nonlocal count
        key = (i, j) if i < j else (j, i)
        if key not in made:
            k = f[i] / (f[i] - f[j])
            new_verts.append((verts[i] + (verts[j] - verts[i]) * k)[None, :])
            made[key] = count
            count += 1
        return made[key]

    sign = np.sign(f)
    out = []
    keep = np.ones(len(faces), bool)
    s = sign[faces]
    touched = np.nonzero((s.max(axis=1) > 0) & (s.min(axis=1) < 0))[0]
    for index in touched:
        tri = faces[index]
        sg = sign[tri]
        keep[index] = False
        zero = np.nonzero(sg == 0)[0]
        if len(zero) == 1:
            # The line leaves through a corner: two triangles.
            k = int(zero[0])
            A, B, C = int(tri[k]), int(tri[(k + 1) % 3]), int(tri[(k + 2) % 3])
            P = split(B, C)
            out += [(A, B, P), (A, P, C)]
            continue
        # One corner alone on its side: it keeps a small triangle, the
        # other two share the rest.
        k = int(np.nonzero(sg == -np.sign(sg.sum()))[0][0])
        A, B, C = int(tri[k]), int(tri[(k + 1) % 3]), int(tri[(k + 2) % 3])
        P, Q = split(A, B), split(A, C)
        out += [(A, P, Q), (P, B, C), (P, C, Q)]
    faces = np.concatenate([faces[keep], np.array(out, int).reshape(-1, 3)])
    return np.concatenate(new_verts), faces


def body(toy, lod=0):
    """The toy's body at a level of detail: (vertices, faces, each face's
    color name, each vertex's normal, {bone: each vertex's weight})."""
    c = toy.creature
    softness = toy.voxel * 3
    mesh = build_mesh(c.shapes, voxel=toy.voxel)
    verts, faces = _decimate(mesh.verts, mesh.faces, toy.triangles[lod])
    for _, patch in toy.patches:
        verts, faces = refine(verts, faces, patch, c.shapes, softness, toy.longest[lod])
        verts, faces = cut(verts, faces, patch(Surface(c.shapes, verts, softness)))
    verts, faces = _solid(verts, faces)
    surface = Surface(c.shapes, verts, softness)
    color = np.full(len(faces), toy.base, dtype=object)
    for name, patch in toy.patches:
        inside = patch(surface)[faces].mean(axis=1) > 0
        color[inside] = name
    skin = Mesh(verts, faces, surface.n, shapes=c.shapes)
    attribute(skin, softness)
    return verts, faces, color, surface.n, bone_weights(skin)


# --- Eyes and other little pieces ------------------------------------------------

def _ball(center, axes, radii, segments=20, rings=10):
    """An ellipsoid's vertices, faces and normals; `axes`: 3x3, its own x,
    y and z as columns."""
    center = np.asarray(center, float)
    radii = np.asarray(radii, float)
    pts, nrm = [(0.0, 0.0, 1.0)], [(0.0, 0.0, 1.0)]
    for r in range(1, rings):
        phi = math.pi * r / rings
        for s in range(segments):
            th = 2 * math.pi * s / segments
            p = (math.sin(phi) * math.cos(th), math.sin(phi) * math.sin(th), math.cos(phi))
            pts.append(p)
            nrm.append(p)
    pts.append((0.0, 0.0, -1.0))
    nrm.append((0.0, 0.0, -1.0))
    unit = np.array(pts)
    local = unit * radii
    normal = unit / radii
    normal /= np.linalg.norm(normal, axis=1, keepdims=True)
    faces = []
    for s in range(segments):
        faces.append((0, 1 + s, 1 + (s + 1) % segments))
    for r in range(rings - 2):
        for s in range(segments):
            a = 1 + r * segments + s
            b = 1 + r * segments + (s + 1) % segments
            c2 = a + segments
            d = b + segments
            faces += [(a, c2, d), (a, d, b)]
    last = len(unit) - 1
    base = 1 + (rings - 2) * segments
    for s in range(segments):
        faces.append((last, base + (s + 1) % segments, base + s))
    return local @ axes.T + center, np.array(faces, int), normal @ axes.T, local


def _eye_frame(direction):
    """An eye's own axes as columns: x across it (to the animal's front or
    midline side), y up it, z out of the head."""
    out = np.asarray(direction, float)
    out = out / np.linalg.norm(out)
    up = np.array([0.0, 0.0, 1.0]) - out * out[2]
    up /= np.linalg.norm(up)
    across = np.cross(up, out)
    return np.stack([across, up, out], axis=1)


def eye_parts(toy, eye, side, lod=0):
    """One eye (side: -1 the animal's left, 1 its right) as parts: each
    (vertices, faces, normals, color, {blendshape: vertices})."""
    c = toy.creature
    # (`toward` and `origin` are the left eye's, x < 0; the right mirrors.)
    d = np.array([eye.toward[0] * -side, eye.toward[1], eye.toward[2]], float)
    d /= np.linalg.norm(d)
    origin = np.array([eye.origin[0] * -side, eye.origin[1], eye.origin[2]], float)
    at = surface_point(c.shapes, origin, d)
    axes = _eye_frame(d)
    R = eye.radius
    depth = R * eye.bulge
    parts = []
    # (name, radius across and up, how far it stands out, its center out of the surface)
    discs = [(eye.white, R, depth, 0.0), (eye.dark, R * eye.pupil, depth * 0.9, depth * 0.45)]
    if eye.glint > 0:
        g = R * eye.pupil * eye.glint
        discs.append((eye.white, g, depth * 0.5, depth * 1.05))
    for index, (color, r, out, lift) in enumerate(discs):
        center = at + axes[:, 2] * lift
        offset = np.zeros(3)
        if index == 2:
            # The glint sits up and toward the front of the pupil.
            offset = axes[:, 0] * (R * eye.pupil * 0.36 * side) + axes[:, 1] * (R * eye.pupil * 0.36)
        segments, rings = ((20, 8), (10, 6)) if lod == 0 else ((12, 6), (8, 4))
        verts, faces, normals, local = _ball(center + offset, axes, (r, r, out), segments=segments[0 if index < 2 else 1],
                                             rings=rings[0 if index < 2 else 1])
        shapes = {}

        def placed(xyz, c0=center + offset):
            return xyz @ axes.T + c0

        x, y, z = local[:, 0], local[:, 1], local[:, 2]
        if index == 0:
            # The white: it closes with the lid.
            shapes[BLINK] = placed(np.stack([x, y * 0.06, z * 0.5], axis=1))
            shapes[HAPPY] = placed(np.stack([x, y * 0.06 + (r * 0.45) * (1 - (x / r) ** 2) - r * 0.2, z * 0.5], axis=1))
            shapes[SLEEP] = placed(np.stack([x, np.minimum(y, r * 0.05), z], axis=1))
            shapes[ANNOYED] = placed(np.stack([x, np.minimum(y, r * 0.35 + x * 0.45 * -side), z], axis=1))
        elif index == 1:
            # The pupil: a blink is a dark line as wide as the eye.
            wide = R / r
            shapes[BLINK] = placed(np.stack([x * wide, y * 0.1, z * 0.7], axis=1))
            shapes[HAPPY] = placed(np.stack([x * wide, y * 0.1 + (R * 0.45) * (1 - (x / r) ** 2) - R * 0.2, z * 0.7], axis=1))
            shapes[SLEEP] = placed(np.stack([x, np.minimum(y, R * 0.05), z], axis=1))
            shapes[ANNOYED] = placed(np.stack([x, np.minimum(y, R * 0.35 + x * 0.45 * -side), z], axis=1))
            shapes[SHRINK] = placed(local * np.array([0.6, 0.6, 1.0]))
            for k, name in enumerate(SPIN):
                # Dizzy: a small pupil rolling round the white.
                ang = 2 * math.pi * k / len(SPIN) + 0.5
                roll = np.array([math.cos(ang), math.sin(ang), 0.0]) * (R - r * 0.55) * 0.8
                shapes[name] = placed(local * np.array([0.55, 0.55, 1.0]) + roll)
        else:
            # The glint goes when the eye closes.
            hidden = placed(local * 0.02 - np.array([0.0, 0.0, depth * 1.2])) - offset
            for name in (BLINK, HAPPY, SLEEP, ANNOYED) + SPIN:
                shapes[name] = hidden
        parts.append((verts, faces, normals, color, shapes))
    return parts


def piece_part(piece, lod=0):
    axes = rotation(piece.yaw, piece.pitch)
    verts, faces, normals, _ = _ball(piece.center, axes, piece.radii, segments=16 if lod == 0 else 10,
                                     rings=10 if lod == 0 else 6)
    return verts, faces, normals, piece.color


# --- Putting it together -----------------------------------------------------------

def _material(name, hex_color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = tuple(S.hex_color(hex_color)) + (1.0,)
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def assemble(toy, lod=0):
    """The toy in the scene at a level of detail: its armature and one mesh
    (the body, its pieces and its eyes), a flat material per color, the
    eyes' blendshapes. Returns (armature, mesh object)."""
    c = toy.creature
    arm = S._armature(c)
    root = c.joints["root"]
    arm["rest_offset"] = (-root[0], -root[1], float(c.motion.get("altitude", 0.0)))
    arm.location = arm["rest_offset"]

    verts, faces, color, normals, weights = body(toy, lod)
    all_v, all_f, all_n, all_c = [verts], [faces], [normals], [color]
    groups = {name: [w] for name, w in weights.items()}
    keys = {}
    count = len(verts)

    def add(v, f, n, col, bone, shapes=None):
        nonlocal count
        all_v.append(v)
        all_f.append(f + count)
        all_n.append(n)
        all_c.append(np.full(len(f), col, dtype=object))
        for name, parts in groups.items():
            parts.append(np.ones(len(v)) if name == bone else np.zeros(len(v)))
        if bone not in groups:
            groups[bone] = [np.zeros(count), np.ones(len(v))]
        for name, moved in (shapes or {}).items():
            keys.setdefault(name, []).append((count, moved))
        count += len(v)

    for piece in toy.pieces:
        v, f, n, col = piece_part(piece, lod)
        add(v, f, n, col, piece.bone)
    for eye in toy.eyes:
        for side in (-1, 1):
            for v, f, n, col, shapes in eye_parts(toy, eye, side, lod):
                add(v, f, n, col, eye.bone, shapes)

    verts = np.concatenate(all_v)
    faces = np.concatenate(all_f)
    normals = np.concatenate(all_n)
    color = np.concatenate(all_c)
    me = bpy.data.meshes.new(toy.name)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.update()
    names = list(dict.fromkeys([toy.base] + [n for n, _ in toy.patches] + list(color)))
    for name in names:
        me.materials.append(_material(name, toy.colors[name]))
    index = {name: i for i, name in enumerate(names)}
    me.polygons.foreach_set("material_index", [index[n] for n in color])
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    # Lit by the shapes' own smooth surface, not by the triangles it was
    # cut down to: no dents where the mesh is coarse, and both sides of a
    # color's edge face the same way (the game's outline is the mesh pushed
    # out along these, and must not tear there).
    me.normals_split_custom_set_from_vertices(normals.tolist())
    ob = bpy.data.objects.new(toy.name, me)
    bpy.context.scene.collection.objects.link(ob)
    for name, parts in groups.items():
        w = np.concatenate(parts)
        vg = ob.vertex_groups.new(name=name)
        for i in np.nonzero(w > 0.01)[0]:
            vg.add([int(i)], float(w[i]), "REPLACE")
    if keys:
        ob.shape_key_add(name="Basis")
        for name, moves in keys.items():
            kb = ob.shape_key_add(name=name)
            co = verts.copy()
            for start, moved in moves:
                co[start:start + len(moved)] = moved
            kb.data.foreach_set("co", co.ravel())
    mod = ob.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    ob.parent = arm
    print(f"[toy] {toy.name} LOD{lod}: {len(faces)} triangles ({len(all_f[0])} the body), {len(verts)} vertices, "
          f"{len(names)} colors, {len(keys)} blendshapes")
    return arm, ob


def bake(toy, arm):
    """Every animation the game plays, as actions (tools/creatures'
    motion, sampled as its own models are), plus "hero": the card pose."""
    c = toy.creature
    motion.ANIMATIONS["hero"] = (lambda creature, t: motion.portrait_pose(creature), 2, 2, False)
    X.LOD.clear()
    X.LOD.update({"animations": ["idle", "walk", "attack", "attack2", "special", "fidget", "victory", "hero"]})
    try:
        X.bake(c, arm)
    finally:
        X.LOD.clear()
        del motion.ANIMATIONS["hero"]
    return [a.name for a in bpy.data.actions]


def export(toy, out_dir=OUT):
    """Writes <name>_LOD0.glb (the 3D viewer's and the renders' detail) and
    <name>_LOD1.glb (fights'): the same rig and clips on both."""
    paths = []
    for lod in range(len(toy.triangles)):
        S.reset()
        arm, ob = assemble(toy, lod)
        made = bake(toy, arm)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, f"{toy.name}_LOD{lod}.glb")
        bpy.ops.object.select_all(action="DESELECT")
        arm.select_set(True)
        ob.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", use_selection=True,
            export_normals=True, export_texcoords=False, export_materials="EXPORT",
            export_skins=True, export_def_bones=True, export_animations=True,
            export_animation_mode="ACTIONS", export_force_sampling=True,
            export_optimize_animation_size=True, export_yup=True, export_apply=False,
            export_morph=True, export_morph_normal=False, export_morph_tangent=False,
            export_extras=False, export_cameras=False, export_lights=False)
        print(f"[toy] {toy.name} LOD{lod}: clips {', '.join(made)}; wrote {path} ({os.path.getsize(path) / 1024:.0f} KB)")
        paths.append(path)
    return paths
