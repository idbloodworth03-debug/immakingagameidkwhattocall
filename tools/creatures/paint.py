"""Helpers for coloring a creature's mesh per vertex.

Paint calls build up colors layer by layer, like painting: fill a base coat,
then blend other colors into body parts, with soft edges.
"""
import numpy as np

from scene import hex_color


class Painter:
    # Cartoon coats: no speckle or noise, so color areas stay clean.
    clean = False

    def __init__(self, mesh, colors):
        self.mesh = mesh
        self.v = mesh.verts
        self.n = mesh.normals / np.maximum(np.linalg.norm(mesh.normals, axis=1, keepdims=True), 1e-9)
        self.palette = {k: hex_color(v) for k, v in colors.items()}
        self.colors = np.zeros((len(self.v), 3))
        self.rng = np.random.default_rng(7)

    @staticmethod
    def smooth(x, edge, width):
        """0 below `edge`, 1 above `edge + width`, smooth in between."""
        t = np.clip((x - edge) / np.maximum(width, 1e-9), 0.0, 1.0)
        return t * t * (3 - 2 * t)

    def color(self, name):
        return self.palette[name] if isinstance(name, str) else np.asarray(name, float)

    def blend(self, name, amount):
        amount = np.clip(amount, 0.0, 1.0)[:, None]
        self.colors = self.colors * (1 - amount) + self.color(name) * amount

    def fill(self, name):
        self.colors[:] = self.color(name)

    def region(self, region, name, strength=1.0):
        self.blend(name, self.mesh.region_weight(region) * strength)

    def region_where(self, region, name, mask_fn, strength=1.0):
        self.blend(name, self.mesh.region_weight(region) * mask_fn(self.v, self.n) * strength)

    def where(self, name, mask_fn, strength=1.0):
        self.blend(name, mask_fn(self.v, self.n) * strength)

    def region_underside(self, region, name, below=-0.2, soft=0.3, strength=1.0):
        self.blend(name, self.mesh.region_weight(region) * self.smooth(-self.n[:, 2], -below, soft) * strength)

    def top_darken(self, name, start=0.4, strength=0.5):
        if Painter.clean:
            strength *= 0.5
        self.blend(name, self.smooth(self.n[:, 2], start, 0.4) * strength)

    def speckle(self, amount):
        """Small random brightness changes so big areas don't look flat."""
        if Painter.clean:
            return
        noise = 1.0 + (self.rng.random(len(self.v)) - 0.5) * amount
        self.colors *= noise[:, None]

    def noise(self, scale, seed=0, markings=False):
        """Smooth random values from -1 to 1 over the body (a sum of waves
        in random directions), `scale` waves per meter. Cartoon coats drop
        noise unless it draws the animal's `markings`."""
        if Painter.clean and not markings:
            return np.zeros(len(self.v))
        rng = np.random.default_rng(seed)
        total = np.zeros(len(self.v))
        for _ in range(6):
            k = rng.normal(size=3)
            k = k / np.linalg.norm(k) * scale * (0.6 + rng.random() * 0.8)
            total += np.sin(self.v @ k + rng.random() * 6.28)
        return total / 2.4

    def stripes(self, name, coord_fn, frequency, width=0.35, wobble=0.0, mask=None, strength=1.0,
                breakup=0.0, seed=5):
        """Bands across the body (a tiger's stripes): `coord_fn(v)` gives the
        position along which stripes repeat. `wobble` bends them, `breakup`
        makes them taper, vary in thickness and sometimes break."""
        x = coord_fn(self.v) * frequency
        if wobble:
            x = x + wobble * self.noise(frequency * 1.2, seed)
        w = np.full(len(self.v), width)
        if breakup:
            w = width * np.clip(1 + breakup * self.noise(frequency * 2.0, seed + 1), 0.0, 2.0)
        band = self.smooth(np.cos(x * 2 * np.pi), 1 - w * 2, 0.25)
        m = band if mask is None else band * mask
        self.blend(name, m * strength)

    def spots(self, name, cell, radius, ring=0.0, mask=None, strength=1.0, seed=3, jitter=0.35):
        """Round spots (or rosettes when `ring` > 0) scattered over the skin,
        about one per `cell` x `cell` patch. Spots vary in size a little."""
        from scipy.spatial import cKDTree
        rng = np.random.default_rng(seed)
        faces = self.mesh.faces
        a, b, c = (self.v[faces[:, i]] for i in range(3))
        areas = np.linalg.norm(np.cross(b - a, c - a), axis=1) / 2
        count = max(3, int(areas.sum() / (cell * cell)))
        pick = rng.choice(len(faces), size=count, p=areas / areas.sum())
        w = rng.random((count, 2))
        flip = w.sum(axis=1) > 1
        w[flip] = 1 - w[flip]
        centers = a[pick] + (b[pick] - a[pick]) * w[:, :1] + (c[pick] - a[pick]) * w[:, 1:]
        sizes = radius * (1 + (rng.random(count) - 0.5) * 2 * jitter)
        tree = cKDTree(centers)
        d, idx = tree.query(self.v, k=3)
        m = np.zeros(len(self.v))
        for j in range(3):
            r = sizes[idx[:, j]]
            if ring > 0:
                inside = self.smooth(d[:, j], r - ring, ring * 0.3) * self.smooth(r + ring * 0.2 - d[:, j], 0.0, ring * 0.3)
            else:
                inside = self.smooth(r - d[:, j], 0.0, r * 0.35)
            m = np.maximum(m, inside)
        if mask is not None:
            m = m * mask
        self.blend(name, m * strength)

    def _surface_points(self, cell, rng):
        faces = self.mesh.faces
        a, b, c = (self.v[faces[:, i]] for i in range(3))
        areas = np.linalg.norm(np.cross(b - a, c - a), axis=1) / 2
        count = max(3, int(areas.sum() / (cell * cell)))
        pick = rng.choice(len(faces), size=count, p=areas / areas.sum())
        w = rng.random((count, 2))
        flip = w.sum(axis=1) > 1
        w[flip] = 1 - w[flip]
        points = a[pick] + (b[pick] - a[pick]) * w[:, :1] + (c[pick] - a[pick]) * w[:, 1:]
        normals = self.n[faces[pick, 0]]
        return points, normals

    def rosettes(self, ring_name, center_name, cell, radius, blob=0.32, blobs=(4, 6), mask=None, seed=31):
        """Leopard rosettes: a broken ring of black blotches round a darker
        middle, about one per `cell` x `cell` patch."""
        from scipy.spatial import cKDTree
        rng = np.random.default_rng(seed)
        centers, normals = self._surface_points(cell, rng)
        size = radius * (0.75 + rng.random(len(centers)) * 0.5)
        # Darker middle.
        tree = cKDTree(centers)
        d, idx = tree.query(self.v)
        middle = self.smooth(size[idx] * 0.8 - d, 0.0, size[idx] * 0.3)
        # Blotches round the ring, in the plane of the skin.
        pts, rads = [], []
        for c, n, r in zip(centers, normals, size):
            t1 = np.cross(n, [0.0, 0.0, 1.0])
            if np.linalg.norm(t1) < 1e-3:
                t1 = np.cross(n, [1.0, 0.0, 0.0])
            t1 /= np.linalg.norm(t1)
            t2 = np.cross(n, t1)
            k = rng.integers(blobs[0], blobs[1] + 1)
            start = rng.random() * 6.28
            for j in range(k):
                ang = start + j * 6.28 / k + (rng.random() - 0.5) * 0.6
                pts.append(c + (t1 * np.cos(ang) + t2 * np.sin(ang)) * r * (0.95 + rng.random() * 0.2))
                rads.append(r * blob * (0.7 + rng.random() * 0.6))
        pts, rads = np.array(pts), np.array(rads)
        tree = cKDTree(pts)
        d, idx = tree.query(self.v, k=2)
        ring = np.maximum(self.smooth(rads[idx[:, 0]] - d[:, 0], 0.0, rads[idx[:, 0]] * 0.4),
                          self.smooth(rads[idx[:, 1]] - d[:, 1], 0.0, rads[idx[:, 1]] * 0.4))
        m = 1.0 if mask is None else mask
        self.blend(center_name, middle * m * 0.75)
        self.blend(ring_name, ring * m)
