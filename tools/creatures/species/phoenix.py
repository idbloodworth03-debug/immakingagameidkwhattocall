"""Phoenix: the fire bird of legend, made friendly: crimson body, wings
burning from red to orange to gold at the tips, a golden crest of three
flame plumes and a long flowing tail of golden plumes.
"""
import numpy as np

from anatomy import bird
from birdkit import crest, finish, flying, layout, masks
from paint import Painter

SPAN = 2.0
J, R = layout(SPAN, body=1.0, girth=1.1, neck=1.2, head=1.35, beak=(0.9, 1.2), hook=0.7, tail=(2.6, 1.4),
              chord=1.05, fingers=6, fan=0.75)
COLORS = {"red": "#e0302a", "orange": "#ff8a1e", "gold": "#ffd23a", "beak": "#f2c23a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("red")
    wing = p.mesh.region_weight("wing")
    p.blend("orange", wing * p.smooth(out - 0.35, 0.0, 0.15))
    p.blend("gold", wing * p.smooth(out - 0.72, 0.0, 0.12))
    tail = p.mesh.region_weight("tail") + p.mesh.region_weight("plume")
    p.blend("orange", tail)
    p.blend("gold", tail * p.smooth(J["tail_base"][1] - v[:, 1] - SPAN * 0.15, 0.0, SPAN * 0.1))
    p.region("crest", "gold")
    p.region("beak", "beak")
    p.blend("orange", down * p.mesh.region_weight("breast") * 0.5)
    return p.colors


def make():
    c = bird("phoenix", J, R, paint=paint, tiles_long=2.4)
    sk = np.asarray(J["skull"])
    r = R["skull"][0]
    for x, back, rise in ((0.0, 1.2, 1.9), (0.6, 1.4, 1.4), (-0.6, 1.4, 1.4)):
        crest(c, sk + np.array([x * r * 0.3, -r * 0.1, r * 0.6]), sk + np.array([x * r * 0.8, -r * back, r * rise]), r * 0.28)
    te = np.asarray(J["tail_end"])
    for x in (-1.0, -0.4, 0.4, 1.0):
        crest(c, te + np.array([x * r * 0.6, r * 1.5, 0]), te + np.array([x * r * 2.5, -SPAN * 0.3, -r * 0.6]), r * 0.3,
              region="plume", bone="tail1")
    finish(c, R, iris="#7a2a0a")
    return flying(c, SPAN, flap=0.65, hover=0.5)
