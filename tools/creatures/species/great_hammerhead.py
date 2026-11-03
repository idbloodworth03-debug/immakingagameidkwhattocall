"""Great hammerhead shark, made cute: a sleek bronze-gray shark with a wide
flat hammer-shaped head with an eye at each end, a very tall curved dorsal
fin, a long upper tail lobe and a white belly. On land it wiggles along on
its belly.

Real size: about 4.5 m long.
Built on the fish body plan.
"""
import numpy as np

from anatomy import add_face
from bodies import fish
from paint import Painter
from sdf import ellipsoid

J = {
    "snout_tip": (0, 0.5, 0.15), "skull": (0, 0.4, 0.16), "head_base": (0, 0.32, 0.16), "withers": (0, 0.2, 0.17),
    "spine_mid": (0, 0.0, 0.17), "pelvis": (0, -0.2, 0.16), "tail_base": (0, -0.3, 0.16), "tail_mid": (0, -0.45, 0.17),
    "tail_end": (0, -0.58, 0.18), "caudal_a": (0, -0.76, 0.42), "caudal_b": (0, -0.66, 0.08),
    "jaw_hinge": (0, 0.36, 0.1), "chin": (0, 0.45, 0.1),
    "dorsal_front": (0, 0.08, 0.27), "dorsal_back": (0, -0.08, 0.26), "dorsal_tip": (0, -0.06, 0.52),
    "anal_front": (0, -0.3, 0.1), "anal_back": (0, -0.38, 0.11), "anal_tip": (0, -0.4, 0.04),
    "pect_base": (-0.08, 0.2, 0.08), "pect_back": (-0.08, 0.1, 0.08), "pect_tip": (-0.3, 0.04, 0.02),
}
R = {
    "body": (0.11, 0.3, 0.11), "front": (0.11, 0.16, 0.11),
    "skull": (0.08, 0.1, 0.06), "snout_root": (0, 0.05, -0.01), "snout": (0.06, 0.03), "snout_blend": 0.04,
    "jaw": (0.04, 0.02), "tail": (0.07, 0.04, 0.022), "blend": 0.06,
    "fin_thick": 0.012, "fin_round": 0.02, "fin_blend": 0.015, "fin_root": 0.03,
}
COLORS = {"gray": "#7d8288", "bronze": "#8a8070", "white": "#f1f1ee", "tip": "#4f545a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    p.fill("gray")
    p.blend("bronze", p.smooth(n[:, 2], 0.4, 0.4) * 0.4)
    p.blend("white", p.smooth(-n[:, 2], 0.1, 0.4))
    p.region("fin", "gray")
    p.region("hammer", "gray")
    p.blend("white", p.mesh.region_weight("hammer") * p.smooth(-n[:, 2], 0.2, 0.3))
    return p.colors


def make():
    c = fish("great_hammerhead", J, R, paint=paint, tiles_long=2.2)
    c.voxel = 0.006
    # The hammer: a wide, flat head with the eyes at its ends.
    c.shapes.append(ellipsoid((0, 0.43, 0.16), (0.27, 0.06, 0.028), "hammer", "head", blend=0.03))
    add_face(c, eye_dir=(-1.0, 0.08, 0.1), eye_radius=0.016, eye_sink=0.006, nose_radius=0, iris="#1b1712", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.4, "bump": 0.05, "roughness": 0.4, "specular": 0.4}
    c.motion = {"body": "fish", "attack": "snap", "hop": 0.15, "gape": 0.6, "cycle_tiles": 1.3}
    return c
