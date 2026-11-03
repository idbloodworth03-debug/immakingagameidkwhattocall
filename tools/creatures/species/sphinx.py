"""Sphinx, made friendly: a sandy-gold lion lying proud with a calm cat
face, wearing a royal striped headdress of blue and gold that falls in two
flaps beside its face, like Egypt's Great Sphinx.

Mythical. Built from the lion, without the mane.
"""
import numpy as np

from paint import Painter
from sdf import ellipsoid, plate
import lion as L

COLORS = {"sand": "#dcb46e", "back": "#c99a52", "pale": "#f0dcb0", "gold": "#f2c13a", "blue": "#2f5fb3", "black": "#3a2a1a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("sand")
    p.top_darken("back", start=0.3, strength=0.4)
    p.region_underside("torso", "pale", below=-0.35, soft=0.3)
    p.region("jaw", "pale", 0.8)
    nemes = p.mesh.region_weight("nemes")
    p.blend("gold", nemes)
    p.stripes("blue", lambda q: q[:, 2] * 1.0 + np.abs(q[:, 0]) * 0.3, frequency=26.0, width=0.45, mask=nemes)
    p.region("tail_tip", "back")
    return p.colors


def make():
    c = L.make()
    c.name = "sphinx"
    c.shapes = [s for s in c.shapes if s.region != "mane"]
    c.paint = paint
    c.cartoon = {}
    sk = np.asarray(L.J["skull"], float)
    # The headdress: a cap over the head and two striped flaps falling beside the face.
    c.shapes.append(ellipsoid(tuple(sk + (0, -0.03, 0.06)), (0.17, 0.17, 0.13), "nemes", "head", blend=0.03))
    for side in (1, -1):
        top = sk + (side * 0.15, -0.02, 0.02)
        c.shapes.append(plate(top + (0, 0.05, 0), top + (0, -0.07, 0), top + (side * 0.02, 0.02, -0.26), 0.02, 0.02, "nemes", "neck",
                              blend=0.02))
    c.tiles_long = 2.4
    c.motion = dict(c.motion, attack="swipe", rear=0.3)
    return c
