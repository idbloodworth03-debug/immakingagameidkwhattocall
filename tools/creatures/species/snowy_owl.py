"""Snowy owl: a big round white owl of the Arctic, spotted and barred with
black, with yellow eyes, a small black beak and fluffy feathered feet.

Real size: about 60 cm long, 1.4 m wingspan.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 1.4
J, R = layout(SPAN, body=0.9, girth=1.5, neck=0.6, head=1.65, beak=(0.4, 1.0), hook=0.8, tail=(0.6, 1.0),
              chord=1.15, fingers=0, legs=0.8, fan=0.4)
COLORS = {"white": "#f7f7f5", "spot": "#2a2a2c", "beak": "#1f1f21"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    p.fill("white")
    body = 1 - p.mesh.region_weight("head") * 0.8
    p.spots("spot", cell=SPAN * 0.045, radius=SPAN * 0.008, mask=up * body * 0.9)
    p.spots("spot", cell=SPAN * 0.06, radius=SPAN * 0.006, mask=down * p.mesh.region_weight("wing") * 0.5, seed=8)
    p.region("beak", "beak")
    return p.colors


def make():
    c = bird("snowy_owl", J, R, paint=paint, tiles_long=1.6)
    finish(c, R, iris="#f2c21b", eye_dir=(-0.45, 0.86, 0.2), eye=0.3)
    return flying(c, SPAN, flap=0.6, hover=0.45)
