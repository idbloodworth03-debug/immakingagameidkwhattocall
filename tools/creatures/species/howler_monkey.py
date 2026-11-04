"""Mantled howler monkey: a black monkey with a golden-brown fringe of long
hair along its sides, a bearded throat (its huge voice box), a dark bare
face and a long curling tail. Walking upright here, as a cartoon.

Real size: about 60 cm tall, plus a 60 cm tail.
Built from the bonobo's upright body, smaller, with a long tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
from bonobo import J as BJ, R as BR
from derive import scaled, scaled_r

K = 0.7
J = scaled(BJ, K)
J.update({"tail_base": (0, -0.05, 0.3), "tail_mid": (0, -0.22, 0.24), "tail_end": (0, -0.33, 0.36)})
R = scaled_r(BR, K)
R.update({"tail": (0.022, 0.018, 0.014, 0.01), "tail_blend": 0.01})

COLORS = {"black": "#1f1b19", "gold": "#b0844a", "face": "#3a302c"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("black")
    # The golden fringe along each flank.
    p.blend("gold", Wt("torso") * p.smooth(-n[:, 1] + np.abs(n[:, 0]) * 0.5, 0.2, 0.3) * p.smooth(0.46 - v[:, 2], 0.0, 0.05) * p.smooth(v[:, 2] - 0.28, 0.0, 0.04))
    for region in ("face", "snout", "jaw"):
        p.region(region, "face")
    p.region("beard", "black")
    p.speckle(0.05)
    return p.colors


def make():
    c = quadruped("howler_monkey", J, R, paint=paint, tiles_long=1.1)
    c.voxel = 0.003
    sk = np.asarray(J["skull"], float)
    c.shapes.append(ellipsoid(tuple(sk + (0, 0.06, -0.01)), (0.038, 0.018, 0.038), "face", "head", blend=0.014))
    # The beard over the big throat.
    c.shapes.append(ellipsoid(tuple(sk + (0, 0.04, -0.07)), (0.035, 0.03, 0.04), "beard", "jaw", blend=0.02))
    add_face(c, eye_dir=(-0.33, 0.92, 0.06), eye_radius=0.0095, eye_sink=0.004, nose_radius=0.007, nose_sink=0.003,
             iris="#3b2412", pupil="round")
    c.fur = {"strands": False, "variation": 0.12, "sheen": 0.25, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "biped", "attack": "swipe", "rear": 0.0, "stride": 1.05, "cycle_tiles": 0.8}
    c.palette = {"eye_line": "#1d1715", "mouth": "#5a3a3a"}
    # A Stun animal: a big wind-up before the blow that stuns.
    c.motion["special"] = True
    return c
