"""Harpy eagle: a powerful rainforest eagle with a soft grey head and a
split double crest, a black band across the chest, white belly, slate
black back, a black hooked beak and yellow feet as big as a bear's paw.

Real size: about 1 m long, 1.9 m wingspan.
"""
import numpy as np

from anatomy import bird
from birdkit import crest, finish, flying, layout, masks
from paint import Painter

SPAN = 1.9
J, R = layout(SPAN, body=1.0, girth=1.3, neck=0.9, head=1.45, beak=(0.9, 1.6), hook=1.2, tail=(1.0, 1.0),
              chord=1.05, fingers=0, fan=0.5)
COLORS = {"grey": "#a9abaf", "black": "#232327", "white": "#f4f2ed", "bar": "#3a3a3e", "beak": "#222224",
          "foot": "#e6b63a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("white")
    p.blend("black", up)
    p.stripes("bar", lambda q: q[:, 1], frequency=1.0 / (SPAN * 0.05), width=0.2,
              mask=down * p.mesh.region_weight("wing") * 0.7)
    p.region("head", "grey")
    p.region("crest", "black")
    p.blend("black", p.mesh.region_weight("breast") * p.smooth(v[:, 1] - J["withers"][1] * 0.9, 0.0, 0.02))
    p.region("neck", "grey", 0.8)
    p.region("beak", "beak")
    p.region("leg", "foot")
    return p.colors


def make():
    c = bird("harpy_eagle", J, R, paint=paint, tiles_long=2.0)
    sk = np.asarray(J["skull"])
    r = R["skull"][0]
    for side in (1, -1):
        crest(c, sk + np.array([side * r * 0.35, -r * 0.3, r * 0.6]), sk + np.array([side * r * 0.6, -r * 1.3, r * 1.6]), r * 0.3)
    finish(c, R, iris="#2a1a0e")
    return flying(c, SPAN, flap=0.6, hover=0.45)
