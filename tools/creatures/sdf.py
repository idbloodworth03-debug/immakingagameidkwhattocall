"""Signed-distance modeling: animals are built from simple shapes (round
cones, ellipsoids) that blend smoothly into each other, then turned into a
mesh with marching cubes.

Every shape belongs to a body part ("region") and a bone, so after meshing
each vertex knows which part it is on (for coloring) and how strongly each
bone moves it (for animation).

Distances are in meters. +Y is the animal's forward, +Z is up, +X is its right.
"""
from dataclasses import dataclass, field

import numpy as np
from skimage import measure


@dataclass
class Shape:
    kind: str                 # "cone" (round cone between a and b) or "ellipsoid"
    a: np.ndarray             # start point (cone) or center (ellipsoid)
    b: np.ndarray = None      # end point (cone)
    ra: float = 0.0           # radius at a (cone)
    rb: float = 0.0           # radius at b (cone)
    radii: np.ndarray = None  # ellipsoid half-sizes along its own axes
    rot: np.ndarray = None    # ellipsoid: 3x3 matrix, columns are its axes in world space
    blend: float = 0.02       # how softly it melts into the shapes before it
    region: str = "body"
    bone: str = "spine"
    bone_b: str = None        # cone: weight slides from `bone` at a to `bone_b` at b
    subtract: bool = False    # carve this shape out instead of adding it


def plate(base_a, base_b, tip, thickness, rounding, region, bone, blend=0.01, subtract=False):
    """A thin rounded triangle (an ear, a fin): corners base_a, base_b, tip."""
    s = Shape("plate", np.asarray(base_a, float), np.asarray(base_b, float), ra=thickness, rb=rounding,
              blend=blend, region=region, bone=bone, subtract=subtract)
    s.radii = np.asarray(tip, float)
    return s


def cone(a, b, ra, rb, region, bone, bone_b=None, blend=0.02):
    return Shape("cone", np.asarray(a, float), np.asarray(b, float), ra, rb,
                 blend=blend, region=region, bone=bone, bone_b=bone_b)


def ellipsoid(center, radii, region, bone, blend=0.02, yaw=0.0, pitch=0.0, roll=0.0, subtract=False):
    return Shape("ellipsoid", np.asarray(center, float), radii=np.asarray(radii, float),
                 rot=rotation(yaw, pitch, roll), blend=blend, region=region, bone=bone, subtract=subtract)


def rotation(yaw=0.0, pitch=0.0, roll=0.0):
    """Yaw turns around Z, pitch tilts the nose up around X, roll around Y (radians)."""
    cz, sz = np.cos(yaw), np.sin(yaw)
    cx, sx = np.cos(pitch), np.sin(pitch)
    cy, sy = np.cos(roll), np.sin(roll)
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    return rz @ rx @ ry


def distance(shape, p):
    """Signed distance from points p (N x 3) to the shape, plus a 0-1 position
    along it (0 at a, 1 at b; ellipsoids report how far along their own Y axis)."""
    if shape.kind == "cone":
        return _round_cone(p, shape.a, shape.b, shape.ra, shape.rb)
    if shape.kind == "plate":
        return _plate(p, shape.a, shape.b, shape.radii, shape.ra, shape.rb)
    local = (p - shape.a) @ shape.rot
    r = shape.radii
    k0 = np.linalg.norm(local / r, axis=1)
    k1 = np.linalg.norm(local / (r * r), axis=1)
    d = k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    t = np.clip(0.5 + 0.5 * local[:, 1] / r[1], 0.0, 1.0)
    return d, t


def _round_cone(p, a, b, ra, rb):
    """Exact distance to a cone with rounded ends (Inigo Quilez's sdRoundCone)."""
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    xv = pa * l2 - np.outer(y, ba)
    x2 = np.einsum("ij,ij->i", xv, xv)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d = np.where(
        np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - rb,
        np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - ra,
                 (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - ra))
    t = np.clip(y * il2, 0.0, 1.0)
    return d, t


