"""Helpers for coloring a creature's mesh per vertex.

Paint calls build up colors layer by layer, like painting: fill a base coat,
then blend other colors into body parts, with soft edges.
"""
import numpy as np

from scene import hex_color


class Painter:
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
        t = np.clip((x - edge) / max(width, 1e-9), 0.0, 1.0)
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
        self.blend(name, self.smooth(self.n[:, 2], start, 0.4) * strength)

    def speckle(self, amount):
        """Small random brightness changes so big areas don't look flat."""
        noise = 1.0 + (self.rng.random(len(self.v)) - 0.5) * amount
        self.colors *= noise[:, None]

    def stripes(self, name, coord_fn, frequency, width=0.35, wobble=0.0, mask=None, strength=1.0):
        """Bands across the body (a tiger's stripes): `coord_fn(v)` gives the
        position along which stripes repeat."""
        x = coord_fn(self.v) * frequency
        if wobble:
            x = x + wobble * np.sin(self.v[:, 2] * 37.0 + self.v[:, 0] * 23.0) + wobble * 0.6 * np.sin(self.v[:, 1] * 51.0)
        band = self.smooth(np.cos(x * 2 * np.pi), 1 - width * 2, 0.25)
        m = band if mask is None else band * mask
        self.blend(name, m * strength)

    def spots(self, name, cell, radius, ring=0.0, mask=None, strength=1.0, seed=3):
        """Round spots (or rosettes when `ring` > 0) scattered over the surface."""
        rng = np.random.default_rng(seed)
        lo, hi = self.v.min(axis=0), self.v.max(axis=0)
        n = int(np.prod((hi - lo) / cell)) + 1
        centers = lo + rng.random((n, 3)) * (hi - lo)
        from scipy.spatial import cKDTree
        tree = cKDTree(centers)
        d, _ = tree.query(self.v)
        if ring > 0:
            m = self.smooth(d, radius - ring, ring * 0.3) * self.smooth(radius + ring * 0.2 - d, 0.0, ring * 0.3)
        else:
            m = self.smooth(radius - d, 0.0, radius * 0.35)
        if mask is not None:
            m = m * mask
        self.blend(name, m * strength)
