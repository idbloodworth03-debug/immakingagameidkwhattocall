"""Philippine eagle: a huge forest eagle with a shaggy cream crest like a
lion's mane, a tall arched blue-grey beak, dark brown back and wings,
cream underparts and big yellow feet.

Real size: about 1 m long, 2 m wingspan.
"""
import numpy as np

from anatomy import bird
from birdkit import crest, finish, flying, layout, masks
from paint import Painter

SPAN = 2.0
J, R = layout(SPAN, body=1.0, girth=1.2, neck=1.0, head=1.55, beak=(1.1, 2.0), hook=1.25, tail=(1.2, 1.0),
              fingers=6, fan=0.6)
COLORS = {"brown": "#5d3f27", "crest": "#d1aa72", "streak": "#7a5634", "cream": "#f1e6d2", "beak": "#7d8b98",
          "foot": "#e2b23a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    p.fill("cream")
    p.blend("brown", up)
    head = p.mesh.region_weight("head") + p.mesh.region_weight("crest") + p.mesh.region_weight("neck")
    p.blend("crest", head)
    p.stripes("streak", lambda q: q[:, 0], frequency=1.0 / (SPAN * 0.02), width=0.15, mask=head * 0.6)
    p.region("beak", "beak")
    p.region("leg", "foot")
    return p.colors


def make():
    c = bird("philippine_eagle", J, R, paint=paint, tiles_long=2.2)
    sk = np.asarray(J["skull"])
    r = R["skull"][0]
    for x, back, rise in ((0.0, 1.5, 1.1), (0.5, 1.4, 0.9), (-0.5, 1.4, 0.9), (0.9, 1.2, 0.6), (-0.9, 1.2, 0.6)):
        crest(c, sk + np.array([x * r * 0.5, -r * 0.2, r * 0.5]), sk + np.array([x * r * 0.9, -r * back, r * rise + r * 0.4]), r * 0.35)
    finish(c, R, iris="#3a5a8a")
    return flying(c, SPAN, flap=0.55, hover=0.4)