def _plate(p, a, b, c, thickness, rounding):
    """Distance to a triangle a-b-c, its outline rounded by `rounding`,
    `thickness` thick on each side with softly beveled edges."""
    e1 = b - a
    normal = np.cross(b - a, c - a)
    normal /= np.linalg.norm(normal)
    u = e1 / np.linalg.norm(e1)
    v = np.cross(normal, u)
    q = p - a
    px, py, pz = q @ u, q @ v, q @ normal
    tri = [np.array([0.0, 0.0]), np.array([(b - a) @ u, (b - a) @ v]), np.array([(c - a) @ u, (c - a) @ v])]
    bevel = thickness * 0.5
    w0 = _triangle_2d(px, py, *tri) - rounding + bevel
    w1 = np.abs(pz) - (thickness - bevel)
    d = np.minimum(np.maximum(w0, w1), 0.0) + np.sqrt(np.maximum(w0, 0) ** 2 + np.maximum(w1, 0) ** 2) - bevel
    base_mid = (a + b) / 2
    axis = c - base_mid
    t = np.clip((p - base_mid) @ axis / (axis @ axis), 0.0, 1.0)
    return d, t


def _triangle_2d(px, py, p0, p1, p2):
    """Inigo Quilez's sdTriangle, for arrays of points."""
    p = np.stack([px, py], axis=1)
    e0, e1, e2 = p1 - p0, p2 - p1, p0 - p2
    v0, v1, v2 = p - p0, p - p1, p - p2

    def edge(v, e):
        h = np.clip((v @ e) / (e @ e), 0.0, 1.0)
        return v - np.outer(h, e)
    pq0, pq1, pq2 = edge(v0, e0), edge(v1, e1), edge(v2, e2)
    s = np.sign(e0[0] * e2[1] - e0[1] * e2[0])
    dx = np.minimum(np.minimum((pq0 ** 2).sum(1), (pq1 ** 2).sum(1)), (pq2 ** 2).sum(1))
    c0 = s * (v0[:, 0] * e0[1] - v0[:, 1] * e0[0])
    c1 = s * (v1[:, 0] * e1[1] - v1[:, 1] * e1[0])
    c2 = s * (v2[:, 0] * e2[1] - v2[:, 1] * e2[0])
    dy = np.minimum(np.minimum(c0, c1), c2)
    return -np.sqrt(dx) * np.sign(dy)


def smooth_union(d1, d2, k):
    if k <= 0:
        return np.minimum(d1, d2)
    h = np.clip(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0)
    return d2 + (d1 - d2) * h - k * h * (1.0 - h)


def smooth_subtract(d_from, d_cut, k):
    if k <= 0:
        return np.maximum(d_from, -d_cut)
    h = np.clip(0.5 - 0.5 * (d_from + d_cut) / k, 0.0, 1.0)
    return d_from + (-d_cut - d_from) * h + k * h * (1.0 - h)


def field_value(shapes, p):
    """Blends all shapes at points p. Each shape only matters near itself
    (within its blend distance), so it is only evaluated there."""
    total = None
    for s in shapes:
        if total is None:
            total, _ = distance(s, p)
            continue
        lo, hi = _bounds(s)
        reach = s.blend + 1e-6
        near = np.all((p >= lo - reach) & (p <= hi + reach), axis=1)
        if not near.any():
            continue
        idx = np.nonzero(near)[0]
        d, _ = distance(s, p[idx])
        if s.subtract:
            total[idx] = smooth_subtract(total[idx], d, s.blend)
        else:
            total[idx] = smooth_union(total[idx], d, s.blend)
    return total


@dataclass
class Mesh:
    verts: np.ndarray
    faces: np.ndarray
    normals: np.ndarray
    # Per vertex: which shapes are nearby, as weights (V x S), and the 0-1
    # position along each shape (V x S).
    shape_weights: np.ndarray = None
    shape_t: np.ndarray = None
    shapes: list = field(default_factory=list)

    def region_weight(self, region):
        """0-1 per vertex: how much each vertex belongs to a body part."""
        cols = [i for i, s in enumerate(self.shapes) if s.region == region]
        if not cols:
            return np.zeros(len(self.verts))
        return self.shape_weights[:, cols].sum(axis=1)

    def region_t(self, region):
        """Weighted 0-1 position along a body part's shapes."""
        cols = [i for i, s in enumerate(self.shapes) if s.region == region]
        if not cols:
            return np.zeros(len(self.verts))
        w = self.shape_weights[:, cols]
        return (w * self.shape_t[:, cols]).sum(axis=1) / np.maximum(w.sum(axis=1), 1e-9)


