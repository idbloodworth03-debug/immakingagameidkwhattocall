"""Barn owl: a white heart-shaped face with a buff rim, dark eyes, golden
buff and soft grey upperparts finely speckled, white underparts, short
tail and broad rounded wings.

Real size: about 35 cm long, 1 m wingspan.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
from paint import Painter
from sdf import ellipsoid

SPAN = 1.0
J, R = layout(SPAN, body=0.85, girth=1.3, neck=0.6, head=1.65, beak=(0.45, 1.0), hook=0.8, tail=(0.6, 1.0),
              chord=1.15, fingers=0, legs=0.9, fan=0.4)
COLORS = {"white": "#f7f2e8", "buff": "#d9a75e", "grey": "#a9a49b", "rim": "#b9824a", "speck": "#5a4a3a",
          "beak": "#e8d8c0"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    p.fill("white")
    p.blend("buff", up)
    p.blend("grey", up * p.mesh.region_weight("wing") * p.smooth(out - 0.3, 0.0, 0.2) * 0.6)
    p.spots("speck", cell=SPAN * 0.04, radius=SPAN * 0.005, mask=up * 0.8)
    face = p.mesh.region_weight("face")
    p.blend("white", face)
    p.blend("rim", p.mesh.region_weight("head") * up * 0.5)
    p.region("beak", "beak")
    p.region("leg", "white")
    return p.colors


def make():
    c = bird("barn_owl", J, R, paint=paint, tiles_long=1.3)
    # The flat, heart-shaped face disc.
    sk = J["skull"]
    c.shapes.append(ellipsoid((0, sk[1] + R["skull"][1] * 0.55, sk[2] - R["skull"][2] * 0.05),
                              (R["skull"][0] * 1.05, R["skull"][1] * 0.35, R["skull"][2] * 1.05), "face", "head", blend=R["skull"][0] * 0.3))
    finish(c, R, iris="#160c06", eye_dir=(-0.42, 0.88, 0.15), eye=0.3)
    return flying(c, SPAN, flap=0.6, hover=0.45)
