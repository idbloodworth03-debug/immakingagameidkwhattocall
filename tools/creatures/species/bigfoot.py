"""Bigfoot, made friendly: a tall, shaggy reddish-brown ape-man striding
upright through the woods, with long arms, a gentle face, a little crest
of hair on top and, of course, enormous feet.

Mythical. Built from the gorilla's upright body.
"""
import numpy as np

from paint import Painter
from sdf import ellipsoid
import mountain_gorilla as G

COLORS = {"fur": "#6b4630", "dark": "#4a2f20", "face": "#b48a6e", "palm": "#8a6650"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("fur")
    p.blend("dark", p.smooth(n[:, 2], 0.5, 0.3) * 0.4)
    for region in ("face", "snout", "jaw"):
        p.region(region, "face")
    p.region("front_paw", "palm", 0.6)
    p.region("hind_paw", "dark", 0.8)
    p.speckle(0.12)
    return p.colors


def make():
    c = G.make()
    c.name = "bigfoot"
    c.paint = paint
    c.tiles_long = 1.9
    # The famous big feet.
    for side, bone in ((1, "hl_foot.R"), (-1, "hl_foot.L")):
        toe = np.asarray(G.J["hind_toe"], float) * (-side, 1, 1)
        c.shapes.append(ellipsoid(tuple(toe + (0, 0.04, 0.015)), (0.07, 0.13, 0.04), "hind_paw", bone, blend=0.03))
    c.motion = dict(c.motion, attack="swipe", stride=1.1)
    return c
