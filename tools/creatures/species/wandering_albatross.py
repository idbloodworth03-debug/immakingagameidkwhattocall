"""Wandering albatross: the longest wings of any bird, long and narrow for
gliding over the ocean. White body, dark wings with white near the body,
a pink hooked beak and pinkish feet.

Real size: about 1.2 m long, 3.1 m wingspan.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 3.1
J, R = layout(SPAN, body=0.9, girth=1.0, neck=0.9, head=1.25, beak=(1.4, 1.3), hook=0.5, tail=(0.6, 0.9),
              chord=0.55, fingers=0, legs=0.7, fan=0.3)
COLORS = {"white": "#f7f6f2", "dark": "#2a2627", "beak": "#f0b0a0", "foot": "#e8c2bc"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    p.fill("white")
    wing = p.mesh.region_weight("wing")
    p.blend("dark", wing * up * p.smooth(out - 0.3, 0.0, 0.08))
    p.blend("dark", wing * down * p.smooth(out - 0.85, 0.0, 0.05))
    p.region("beak", "beak")
    p.region("leg", "foot")
    return p.colors


def make():
    c = bird("wandering_albatross", J, R, paint=paint, tiles_long=2.6)
    finish(c, R, iris="#2a1a10")
    return flying(c, SPAN, flap=0.4, hover=0.3)
