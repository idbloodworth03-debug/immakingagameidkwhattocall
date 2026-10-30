"""Hippopotamus: a huge barrel body on very short legs, an enormous head
with a wide square muzzle, and small ears, eyes and nostrils set on top of
the head so it can watch from under the water. Short flat tail. Smooth,
nearly hairless gray-brown skin, pinkish around the eyes, ears, mouth, belly
and in the folds. It opens its jaws enormously to bite.

Real size: about 1.5 m at the shoulder, 3.5 m long.
"""
import numpy as np

from anatomy import Extra, add_face, add_mouth, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -1.0, 1.15),
    "spine_mid": (0, -0.3, 1.25),
    "withers": (0, 0.4, 1.28),
    "neck_base": (0, 0.6, 1.1),
    "head_base": (0, 0.85, 1.05),
    "skull": (0, 0.98, 1.08),
    "snout_tip": (0, 1.55, 0.92),
    "jaw_hinge": (0, 1.0, 0.86),
    "chin": (0, 1.5, 0.66),
    "ear_base": (-0.15, 0.93, 1.28),
    "ear_tip": (-0.18, 0.9, 1.36),
    "shoulder": (-0.36, 0.5, 0.85),
    "elbow": (-0.38, 0.38, 0.55),
    "wrist": (-0.36, 0.42, 0.18),
    "front_toe": (-0.36, 0.5, 0.04),
    "hip": (-0.36, -1.0, 1.0),
    "knee": (-0.38, -0.82, 0.62),
    "hock": (-0.36, -1.08, 0.3),
    "hind_toe": (-0.36, -1.0, 0.04),
    "tail_base": (0, -1.38, 1.1),
    "tail_mid": (0, -1.45, 0.95),
    "tail_end": (0, -1.48, 0.82),
}

R = {
    "rump": (0.55, 0.5, 0.48), "rump_back": 0.02, "rump_drop": 0.25,
    "belly": (0.66, 0.95, 0.56), "belly_drop": 0.4,
    "chest": (0.6, 0.6, 0.55), "chest_back": 0.12, "chest_drop": 0.38,
    "torso_blend": 0.25,
    "neck_base": 0.5, "neck_top": 0.42, "neck_blend": 0.15,
    "skull": (0.33, 0.3, 0.26), "skull_pitch": -0.1, "head_blend": 0.12,
    "snout_root": (0, 0.25, -0.08), "snout_base": 0.28, "snout_end": 0.27, "snout_blend": 0.1,
    "jaw_base": 0.24, "jaw_end": 0.22, "jaw_blend": 0.06,
    "ear_width": 0.07, "ear_thick": 0.012, "ear_round": 0.025, "ear_yaw": 0.4, "ear_sink": 0.03,
    "ear_voxel": 0.005,
    "scapula": (0.3, 0.35, 0.4), "scapula_up": 0.15, "scapula_pitch": 0.3,
    "upper_arm": (0.3, 0.22), "forearm": (0.2, 0.18), "front_paw": (0.18, 0.16),
    "thigh": (0.4, 0.45, 0.45), "thigh_drop": 0.2, "thigh_pitch": -0.25,
    "upper_leg": (0.34, 0.22), "shin": (0.2, 0.17), "hind_paw": (0.18, 0.16),
    "limb_blend": 0.22, "joint_blend": 0.08,
    "tail": (0.06, 0.05, 0.04, 0.03), "tail_blend": 0.04,
}

COLORS = {
    "skin": "#6e5f58",
    "top": "#55504d",
    "pink": "#c58c80",
    "dark": "#3a3330",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    W = p.mesh.region_weight
    p.fill("skin")
    p.top_darken("top", start=0.2, strength=0.6)
    # Pink belly, mouth, and around the eyes and ears.
    p.where("pink", lambda v, n: p.smooth(-n[:, 2], 0.35, 0.35), 0.75)
    p.region_where("jaw", "pink", lambda v, n: p.smooth(-n[:, 2], -0.1, 0.4), 0.9)
    p.region_where("snout", "pink", lambda v, n: p.smooth(-n[:, 2] + n[:, 1] * 0.5, 0.0, 0.4), 0.7)
    p.region("ear", "pink", 0.6)
    for center, radius in creature.eyes:
        d = np.linalg.norm(v - center, axis=1)
        p.blend("pink", np.clip((radius * 2.6 - d) / (radius * 0.8), 0, 1) * 0.8)
    # Nostrils on top of the muzzle.
    for side in (1, -1):
        d = np.linalg.norm(v - np.array([side * 0.09, 1.52, 1.16]), axis=1)
        p.blend("dark", np.clip((0.035 - d) / 0.01, 0, 1))
    p.speckle(0.08)
    return p.colors


def make():
    c = quadruped("hippopotamus", J, R, paint=paint, tiles_long=2.6)
    c.voxel = 0.012
    # The wide square muzzle: two big pads on either side of the nose.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.16, 1.38, 0.92), (0.21, 0.26, 0.22), "snout", "head", blend=0.08))
        c.shapes.append(ellipsoid((side * 0.18, 1.32, 0.68), (0.18, 0.24, 0.13), "jaw", "jaw", blend=0.05))
        # Raised eye bumps on top of the head.
        c.shapes.append(ellipsoid((side * 0.18, 1.02, 1.24), (0.08, 0.08, 0.07), "head", "head", blend=0.06))
    # A real mouth to gape with, and the big lower tusks hidden behind the
    # upper lip until it opens.
    add_mouth(c, center=(0, 1.48, 0.755), radii=(0.42, 0.38, 0.022))
    for side in (1, -1):
        c.extras.append(Extra("cone", "tusk", "jaw", center=(side * 0.25, 1.5, 0.72), tip=(side * 0.27, 1.56, 0.92),
                              radius=0.045, tip_radius=0.012))
    add_face(c, eye_dir=(-0.6, 0.35, 0.72), eye_radius=0.026, eye_sink=0.012, nose_radius=0, iris="#2a1408", pupil="round")
    c.fur = {"strands": False, "variation": 0.12, "sheen": 0.05, "bump": 0.4, "roughness": 0.5, "specular": 0.45,
             "subsurface": 0.15, "streak_x": 60.0, "streak_y": 60.0, "streak_z": 60.0}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.8, "gape": 1.15}
    c.palette = {"mouth": "#b5606a"}
    c.palette = {"eye_line": "#5a3a34", "eye_line_size": 1.5}
    return c