def build_mesh(shapes, voxel=0.006, softness=None, padding=0.03):
    """Meshes the blended shapes with marching cubes."""
    adds = [s for s in shapes if not s.subtract]
    lo = np.min([_bounds(s)[0] for s in adds], axis=0) - padding
    hi = np.max([_bounds(s)[1] for s in adds], axis=0) + padding
    counts = np.ceil((hi - lo) / voxel).astype(int) + 1
    axes = [lo[i] + np.arange(counts[i]) * voxel for i in range(3)]
    grid = np.stack(np.meshgrid(*axes, indexing="ij"), axis=-1).reshape(-1, 3)
    values = np.empty(len(grid))
    chunk = 400_000
    for start in range(0, len(grid), chunk):
        values[start:start + chunk] = field_value(shapes, grid[start:start + chunk])
    volume = values.reshape(counts)
    # "ascent": inside is where the distance is lowest (negative), so the
    # faces and normals point outward.
    verts, faces, normals, _ = measure.marching_cubes(volume, level=0.0, spacing=(voxel, voxel, voxel),
                                                      gradient_direction="ascent")
    verts = verts + lo
    mesh = Mesh(verts, faces, field_normals(shapes, verts, voxel), shapes=shapes)
    # Make sure faces wind the same way as the outward normals.
    a, b, c = (verts[faces[:, i]] for i in range(3))
    face_n = np.cross(b - a, c - a)
    outward = (face_n * mesh.normals[faces].mean(axis=1)).sum(axis=1)
    if np.mean(outward > 0) < 0.5:
        mesh.faces = faces[:, ::-1].copy()
    attribute(mesh, softness or voxel * 3)
    return mesh


def surface_point(shapes, origin, direction, sink=0.0):
    """Walks from `origin` along `direction` until it reaches the surface
    (sphere tracing), then steps back in by `sink`."""
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    p = np.asarray(origin, float).copy()
    for _ in range(200):
        dist = float(field_value(shapes, p[None, :])[0])
        if dist > 0:
            # Started outside or passed it: walk back.
            p -= d * max(dist, 1e-4) * 0.5
            if dist < 1e-4:
                break
            continue
        if -dist < 1e-4:
            break
        p += d * max(-dist, 1e-4) * 0.8
    return p - d * sink


def field_normals(shapes, points, step):
    """Outward surface directions: the gradient of the distance field."""
    grads = []
    for axis in range(3):
        offset = np.zeros(3)
        offset[axis] = step * 0.5
        grads.append(field_value(shapes, points + offset) - field_value(shapes, points - offset))
    g = np.stack(grads, axis=1)
    return g / np.maximum(np.linalg.norm(g, axis=1, keepdims=True), 1e-12)


def attribute(mesh, softness):
    """Works out which shapes each vertex belongs to."""
    ds, ts = [], []
    for s in mesh.shapes:
        d, t = distance(s, mesh.verts)
        ds.append(d)
        ts.append(t)
    d = np.stack(ds, axis=1)
    t = np.stack(ts, axis=1)
    for i, s in enumerate(mesh.shapes):
        if s.subtract:
            d[:, i] = np.inf
    nearest = d.min(axis=1, keepdims=True)
    w = np.exp(-(d - nearest) / softness)
    w /= w.sum(axis=1, keepdims=True)
    mesh.shape_weights = w
    mesh.shape_t = t


def bone_weights(mesh):
    """Bone name -> per-vertex weight, from the shapes' bones."""
    weights = {}
    for i, s in enumerate(mesh.shapes):
        if s.subtract:
            continue
        w = mesh.shape_weights[:, i]
        if s.kind == "cone" and s.bone_b:
            # Slide from bone to bone_b over the middle of the segment.
            t = np.clip((mesh.shape_t[:, i] - 0.25) / 0.5, 0.0, 1.0)
            t = t * t * (3 - 2 * t)
            weights[s.bone] = weights.get(s.bone, 0) + w * (1 - t)
            weights[s.bone_b] = weights.get(s.bone_b, 0) + w * t
        else:
            weights[s.bone] = weights.get(s.bone, 0) + w
    return weights


def _bounds(s):
    if s.kind == "plate":
        pts = np.stack([s.a, s.b, s.radii])
        pad = s.ra + s.rb
        return pts.min(axis=0) - pad, pts.max(axis=0) + pad
    if s.kind == "cone":
        r = max(s.ra, s.rb)
        return np.minimum(s.a, s.b) - r, np.maximum(s.a, s.b) + r
    r = float(np.max(s.radii))
    return s.a - r, s.a + r
