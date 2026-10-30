"""The cartoon look: takes a species built to real proportions and turns it
into a cartoon of itself, still modeled and lit in 3D. The legs and body get
shorter and the torso rounder, the muzzle shorter and the head (with
everything on it: jaw, ears, trunk, horns) bigger, the eyes become big
googly ones, hair strands give way to smooth skin in brighter colors, and
the renderer draws a dark outline (see scene.outline).

The species' own paint still decides the coat: each vertex is painted where
it would have been on the real-proportioned animal.

    import cartoon
    creature = cartoon.load("red_fox")
"""
import copy
import importlib

import numpy as np

from anatomy import Extra
from sdf import surface_point

HEAD = 1.9        # head size
MUZZLE = 0.62     # muzzle length (before the head grows)
EYES = 2.5        # eye size, on top of the head's growth
EARS = 1.1        # ear size on top of the head's growth (thicker and rounder too)
LEGS = 0.75       # leg length; thickness stays, so they get stubby
LENGTH = 0.72     # body length
BELLY = 1.1       # torso thickness
LIMBS = 1.35      # leg thickness

TORSO_REGIONS = ("torso", "chest", "belly", "rump", "shoulder", "thigh")


def load(species, style="cartoon"):
    creature = importlib.import_module(species).make()
    if style == "cartoon":
        cartoonify(creature)
    return creature


def cartoonify(c):
    """A species can tune its cartoon by setting c.cartoon, e.g.
    {"head": 1.3} for an animal whose head is already big, or
    {"face_mane": True} for a mane that frames the face and so grows with it."""
    global HEAD, MUZZLE, EYES, EARS, LEGS, LENGTH, BELLY, LIMBS
    defaults = dict(HEAD=HEAD, MUZZLE=MUZZLE, EYES=EYES, EARS=EARS, LEGS=LEGS, LENGTH=LENGTH, BELLY=BELLY,
                    LIMBS=LIMBS)
    tuned = {k.upper(): v for k, v in (getattr(c, "cartoon", None) or {}).items() if k != "face_mane"}
    HEAD, MUZZLE, EYES, EARS, LEGS, LENGTH, BELLY, LIMBS = (tuned.get(k, v) for k, v in defaults.items())
    try:
        _cartoonify(c)
    finally:
        HEAD, MUZZLE, EYES, EARS, LEGS, LENGTH, BELLY, LIMBS = defaults.values()


