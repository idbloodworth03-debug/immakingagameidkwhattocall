"""Whooping crane: tall and white, with black wingtips, a red crown, a black
patch on the cheek, a long straight yellowish beak, a long neck stretched
out in flight and long black legs trailing behind.

Real size: about 1.5 m tall, 2.2 m wingspan.
"""
import numpy as np

from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 2.2
J, R = layout(SPAN, body=1.0, girth=0.9, neck=2.0, head=1.0, beak=(2.2, 0.8), hook=0.0, tail=(0.5, 0.9),
              chord=0.95, fingers=5, legs=3.0, fan=0.6)
COLORS = {"white": "#f6f5f0", "black": "#16161a", "red": "#d63a3a", "beak": "#a89a55", "leg": "#202022"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("white")
    p.blend("black", p.mesh.region_weight("wing") * p.smooth(out - 0.72, 0.0, 0.05))
    head = p.mesh.region_weight("head")
    sk = np.asarray(J["skull"])
    p.blend("red", head * up * p.smooth(v[:, 2] - sk[2], 0.0, R["skull"][2] * 0.3))
    p.blend("black", head * p.smooth(sk[2] - v[:, 2], 0.0, R["skull"][2] * 0.3) * p.smooth(v[:, 1] - sk[1], 0.0, R["skull"][1] * 0.3) * 0.8)
    p.region("beak", "beak")
    p.region("leg", "leg")
    return p.colors


def make():
    c = bird("whooping_crane", J, R, paint=paint, tiles_long=2.2)
    finish(c, R, iris="#d8a020")
    return flying(c, SPAN, flap=0.55, hover=0.4)
