"""Steller's sea eagle: one of the biggest eagles, dark brown with bright
white shoulders, a white wedge tail and white thighs, and an enormous
arched orange-yellow beak.

Real size: about 1 m long, 2.3 m wingspan.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 2.3
J, R = layout(SPAN, body=1.0, girth=1.25, neck=0.9, head=1.4, beak=(1.3, 2.4), hook=1.25, tail=(1.15, 1.0),
              chord=1.05, fingers=6, fan=0.6)
COLORS = {"brown": "#2b2320", "white": "#f5f3ee", "beak": "#f0a21a", "foot": "#f0b83a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("brown")
    wing = p.mesh.region_weight("wing")
    # White shoulders along the front of the inner wing.
    p.blend("white", wing * up * p.smooth(0.42 - out, 0.0, 0.05) * p.smooth(v[:, 1] - J["elbow"][1] * 0.9, 0.0, SPAN * 0.02))
    p.region("tail", "white")
    p.region("leg", "white")
    p.region("beak", "beak")
    return p.colors


def make():
    c = bird("stellers_sea_eagle", J, R, paint=paint, tiles_long=2.3)
    finish(c, R, iris="#c9a020")
    return flying(c, SPAN, flap=0.55, hover=0.4)