def _cartoonify(c):
    c.style = "cartoon"
    # Solid, puffy ears: no hollow cup.
    for part in c.parts:
        part["shapes"] = [s for s in part["shapes"] if not s.subtract]
    original = copy.deepcopy(c)
    before = {id(s): copy.deepcopy(s) for s in _all_shapes(c)}
    heads = _descendants(c, "head")
    head_joints = {j for b in c.bones if b.name in heads for j in (b.head, b.tail)} | {"skull"}

    if c.motion.get("body") != "bird":
        # Shorter legs (the body comes down to meet them) and a shorter body.
        z_belly = np.mean([c.joints[j][2] for j in ("elbow.L", "knee.L") if j in c.joints])
        y_mid = c.joints["spine_mid"][1]

        def squash(p):
            p = np.array(p, float)
            z = p[..., 2]
            p[..., 2] = np.where(z < z_belly, z * LEGS, z - (1 - LEGS) * z_belly)
            p[..., 1] = y_mid + (p[..., 1] - y_mid) * LENGTH
            return p
        _warp(c, squash)
        for s in c.shapes:
            if s.region in TORSO_REGIONS:
                _thicken(s, BELLY)
            elif (s.bone or "").startswith(("fl_", "hl_")):
                _thicken(s, LIMBS)

    # The head itself (with jaw and ears) gets a shorter muzzle and grows
    # from where it meets the neck. Things hanging off it, like a trunk,
    # move with it but keep their length. A mane grows with the face.
    core = {b for b in heads if b in ("head", "jaw") or b.startswith("ear")}
    hanging = heads - core
    core_joints = {j for b in c.bones if b.name in core for j in (b.head, b.tail)} | {"skull"}
    skull_y = c.joints["skull"][1] if "skull" in c.joints else c.joint(_bone(c, "head").head)[1]
    pivot = c.joint(_bone(c, "head").head)

    def muzzle(p):
        p = np.array(p, float)
        y = p[..., 1]
        p[..., 1] = np.where(y > skull_y, skull_y + (y - skull_y) * MUZZLE, y)
        return p

    def grow(p):
        return pivot + (np.array(p, float) - pivot) * HEAD

    def head_move(p):
        return grow(muzzle(p))

    chains = []
    for root in [b for b in c.bones if b.name in hanging and b.parent in core]:
        start = c.joint(root.head)
        chain = _descendants(c, root.name)
        joints = {j for b in c.bones if b.name in chain for j in (b.head, b.tail)} - core_joints
        chains.append((chain, joints, head_move(start) - start))
    _warp(c, head_move, bones=core, joints=core_joints - {_bone(c, "head").head})
    face_mane = (getattr(c, "cartoon", None) or {}).get("face_mane", False)
    for s in c.shapes:
        if face_mane and s.region == "mane" and s.bone not in core:
            s.a = grow(s.a)
            if s.kind in ("cone", "plate"):
                s.b = grow(s.b)
            _thicken(s, HEAD)
    for chain, joints, shift in chains:
        _warp(c, lambda p, d=shift: np.array(p, float) + d, bones=chain, joints=joints)
        for s in _all_shapes(c):
            if s.bone in chain:
                _thicken(s, HEAD ** 0.5)
    for s in _all_shapes(c):
        if s.bone in core:
            if s.subtract and s.kind == "ellipsoid":
                # A carved mouth gets wider and longer but its gap stays.
                s.radii = s.radii * np.array([HEAD, HEAD, 1.0])
            else:
                _thicken(s, HEAD)
                s.blend *= HEAD
    for e in c.extras:
        if e.bone in core:
            e.radius = (e.radius or 0.0) * HEAD
            e.tip_radius = (e.tip_radius or 0.0) * HEAD
            if e.radii is not None:
                e.radii = tuple(r * HEAD for r in e.radii)
    # Bigger, chunkier ears, grown from their base.
    for b in c.bones:
        if b.name.startswith("ear"):
            base = c.joint(b.head)
            for part in c.parts:
                if part.get("bone") == b.name:
                    for s in part["shapes"]:
                        for key in ("a", "b", "radii") if s.kind == "plate" else ("a", "b"):
                            if getattr(s, key) is not None:
                                setattr(s, key, base + (np.asarray(getattr(s, key)) - base) * EARS)
                        s.ra *= 2.5
                        s.rb *= 1.8
            for s in c.shapes:
                if s.bone == b.name and s.kind == "plate":
                    for key in ("a", "b", "radii"):
                        setattr(s, key, base + (np.asarray(getattr(s, key)) - base) * EARS)
                    s.ra *= 2.5
                    s.rb *= 1.8
            c.joints[b.tail] = tuple(base + (c.joint(b.tail) - base) * EARS)
    c.eyes = [(p, r * HEAD) for p, r in c.eyes]
    if c.nose is not None:
        c.nose = (c.nose[0], c.nose[1] * HEAD)
    if c.mouth:
        r = c.mouth["radii"]
        c.mouth = dict(c.mouth, radii=(r[0] * HEAD, r[1] * HEAD, r[2]))

    _googly_eyes(c, EYES)

    # Smooth skin instead of hair, in brighter colors, painted as the real
    # animal would be.
    c.fur = dict(c.fur, strands=False, variation=0.0, bump=0.0, roughness=0.55, sheen=0.15, specular=0.2,
                 subsurface=0.08)
    paint = original.paint

    def painted(mesh, creature):
        real = copy.copy(mesh)
        real.verts = _real_points(mesh, before)
        return _vivid(_smooth_colors(mesh, _clean(paint, real, original)))
    c.paint = painted
    c.palette = dict(c.palette or {}, eye_line_size=0.0)


def _googly_eyes(c, boost):
    """Swaps the eyes for big round cartoon ones bulging out of the head,
    turned a little forward and up."""
    old = [e for e in c.extras if e.material == "eye"]
    if not old:
        return
    c.extras = [e for e in c.extras if e.material != "eye"]
    skull = c.joint("skull") if "skull" in c.joints else np.mean([np.asarray(e.center) for e in old], axis=0)
    c.eyes = []
    for e in old:
        d = np.asarray(e.direction, float) + np.array([0.0, 0.0, 0.25])
        d /= np.linalg.norm(d)
        r = max(e.radii) * boost
        p = surface_point(c.shapes, skull, d, sink=r * 0.3)
        eye = Extra("ellipsoid", "eye", e.bone, center=tuple(p), radii=(r * 0.85, r * 1.05, r * 0.75),
                    direction=tuple(d), color="#ffffff", rot=(0.0, 0.0, 0.0))
        eye.pupil = "cartoon"
        c.extras.append(eye)
        c.eyes.append((p, r))


# --- Moving things ---------------------------------------------------------------------

def _all_shapes(c):
    return list(c.shapes) + [s for part in c.parts for s in part["shapes"]]


