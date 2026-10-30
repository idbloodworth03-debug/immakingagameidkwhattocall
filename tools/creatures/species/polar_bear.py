"""Polar Bear: long-bodied and long-necked, with a smaller, longer head and
a straight "Roman" nose, small round ears, no shoulder hump, big furry
paws. Creamy white coat tinted yellow, black nose, lips and eye skin.

Real size: about 1.3 m at the shoulder, 2.2 m long. Built from the brown
bear's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.55, 0.95),
    "spine_mid": (0, -0.05, 1.0),
    "withers": (0, 0.40, 1.08),
    "neck_base": (0, 0.5, 0.96),
    "head_base": (0, 0.88, 0.88),
    "skull": (0, 0.95, 0.885),
    "snout_tip": (0, 1.24, 0.79),
    "jaw_hinge": (0, 0.94, 0.81),
    "chin": (0, 1.17, 0.745),
    "ear_base": (-0.085, 0.93, 0.975),
    "ear_tip": (-0.105, 0.915, 1.035),
    "shoulder": (-0.17, 0.50, 0.82),
    "elbow": (-0.18, 0.38, 0.55),
    "wrist": (-0.17, 0.44, 0.14),
    "front_toe": (-0.17, 0.60, 0.05),
    "hip": (-0.18, -0.58, 0.86),
    "knee": (-0.19, -0.40, 0.56),
    "hock": (-0.18, -0.70, 0.16),
    "hind_toe": (-0.17, -0.47, 0.05),
    "tail_base": (0, -0.82, 0.92),
    "tail_mid": (0, -0.87, 0.86),
    "tail_end": (0, -0.90, 0.80),
}

R = {
    "rump": (0.24, 0.34, 0.27), "rump_back": 0.03, "rump_drop": 0.17,
    "belly": (0.29, 0.6, 0.27), "belly_drop": 0.23,
    "chest": (0.29, 0.38, 0.33), "chest_back": 0.1, "chest_drop": 0.25,
    "torso_blend": 0.16,
    "neck_base": 0.23, "neck_top": 0.15, "neck_blend": 0.14,
    "skull": (0.125, 0.15, 0.115), "skull_pitch": -0.05, "head_blend": 0.07,
    "snout_root": (0, 0.11, -0.03), "snout_base": 0.085, "snout_end": 0.058, "snout_blend": 0.06,
    "jaw_base": 0.065, "jaw_end": 0.042, "jaw_blend": 0.025,
    "ear_width": 0.075, "ear_thick": 0.012, "ear_round": 0.024, "ear_yaw": 0.3, "ear_sink": 0.03, "ear_voxel": 0.004,
    "ear_fur": 0.02,
    "scapula": (0.13, 0.2, 0.25), "scapula_up": 0.14, "scapula_pitch": 0.25,
    "upper_arm": (0.15, 0.115), "forearm": (0.11, 0.09), "front_paw": (0.095, 0.09),
    "thigh": (0.2, 0.27, 0.29), "thigh_drop": 0.12, "thigh_pitch": -0.2,
    "upper_leg": (0.18, 0.12), "shin": (0.11, 0.09), "hind_paw": (0.095, 0.09),
    "limb_blend": 0.11, "joint_blend": 0.05,
    "tail": (0.06, 0.055, 0.04, 0.02), "tail_blend": 0.05,
}

COLORS = {
    "cream": "#ddd0b0",
    "shadow": "#a89a7a",
    "yellow": "#cfb680",
    "black": "#141212",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("cream")
    # Yellowish on the back and rump, slightly greyer underneath.
    p.where("yellow", lambda v, n: p.smooth(n[:, 2], 0.3, 0.5), 0.35)
    p.where("shadow", lambda v, n: p.smooth(-n[:, 2], 0.3, 0.4), 0.45)
    # Legs and paws grubbier from the snow and the hunt.
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "shadow", 0.35)
    # Black lips: a thin line along the mouth.
    p.region_where("jaw", "black", lambda v, n: p.smooth(n[:, 2], 0.3, 0.3), 0.7)
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("polar_bear", J, R, paint=paint, tiles_long=2.4)
    # A heavy brow and round cheeks for the dished face.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.085, 0.95, 0.85), (0.065, 0.09, 0.075), "cheek", "head", blend=0.06))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.017, eye_sink=0.012, nose_radius=0.04, nose_sink=0.016,
             iris="#2a1a10", pupil="round")
    c.palette = {"eye_line": "#141212", "eye_line_size": 1.7}
    c.fur = {"variation": 0.12, "sheen": 0.3, "bump": 0.35, "length": 0.07, "density": 9000, "hair_gamma": 2.2,
             "frizz": 0.004, "clump": 0.4,
             "lengths": {"cheek": 1.1, "tail": 0.9, "tail_tip": 0.9, "head": 0.5, "front_paw": 0.4, "hind_paw": 0.4}}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.3, "stride": 0.95}
    return c
