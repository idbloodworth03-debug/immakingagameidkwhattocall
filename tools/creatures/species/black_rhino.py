"""Black Rhinoceros: a massive barrel body on short, thick pillar legs, a
long heavy head carried low with two horns (a long curved front horn and a
shorter rear one), the pointed, grasping upper lip that gives it its other
name (hook-lipped rhino), tube-shaped ears with a fringe and a thin tasseled
tail. Gray, hairless skin with deep folds at the shoulders and hips.

Real size: about 1.6 m at the shoulder, 3.3 m long.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.95, 1.33),
    "spine_mid": (0, -0.3, 1.36),
    "withers": (0, 0.45, 1.45),
    "neck_base": (0, 0.6, 1.22),
    "head_base": (0, 0.95, 1.06),
    "skull": (0, 1.06, 1.02),
    "snout_tip": (0, 1.52, 0.72),
    "jaw_hinge": (0, 1.05, 0.88),
    "chin": (0, 1.42, 0.62),
    "ear_base": (-0.17, 0.98, 1.22),
    "ear_tip": (-0.25, 0.94, 1.43),
    "shoulder": (-0.3, 0.55, 1.05),
    "elbow": (-0.32, 0.4, 0.7),
    "wrist": (-0.3, 0.45, 0.25),
    "front_toe": (-0.3, 0.55, 0.04),
    "hip": (-0.3, -0.95, 1.2),
    "knee": (-0.32, -0.75, 0.8),
    "hock": (-0.3, -1.1, 0.4),
    "hind_toe": (-0.3, -1.0, 0.04),
    "tail_base": (0, -1.3, 1.3),
    "tail_mid": (0, -1.36, 1.05),
    "tail_end": (0, -1.38, 0.85),
}

R = {
    "rump": (0.42, 0.45, 0.42), "rump_back": 0.02, "rump_drop": 0.25,
    "belly": (0.55, 0.85, 0.5), "belly_drop": 0.42,
    "chest": (0.5, 0.55, 0.55), "chest_back": 0.12, "chest_drop": 0.42,
    "torso_blend": 0.2,
    "neck_base": 0.4, "neck_top": 0.3, "neck_blend": 0.1,
    "skull": (0.27, 0.3, 0.26), "skull_pitch": -0.55, "head_blend": 0.07,
    "snout_root": (0, 0.18, -0.1), "snout_base": 0.23, "snout_end": 0.16, "snout_blend": 0.07,
    "jaw_base": 0.15, "jaw_end": 0.11, "jaw_blend": 0.05,
    "ear_width": 0.13, "ear_thick": 0.014, "ear_round": 0.035, "ear_yaw": 0.25, "ear_sink": 0.04,
    "ear_voxel": 0.006,
    "scapula": (0.25, 0.33, 0.42), "scapula_up": 0.22, "scapula_pitch": 0.3,
    "upper_arm": (0.25, 0.18), "forearm": (0.16, 0.14), "front_paw": (0.14, 0.13),
    "thigh": (0.32, 0.42, 0.45), "thigh_drop": 0.2, "thigh_pitch": -0.25,
    "upper_leg": (0.28, 0.18), "shin": (0.16, 0.13), "hind_paw": (0.14, 0.13),
    "limb_blend": 0.2, "joint_blend": 0.07,
    "tail": (0.04, 0.03, 0.025, 0.05), "tail_blend": 0.03,
}

COLORS = {
    "gray": "#57534e",
    "mud": "#5b5047",
    "fold": "#3b3732",
    "light": "#76716a",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    W = p.mesh.region_weight
    p.fill("gray")
    p.where("light", lambda v, n: p.smooth(n[:, 2], 0.5, 0.4), 0.25)
    # Dried mud on the legs and belly.
    p.where("mud", lambda v, n: p.smooth(0.75 - v[:, 2], 0.0, 0.3) * (0.6 + 0.4 * p.noise(8.0, 2)), 0.7)
    # Skin folds behind the shoulders and in front of the hips, and wrinkles.
    for y in (0.3, -0.75):
        p.blend("fold", W("torso") * p.smooth(0.05 - np.abs(v[:, 1] - y - 0.05 * p.noise(6.0, 3)), 0.0, 0.04) * 0.7)
    p.stripes("fold", lambda q: q[:, 2], frequency=26.0, width=0.08, wobble=0.6, breakup=1.0,
              mask=(W("front_lower") + W("hind_lower") + W("neck")) * 0.6)
    p.region("ear", "fold", 0.3)
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("black_rhino", J, R, paint=paint, tiles_long=2.8)
    c.voxel = 0.012
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.17, 1.15, 0.84), (0.13, 0.24, 0.16), "cheek", "head", blend=0.06))
    # Two horns on the nose, the front one long and curving back.
    c.extras.append(Extra("cone", "horn", "head", center=(0, 1.4, 0.86), tip=(0, 1.48, 1.17), radius=0.125, tip_radius=0.06))
    c.extras.append(Extra("cone", "horn", "head", center=(0, 1.48, 1.17), tip=(0, 1.41, 1.44), radius=0.061, tip_radius=0.008))
    c.extras.append(Extra("cone", "horn", "head", center=(0, 1.2, 1.0), tip=(0, 1.24, 1.25), radius=0.095, tip_radius=0.01))
    add_face(c, eye_dir=(-0.8, 0.5, 0.2), eye_radius=0.02, eye_sink=0.013, nose_radius=0, iris="#1a0f08", pupil="round")
    c.fur = {"strands": False, "variation": 0.2, "sheen": 0.05, "bump": 0.9, "roughness": 0.85, "specular": 0.2,
             "streak_x": 90.0, "streak_y": 90.0, "streak_z": 90.0}
    c.motion = {"gait": "walk", "attack": "charge", "stride": 0.85, "charge_reach": 0.3}
    c.palette = {"eye_line": "#2e2a26", "eye_line_size": 1.4}
    return c