def _warp(c, fn, bones=None, joints=None):
    """Moves every point (joints, shape ends and centers, extras, eyes, nose,
    mouth) through fn, or only those on `bones` and the named `joints`."""
    def on(bone):
        return bones is None or bone in bones
    for name in list(c.joints):
        if joints is None or name in joints:
            c.joints[name] = tuple(fn(c.joints[name]))
    for s in _all_shapes(c):
        if on(s.bone):
            s.a = fn(s.a)
            if s.kind in ("cone", "plate"):
                s.b = fn(s.b)
            if s.kind == "plate":
                s.radii = fn(s.radii)          # a plate keeps its tip here
    for e in c.extras:
        if on(e.bone):
            e.center = tuple(fn(e.center))
            if e.tip is not None:
                e.tip = tuple(fn(e.tip))
    if bones is None or "head" in bones:
        c.eyes = [(fn(p), r) for p, r in c.eyes]
        if c.nose is not None:
            c.nose = (fn(c.nose[0]), c.nose[1])
        if c.mouth:
            c.mouth = dict(c.mouth, center=tuple(fn(c.mouth["center"])))


def _thicken(s, k):
    if s.kind == "cone":
        s.ra *= k
        s.rb *= k
    elif s.kind == "ellipsoid":
        s.radii = s.radii * k
    elif s.kind == "plate":
        s.ra *= k
        s.rb *= k


# --- Painting as the real animal ---------------------------------------------------------

def _real_points(mesh, before):
    """Where each vertex would be on the real-proportioned animal: each shape
    maps its own surroundings back to where it was, blended by how much the
    vertex belongs to each shape."""
    v = mesh.verts
    total = np.zeros_like(v)
    weight = np.zeros(len(v))
    for i, s in enumerate(mesh.shapes):
        old = before.get(id(s))
        if old is None or s.subtract:
            continue
        w = mesh.shape_weights[:, i]
        idx = np.nonzero(w > 1e-4)[0]
        if not len(idx):
            continue
        total[idx] += w[idx, None] * _map_back(s, old, v[idx])
        weight[idx] += w[idx]
    out = v.copy()
    has = weight > 0
    out[has] = total[has] / weight[has, None]
    return out


def _map_back(new, old, p):
    if new.kind == "ellipsoid":
        local = (p - new.a) @ new.rot
        return old.a + (local * (old.radii / new.radii)) @ old.rot.T
    if new.kind == "cone":
        axis_n, axis_o = new.b - new.a, old.b - old.a
        t = (p - new.a) @ axis_n / max(axis_n @ axis_n, 1e-12)
        radial = p - (new.a + np.outer(t, axis_n))
        radial = radial @ _turn(axis_n, axis_o).T
        tc = np.clip(t, 0.0, 1.0)
        r_new = new.ra + (new.rb - new.ra) * tc
        r_old = old.ra + (old.rb - old.ra) * tc
        return old.a + np.outer(t, axis_o) + radial * (r_old / np.maximum(r_new, 1e-9))[:, None]

    # plate: the triangle's own frame
    def frame(s):
        e1, e2 = s.b - s.a, s.radii - s.a
        n = np.cross(e1, e2)
        n /= max(np.linalg.norm(n), 1e-12)
        return np.stack([e1, e2, n], axis=1)
    coords = np.linalg.solve(frame(new), (p - new.a).T).T
    return old.a + coords @ frame(old).T


def _turn(a, b):
    """Rotation matrix taking direction a to direction b."""
    a = a / max(np.linalg.norm(a), 1e-12)
    b = b / max(np.linalg.norm(b), 1e-12)
    v = np.cross(a, b)
    c = float(a @ b)
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else -np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx / (1 + c)


def _clean(paint, mesh, creature):
    from paint import Painter
    Painter.clean = True
    try:
        return paint(mesh, creature)
    finally:
        Painter.clean = False


def _smooth_colors(mesh, colors, rounds=12):
    """Evens out small blotches in the coat by averaging each vertex's color
    with its neighbors'."""
    from scipy import sparse
    f = np.asarray(mesh.faces)
    rows = np.concatenate([f[:, 0], f[:, 1], f[:, 2], f[:, 1], f[:, 2], f[:, 0]])
    cols = np.concatenate([f[:, 1], f[:, 2], f[:, 0], f[:, 0], f[:, 1], f[:, 2]])
    n = len(mesh.verts)
    adj = sparse.csr_matrix((np.ones(len(rows)), (rows, cols)), shape=(n, n))
    degree = np.maximum(np.asarray(adj.sum(axis=1)).ravel(), 1.0)
    colors = np.asarray(colors, float)
    for _ in range(rounds):
        colors = 0.5 * colors + 0.5 * (adj @ colors) / degree[:, None]
    return colors


def _vivid(colors, saturation=1.25, brightness=1.08):
    colors = np.asarray(colors, float)
    lum = colors @ np.array([0.2126, 0.7152, 0.0722])
    out = lum[:, None] + (colors - lum[:, None]) * saturation
    return np.clip(out * brightness, 0.0, 1.0)


def _bone(c, name):
    return next(b for b in c.bones if b.name == name)


def _descendants(c, root):
    names = {root}
    changed = True
    while changed:
        changed = False
        for b in c.bones:
            if b.parent in names and b.name not in names:
                names.add(b.name)
                changed = True
    return names
