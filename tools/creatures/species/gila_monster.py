"""Gila monster: a chunky, slow desert lizard with a fat sausage tail,
a blunt head, short legs and beaded skin patterned in black and bright
pink-orange bands and blotches. It sways along with a waddling walk.

Real size: about 50 cm long.
Built from the Komodo dragon's skeleton, shorter and stouter.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
import komodo_dragon as K

J = dict(K.J)
J.update({"snout_tip": (0, 0.84, 0.31), "chin": (0, 0.8, 0.27), "tail_mid": (0, -0.85, 0.2), "tail_end": (0, -1.08, 0.1),
          "elbow": (-0.28, 0.41, 0.19), "knee": (-0.29, -0.36, 0.19)})
R = dict(K.R)
R.update({"rump": (0.19, 0.25, 0.14), "belly": (0.22, 0.42, 0.15), "chest": (0.2, 0.25, 0.14),
          "skull": (0.11, 0.11, 0.08), "snout_base": 0.085, "snout_end": 0.065,
          "tail": (0.13, 0.12, 0.07, 0.02)})

COLORS = {"black": "#211a17", "pink": "#ec8a5e", "bead": "#3a2e28"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("black")
    # Broad pink-orange bands, broken into blotches.
    p.stripes("pink", lambda q: q[:, 1], frequency=4.5, width=0.45, wobble=0.6,
              mask=(1 - p.mesh.region_weight("head") * 0.6) * p.smooth(p.n[:, 2], -0.4, 0.5))
    p.spots("pink", cell=0.07, radius=0.02, mask=p.smooth(p.n[:, 2], -0.2, 0.5) * 0.8, seed=19)
    p.speckle(0.35)
    return p.colors


def make():
    c = quadruped("gila_monster", J, R, paint=paint, tiles_long=1.3)
    c.voxel = 0.008
    K.tongue(c, J, 0.06, 0.01, color="#2b2430")
    add_face(c, eye_dir=(-0.7, 0.55, 0.4), eye_radius=0.014, eye_sink=0.006, nose_radius=0.0, iris="#2a1a12", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.2, "bump": 0.45, "roughness": 0.75}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.85, "wiggle": 0.14, "gape": 0.6, "cycle_tiles": 0.6}
    return c
