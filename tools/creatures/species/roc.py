"""Roc: the giant bird of legend, big enough to carry off an elephant: a
golden-brown eagle with a cream breast, dark wingtips and a huge golden
hooked beak.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter

SPAN = 3.0
J, R = layout(SPAN, body=1.1, girth=1.35, neck=1.0, head=1.5, beak=(1.2, 2.0), hook=1.3, tail=(1.2, 1.1),
              chord=1.1, fingers=6, fan=0.65)
COLORS = {"brown": "#8a5a2b", "cream": "#e8d2a8", "dark": "#3a2614", "beak": "#e2ac2c", "foot": "#d9a43a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    p.fill("cream")
    p.blend("brown", up)
    p.blend("dark", p.mesh.region_weight("wing") * p.smooth(out - 0.75, 0.0, 0.08) * 0.85)
    p.region("head", "brown", 0.5)
    p.region("beak", "beak")
    p.region("leg", "foot")
    return p.colors


def make():
    c = bird("roc", J, R, paint=paint, tiles_long=3.0)
    finish(c, R, iris="#c98a1a")
    return flying(c, SPAN, flap=0.5, hover=0.4)
