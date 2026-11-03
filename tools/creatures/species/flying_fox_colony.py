"""Grey-headed flying fox in flight: a big fruit bat with a fox-like face,
a silver-grey head, a rusty orange collar, a dark body and black wings of
skin stretched over long fingers. The game shows a pair of them.

Real size: about 25 cm body, 1 m wingspan.
"""
import numpy as np

from anatomy import add_face
from bodies import bat
from paint import Painter

J = {
    "pelvis": (0, -0.07, 0.0),
    "spine_mid": (0, 0.0, 0.005),
    "withers": (0, 0.06, 0.01),
    "neck_base": (0, 0.075, 0.012),
    "head_base": (0, 0.1, 0.02),
    "skull": (0, 0.125, 0.025),
    "snout_tip": (0, 0.178, 0.012),
    "jaw_hinge": (0, 0.135, 0.008),
    "chin": (0, 0.166, 0.0),
    "ear_base": (-0.022, 0.118, 0.045),
    "ear_tip": (-0.03, 0.112, 0.076),
    "shoulder": (-0.03, 0.05, 0.015),
    "elbow": (-0.16, 0.025, 0.02),
    "wrist": (-0.3, 0.065, 0.02),
    "wing_tip": (-0.5, 0.0, 0.015),
    "finger2": (-0.45, -0.12, 0.012),
    "finger3": (-0.32, -0.17, 0.01),
    "hip": (-0.025, -0.06, -0.005),
    "foot": (-0.06, -0.16, -0.01),
}

R = {
    "body": (0.046, 0.08, 0.042), "chest": (0.047, 0.045, 0.044), "neck": (0.032, 0.027),
    "skull": (0.036, 0.038, 0.034), "snout_root": (0, 0.03, -0.008), "snout": (0.021, 0.009), "snout_blend": 0.012,
    "jaw": (0.012, 0.006), "blend": 0.02,
    "wing_thick": 0.003, "wing_round": 0.006, "wing_blend": 0.014, "arm": (0.012, 0.009, 0.006), "leg": (0.01, 0.007),
    "ear_width": 0.03, "ear_thick": 0.004, "ear_round": 0.01, "ear_yaw": 0.3, "ear_sink": 0.008, "ear_voxel": 0.0015,
}

COLORS = {
    "body": "#4a3c34",
    "head": "#8d8a86",
    "collar": "#c4702c",
    "wing": "#2b2422",
    "bone": "#1d1816",
    "snout": "#3a302b",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("body")
    p.region("wing", "wing")
    p.region("wing_bone", "bone")
    p.region("head", "head")
    p.region("snout", "snout", 0.8)
    p.region("jaw", "snout", 0.6)
    p.region("ear", "snout")
    # The rusty collar around the neck and shoulders.
    p.region("neck", "collar", 0.95)
    p.region_where("torso", "collar", lambda v, n: p.smooth(v[:, 1] - 0.03, 0.0, 0.02), 0.9)
    p.region("leg", "bone")
    p.speckle(0.06)
    return p.colors


def make():
    c = bat("flying_fox_colony", J, R, paint=paint, tiles_long=1.5)
    c.voxel = 0.0025
    add_face(c, eye_dir=(-0.6, 0.75, 0.25), eye_radius=0.008, eye_sink=0.004, nose_radius=0.007, nose_sink=0.003,
             iris="#3a1f0e", pupil="round")
    c.fur = {"strands": False, "variation": 0.15, "sheen": 0.2, "bump": 0.2, "roughness": 0.7}
    c.motion = {"body": "bird", "attack": "dive", "altitude": 0.4, "flap": 0.9, "hover_power": 0.6, "cycle_tiles": 1.4}
    c.palette = {"eye_line": "#1d1816"}
    return c
