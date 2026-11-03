"""Bonobo, walking upright as bonobos often do: a slim black ape with long
arms, a dark face with pink lips, small ears and hair parted down the
middle. It throws fruit.

Real size: about 1.1 m standing.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

# Built standing up: the "front legs" are its arms, hanging at its sides.
J = {
    "pelvis": (0, 0.0, 0.42),
    "spine_mid": (0, 0.01, 0.55),
    "withers": (0, 0.0, 0.68),
    "neck_base": (0, 0.01, 0.72),
    "head_base": (0, 0.02, 0.76),
    "skull": (0, 0.03, 0.83),
    "snout_tip": (0, 0.11, 0.785),
    "jaw_hinge": (0, 0.05, 0.765),
    "chin": (0, 0.095, 0.745),
    "ear_base": (-0.062, 0.02, 0.835),
    "ear_tip": (-0.086, 0.015, 0.855),
    "shoulder": (-0.13, 0.0, 0.66),
    "elbow": (-0.175, 0.025, 0.49),
    "wrist": (-0.185, 0.06, 0.33),
    "front_toe": (-0.185, 0.085, 0.27),
    "hip": (-0.07, 0.0, 0.42),
    "knee": (-0.08, 0.03, 0.22),
    "hock": (-0.08, -0.0, 0.04),
    "hind_toe": (-0.08, 0.075, 0.012),
    "tail_base": (0, -0.05, 0.43),
    "tail_mid": (0, -0.058, 0.425),
    "tail_end": (0, -0.064, 0.42),
}

R = {
    "rump": (0.1, 0.08, 0.09), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.11, 0.09, 0.1), "belly_drop": 0.0,
    "chest": (0.12, 0.085, 0.1), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.06,
    "neck_base": 0.05, "neck_top": 0.045, "neck_blend": 0.04,
    "skull": (0.07, 0.07, 0.075), "head_blend": 0.04,
    "snout_root": (0, 0.05, -0.035), "snout_base": 0.038, "snout_end": 0.03, "snout_blend": 0.025,
    "jaw_base": 0.026, "jaw_end": 0.018, "jaw_blend": 0.012,
    "ear_width": 0.035, "ear_thick": 0.008, "ear_round": 0.015, "ear_yaw": 0.0, "ear_sink": 0.01, "ear_voxel": 0.002,
    "scapula": (0.04, 0.04, 0.04), "scapula_up": 0.0,
    "upper_arm": (0.044, 0.036), "forearm": (0.036, 0.031), "front_paw": (0.036, 0.032),
    "thigh": (0.06, 0.06, 0.07), "thigh_drop": 0.02,
    "upper_leg": (0.055, 0.04), "shin": (0.038, 0.032), "hind_paw": (0.03, 0.028),
    "limb_blend": 0.03, "joint_blend": 0.015,
    "tail": (0.005, 0.004, 0.003), "tail_blend": 0.005,
}

COLORS = {
    "fur": "#38302b",
    "face": "#a3826f",
    "lips": "#e0929a",
    "palm": "#8a6f60",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("fur")
    # A light face, muzzle and jaw, with pink lips at the front.
    p.region("face", "face")
    p.region("snout", "face")
    p.region("jaw", "face")
    p.region_where("snout", "lips", lambda v, n: p.smooth(v[:, 1] - 0.105, 0.0, 0.006) * p.smooth(0.785 - v[:, 2], 0.0, 0.006), 0.85)
    p.region_where("jaw", "lips", lambda v, n: p.smooth(v[:, 1] - 0.09, 0.0, 0.006) * p.smooth(v[:, 2] - 0.745, 0.0, 0.006), 0.85)
    p.region("front_paw", "palm", 0.6)
    p.region("hind_paw", "palm", 0.6)
    p.speckle(0.05)
    return p.colors


def make():
    c = quadruped("bonobo", J, R, paint=paint, tiles_long=1.3)
    c.voxel = 0.004
    # Fluffy cheek tufts frame a light face disc.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.06, 0.02, 0.8), (0.03, 0.03, 0.035), "head", "head", blend=0.03))
    c.shapes.append(ellipsoid((0, 0.094, 0.812), (0.056, 0.026, 0.056), "face", "head", blend=0.02))
    add_face(c, eye_dir=(-0.33, 0.92, 0.06), eye_radius=0.013, eye_sink=0.006, nose_radius=0.01, nose_sink=0.004,
             iris="#3b2412", pupil="round")
    c.fur = {"strands": False, "variation": 0.15, "sheen": 0.25, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "biped", "attack": "throw", "rear": 0.0, "stride": 1.0, "cycle_tiles": 0.9}
    c.palette = {"eye_line": "#1d1715", "mouth": "#7a3a3e"}
    return c
