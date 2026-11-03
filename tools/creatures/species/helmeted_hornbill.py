"""Helmeted hornbill: a big dark rainforest bird with a solid red and yellow
"helmet" (casque) on top of its beak, a bare red throat, a white tail with a
black band and two very long white central tail feathers.

Real size: about 1.2 m long plus 50 cm tail plumes, 1.6 m wingspan.
"""
import numpy as np

from anatomy import bird
from birdkit import crest, finish, flying, layout, masks
from paint import Painter
from sdf import ellipsoid

SPAN = 1.6
J, R = layout(SPAN, body=1.0, girth=1.0, neck=1.1, head=1.4, beak=(1.5, 1.6), hook=0.0, tail=(2.2, 0.7),
              fingers=5, fan=0.6)
COLORS = {"dark": "#2a2320", "white": "#f2efe8", "band": "#1a1716", "red": "#cf4a2c", "yellow": "#e8b43a",
          "throat": "#c8403a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("dark")
    p.blend("white", down * p.mesh.region_weight("torso") * 0.8)
    tail = p.mesh.region_weight("tail") + p.mesh.region_weight("plume")
    p.blend("white", tail)
    mid = (J["tail_base"][1] + J["tail_end"][1]) / 2
    p.blend("band", p.mesh.region_weight("tail") * p.smooth(SPAN * 0.04 - np.abs(v[:, 1] - mid), 0.0, SPAN * 0.01))
    p.region("beak", "yellow")
    p.region("casque", "red")
    p.blend("yellow", p.mesh.region_weight("casque") * p.smooth(v[:, 1] - J["beak_tip"][1] * 0.97, 0.0, SPAN * 0.01))
    p.region("neck", "throat", 0.6)
    return p.colors


def make():
    c = bird("helmeted_hornbill", J, R, paint=paint, tiles_long=1.9)
    sk, tip = np.asarray(J["skull"]), np.asarray(J["beak_tip"])
    r = R["skull"][0]
    # The casque: a solid block on top of the beak, from the forehead out.
    mid = sk + (tip - sk) * 0.45 + np.array([0, 0, r * 0.75])
    c.shapes.append(ellipsoid(tuple(mid), (r * 0.5, float(np.linalg.norm(tip - sk)) * 0.38, r * 0.45), "casque", "head", blend=r * 0.3))
    # Two long white plumes from the middle of the tail.
    te = np.asarray(J["tail_end"])
    for side in (1, -1):
        crest(c, te + np.array([side * r * 0.2, r * 0.5, 0]), te + np.array([side * r * 0.3, -SPAN * 0.35, -r * 0.3]), r * 0.22,
              region="plume", bone="tail1")
    finish(c, R, iris="#a8201a")
    return flying(c, SPAN, flap=0.6, hover=0.45)
