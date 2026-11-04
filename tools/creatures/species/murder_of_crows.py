"""American crows: glossy black all over with a blue sheen on the back, a
strong straight black beak and black legs. The game shows a pair of them.

Real size: about 45 cm long, 90 cm wingspan.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 0.9
J, R = layout(SPAN, body=1.0, girth=1.1, neck=0.9, head=1.3, beak=(0.95, 1.3), hook=0.15, tail=(1.0, 1.0),
              fingers=5, fan=0.7)
COLORS = {"black": "#1b1c23", "gloss": "#2f3a5c", "beak": "#101013"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    p.fill("black")
    p.blend("gloss", up * 0.35)
    p.region("beak", "beak")
    p.region("leg", "beak")
    return p.colors


def make():
    c = bird("murder_of_crows", J, R, paint=paint, tiles_long=1.0)
    finish(c, R, iris="#2a1a10")
    c = flying(c, SPAN, flap=0.8, hover=0.55)
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "rake"
    return c
