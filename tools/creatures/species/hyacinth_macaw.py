"""Hyacinth macaw: the biggest parrot, deep cobalt blue all over with a
bright yellow ring around each eye and a yellow strip under its huge
curved black beak, and a long pointed tail.

Real size: about 1 m long including the tail, 1.1 m wingspan.
"""
import numpy as np

from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 1.1
J, R = layout(SPAN, body=1.0, girth=1.0, neck=0.9, head=1.5, beak=(0.85, 2.6), hook=1.7, tail=(2.4, 0.6),
              chord=0.85, fingers=0, fan=0.5)
COLORS = {"blue": "#2847b8", "light": "#3e66d8", "yellow": "#f5d23a", "beak": "#1b1b1f"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("blue")
    p.blend("light", up * 0.5)
    p.region("beak", "beak")
    # The yellow strip of bare skin under the beak.
    jaw = np.asarray(J["jaw_hinge"])
    p.blend("yellow", p.mesh.region_weight("head") * p.smooth(jaw[2] - v[:, 2], 0.0, R["skull"][2] * 0.2)
            * p.smooth(v[:, 1] - jaw[1] + R["skull"][1] * 0.3, 0.0, R["skull"][1] * 0.2))
    p.region("leg", "beak", 0.6)
    return p.colors


def make():
    c = bird("hyacinth_macaw", J, R, paint=paint, tiles_long=1.4)
    finish(c, R, iris="#1a0d06", eye_line="#f5d23a")
    return flying(c, SPAN, flap=0.75, hover=0.5)
