"""Atlantic puffin: a little black-and-white seabird with a white face,
a tall striped beak of orange, blue-grey and yellow, a red-rimmed eye and
bright orange feet, beating its short wings fast.

Real size: about 28 cm long, 55 cm wingspan.
"""
import numpy as np

from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 0.6
J, R = layout(SPAN, body=0.9, girth=1.5, neck=0.6, head=1.65, beak=(0.75, 2.5), hook=0.0, tail=(0.5, 0.9),
              chord=0.75, fingers=0, legs=0.6, fan=0.3)
COLORS = {"black": "#18181c", "white": "#f5f5f2", "grey": "#c9cbd0", "orange": "#f06a20", "blue": "#4a6c8c",
          "yellow": "#f2c94a", "foot": "#f2782a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("white")
    p.blend("black", up)
    p.blend("black", p.mesh.region_weight("neck") * 0.9)
    head = p.mesh.region_weight("head")
    p.blend("black", head * up * p.smooth(v[:, 2] - J["skull"][2] - R["skull"][2] * 0.3, 0.0, R["skull"][2] * 0.2))
    p.blend("white", head * (1 - up) * 0.6)
    beak = p.mesh.region_weight("beak")
    root, tip = np.asarray(J["jaw_hinge"]), np.asarray(J["beak_tip"])
    along = np.clip((v[:, 1] - root[1]) / max(tip[1] - root[1], 1e-6), 0, 1)
    p.blend("blue", beak)
    p.blend("yellow", beak * p.smooth(along - 0.35, 0.0, 0.04) * p.smooth(0.45 - along, 0.0, 0.04))
    p.blend("orange", beak * p.smooth(along - 0.45, 0.0, 0.04))
    p.region("leg", "foot")
    return p.colors


def make():
    c = bird("atlantic_puffin", J, R, paint=paint, tiles_long=0.9)
    finish(c, R, iris="#1a0d06", eye_line="#d94a3a")
    return flying(c, SPAN, flap=0.95, hover=0.7)
