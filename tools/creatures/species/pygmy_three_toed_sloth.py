"""Pygmy three-toed sloth: a small, shaggy island sloth with a round face
that seems to smile, dark stripes running back from its eyes, long arms
with three long curved claws each, and tan fur tinted green with algae.
On the ground it crawls along very slowly.

Real size: about 50 cm long.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter

J = {
    "pelvis": (0, -0.12, 0.16), "spine_mid": (0, 0.0, 0.17), "withers": (0, 0.1, 0.17),
    "neck_base": (0, 0.13, 0.18), "head_base": (0, 0.17, 0.2), "skull": (0, 0.19, 0.21),
    "snout_tip": (0, 0.24, 0.2), "jaw_hinge": (0, 0.19, 0.19), "chin": (0, 0.23, 0.185),
    "ear_base": (-0.036, 0.18, 0.235), "ear_tip": (-0.037, 0.179, 0.238),
    "shoulder": (-0.06, 0.1, 0.14), "elbow": (-0.13, 0.15, 0.1), "wrist": (-0.15, 0.2, 0.03), "front_toe": (-0.16, 0.24, 0.01),
    "hip": (-0.05, -0.12, 0.12), "knee": (-0.09, -0.1, 0.08), "hock": (-0.09, -0.15, 0.02), "hind_toe": (-0.095, -0.12, 0.005),
    "tail_base": (0, -0.18, 0.14), "tail_mid": (0, -0.2, 0.13), "tail_end": (0, -0.21, 0.12),
}
R = {
    "rump": (0.07, 0.08, 0.07), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.08, 0.11, 0.075), "belly_drop": 0.0,
    "chest": (0.075, 0.08, 0.07), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.03,
    "neck_base": 0.05, "neck_top": 0.045, "neck_blend": 0.02,
    "skull": (0.047, 0.045, 0.043), "head_blend": 0.015,
    "snout_root": (0, 0.02, -0.008), "snout_base": 0.022, "snout_end": 0.018, "snout_blend": 0.01,
    "jaw_base": 0.014, "jaw_end": 0.01, "jaw_blend": 0.005,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.025, 0.025, 0.025), "scapula_up": 0.0,
    "upper_arm": (0.02, 0.017), "forearm": (0.016, 0.014), "front_paw": (0.014, 0.01),
    "thigh": (0.03, 0.035, 0.035), "thigh_drop": 0.0,
    "upper_leg": (0.022, 0.017), "shin": (0.015, 0.013), "hind_paw": (0.013, 0.01),
    "limb_blend": 0.012, "joint_blend": 0.006,
    "tail": (0.015, 0.01, 0.006), "tail_blend": 0.006,
}
COLORS = {"tan": "#b9a27c", "green": "#8f9a62", "face": "#efe3c8", "stripe": "#3a2c20"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    Wt = p.mesh.region_weight
    p.fill("tan")
    p.spots("green", cell=0.04, radius=0.014, mask=p.smooth(p.n[:, 2], 0.0, 0.4) * 0.7, seed=33)
    p.region("snout", "face")
    p.region("jaw", "face")
    p.blend("face", Wt("head") * p.smooth(p.n[:, 1], 0.4, 0.3))
    # Dark stripes running back from the eyes.
    for center, radius in creature.eyes:
        c = np.asarray(center)
        d = np.abs(v[:, 2] - c[2] + (v[:, 1] - c[1]) * 0.2)
        p.blend("stripe", Wt("head") * p.smooth(radius * 0.9 - d, 0.0, radius * 0.3) * p.smooth(c[1] + radius - v[:, 1], 0.0, 0.01)
                * p.smooth(radius * 3.5 - np.abs(np.abs(v[:, 0]) - abs(c[0])), 0.0, radius))
    p.speckle(0.15)
    return p.colors


def make():
    c = quadruped("pygmy_three_toed_sloth", J, R, paint=paint, tiles_long=1.2)
    c.voxel = 0.0022
    for side, bone in ((1, "fl_foot.R"), (-1, "fl_foot.L")):
        for k in (-1, 0, 1):
            b = (side * (0.16 + k * 0.008), 0.235, 0.012)
            c.extras.append(Extra("cone", "claw", bone, center=b, tip=(b[0], 0.27, 0.002), radius=0.004, tip_radius=0.0008, color="#e6dccb"))
    add_face(c, eye_dir=(-0.4, 0.85, 0.25), eye_radius=0.007, eye_sink=0.003, nose_radius=0.007, nose_sink=0.003,
             iris="#1a120c", pupil="round")
    c.fur = {"strands": False, "variation": 0.12, "sheen": 0.2, "bump": 0.35, "roughness": 0.75}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.25, "stride": 0.6, "cycle_tiles": 0.35}
    c.palette = {"mouth": "#4a3328"}
    return c
