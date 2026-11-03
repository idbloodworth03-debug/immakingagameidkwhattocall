"""Honey badger: a low, broad, fearless badger on short strong legs with
long front claws. Jet black below, with a broad silver-white mantle from the
top of the head down the back to the short tail, tiny ears and small eyes.

Real size: about 28 cm at the shoulder, 75 cm long.
Built from the raccoon's skeleton, lower and wider.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.17, 0.25),
    "spine_mid": (0, 0.0, 0.25),
    "withers": (0, 0.15, 0.24),
    "neck_base": (0, 0.18, 0.22),
    "head_base": (0, 0.25, 0.23),
    "skull": (0, 0.28, 0.235),
    "snout_tip": (0, 0.37, 0.2),
    "jaw_hinge": (0, 0.28, 0.2),
    "chin": (0, 0.345, 0.185),
    "ear_base": (-0.045, 0.265, 0.27),
    "ear_tip": (-0.052, 0.262, 0.285),
    "shoulder": (-0.06, 0.16, 0.17),
    "elbow": (-0.07, 0.12, 0.11),
    "wrist": (-0.065, 0.14, 0.035),
    "front_toe": (-0.065, 0.18, 0.012),
    "hip": (-0.06, -0.17, 0.2),
    "knee": (-0.07, -0.1, 0.12),
    "hock": (-0.065, -0.19, 0.04),
    "hind_toe": (-0.06, -0.13, 0.012),
    "tail_base": (0, -0.26, 0.24),
    "tail_mid": (0, -0.31, 0.22),
    "tail_end": (0, -0.35, 0.19),
}
R = {
    "rump": (0.1, 0.11, 0.08), "rump_back": 0.01, "rump_drop": 0.02,
    "belly": (0.11, 0.17, 0.08), "belly_drop": 0.03,
    "chest": (0.1, 0.1, 0.08), "chest_back": 0.02, "chest_drop": 0.03,
    "torso_blend": 0.08,
    "neck_base": 0.07, "neck_top": 0.055, "neck_blend": 0.05,
    "skull": (0.058, 0.055, 0.045), "skull_pitch": -0.1, "head_blend": 0.035,
    "snout_root": (0, 0.035, -0.015), "snout_base": 0.03, "snout_end": 0.016, "snout_blend": 0.022,
    "jaw_base": 0.02, "jaw_end": 0.01, "jaw_blend": 0.01,
    "ear_width": 0.022, "ear_thick": 0.004, "ear_round": 0.008, "ear_yaw": 0.4, "ear_sink": 0.008,
    "ear_fur": 0.004,
    "scapula": (0.035, 0.05, 0.05), "scapula_up": 0.03, "scapula_pitch": 0.3,
    "upper_arm": (0.045, 0.032), "forearm": (0.03, 0.024), "front_paw": (0.024, 0.02),
    "thigh": (0.055, 0.07, 0.07), "thigh_drop": 0.02, "thigh_pitch": -0.2,
    "upper_leg": (0.05, 0.034), "shin": (0.028, 0.022), "hind_paw": (0.022, 0.02),
    "limb_blend": 0.04, "joint_blend": 0.014,
    "tail": (0.03, 0.024, 0.016, 0.01), "tail_blend": 0.02,
}

COLORS = {"black": "#1b1918", "silver": "#d9d7d2", "gray": "#8c8a86", "claw": "#e8dccb"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("black")
    # The silver mantle: everything on top, from the crown to the tail.
    top = p.smooth(n[:, 2], 0.05, 0.3) * p.smooth(v[:, 2] - 0.2, 0.0, 0.03)
    snout = p.mesh.region_weight("snout") + p.mesh.region_weight("jaw")
    legs = sum(p.mesh.region_weight(r) for r in ("front_upper", "front_lower", "front_paw", "hind_lower", "hind_paw", "thigh"))
    p.blend("silver", np.clip(top * (1 - snout) * (1 - legs) * p.smooth(0.31 - v[:, 1], 0.0, 0.02), 0, 1))
    p.blend("gray", top * (1 - snout) * p.smooth(0.08 - np.abs(v[:, 2] - 0.22) - np.abs(n[:, 2]) * 0.02, 0.0, 0.02) * 0.3)
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("honey_badger", J, R, paint=paint, tiles_long=1.15)
    c.voxel = 0.0025
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.045, 0.275, 0.215), (0.035, 0.04, 0.03), "cheek", "head", blend=0.03, yaw=side * 0.3))
        # Long digging claws on the front feet.
        for k in (-1, 0, 1):
            base = (side * (0.065 + k * 0.008), 0.18, 0.014)
            c.extras.append(Extra("cone", "claw", "fl_foot" + (".R" if side > 0 else ".L"), center=base,
                                  tip=(base[0], 0.205, 0.004), radius=0.004, tip_radius=0.0008, color="#e8dccb"))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.008, eye_sink=0.005, nose_radius=0.009, nose_sink=0.004,
             iris="#1a1210", pupil="round")
    c.fur = {"variation": 0.1, "sheen": 0.3, "bump": 0.3, "length": 0.02, "density": 60000, "hair_gamma": 1.9,
             "lengths": {"tail": 1.2}}
    c.motion = {"gait": "trot", "attack": "bite", "stride": 1.2, "gape": 0.8}
    c.palette = {"eye_line": "#151210"}
    return c
