"""Malayan tapir: a big, round, pig-shaped forest animal with a short
flexible trunk for a nose, small oval ears with white rims and a striking
two-tone coat: black head, shoulders and legs, and a big white "saddle"
over the back and belly, like a blanket.

Real size: about 1 m at the shoulder, 2.2 m long.
Built from the wild boar's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid
import wild_boar as WB

J = dict(WB.J)
J.update({"snout_tip": (0, 0.95, 0.5), "chin": (0, 0.74, 0.48), "ear_tip": (-0.1, 0.54, 0.92)})
R = dict(WB.R)
R.update({"rump": (0.2, 0.25, 0.2), "belly": (0.21, 0.42, 0.21), "chest": (0.2, 0.26, 0.24), "snout_base": 0.07, "snout_end": 0.045,
          "ear_width": 0.08, "ear_round": 0.03})

COLORS = {"black": "#1f1d1e", "white": "#ece9e1", "rim": "#f4f2ec", "trunk": "#2e2b2c"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    Wt = p.mesh.region_weight
    p.fill("black")
    # The white saddle, from behind the shoulders to the rump, down to the belly.
    p.blend("white", Wt("torso") * p.smooth(0.12 - v[:, 1], 0.0, 0.04) * p.smooth(v[:, 1] + 0.58, 0.0, 0.04)
            * p.smooth(v[:, 2] - 0.42, 0.0, 0.04))
    p.region_where("ear", "rim", lambda v, n: p.smooth(v[:, 2] - 0.88, 0.0, 0.02))
    p.region("trunk", "trunk")
    p.speckle(0.05)
    return p.colors


def make():
    c = quadruped("malayan_tapir", J, R, paint=paint, tiles_long=2.1)
    c.voxel = 0.006
    # The short trunk, curling down a little at the end.
    tip = np.asarray(J["snout_tip"], float)
    c.shapes.append(cone(tip, tip + (0, 0.08, -0.06), 0.045, 0.03, "trunk", "head", blend=0.03))
    c.shapes.append(ellipsoid(tuple(tip + (0, 0.085, -0.065)), (0.035, 0.03, 0.028), "trunk", "head", blend=0.015))
    add_face(c, eye_dir=(-0.75, 0.55, 0.35), eye_radius=0.012, eye_sink=0.006, nose_radius=0.0, iris="#2a160c", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.15, "roughness": 0.55}
    c.motion = {"gait": "trot", "attack": "charge", "stride": 0.9, "charge_reach": 0.3}
    return c
