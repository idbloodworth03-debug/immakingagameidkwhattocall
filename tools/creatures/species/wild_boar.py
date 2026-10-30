"""Wild Boar: wedge-shaped, with a massive head and shoulders, small
hindquarters and short thin legs on hooves. Long sloping snout ending in a
flat disc, small eyes, upright triangular ears, curved tusks, a bristly mane
along the spine and a thin tail with a tuft. Dark gray-brown grizzled coat.

Real size: about 90 cm at the shoulder, 1.5 m long.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.45, 0.76),
    "spine_mid": (0, -0.05, 0.84),
    "withers": (0, 0.3, 0.9),
    "neck_base": (0, 0.38, 0.77),
    "head_base": (0, 0.54, 0.7),
    "skull": (0, 0.6, 0.68),
    "snout_tip": (0, 0.92, 0.47),
    "jaw_hinge": (0, 0.6, 0.6),
    "chin": (0, 0.8, 0.47),
    "ear_base": (-0.08, 0.57, 0.82),
    "ear_tip": (-0.12, 0.53, 0.92),
    "shoulder": (-0.12, 0.37, 0.6),
    "elbow": (-0.13, 0.29, 0.4),
    "wrist": (-0.12, 0.32, 0.12),
    "front_toe": (-0.12, 0.37, 0.02),
    "hip": (-0.11, -0.45, 0.66),
    "knee": (-0.12, -0.33, 0.44),
    "hock": (-0.11, -0.52, 0.18),
    "hind_toe": (-0.11, -0.46, 0.02),
    "tail_base": (0, -0.6, 0.74),
    "tail_mid": (0, -0.66, 0.6),
    "tail_end": (0, -0.68, 0.5),
}

R = {
    "rump": (0.16, 0.2, 0.17), "rump_back": 0.01, "rump_drop": 0.1,
    "belly": (0.19, 0.4, 0.2), "belly_drop": 0.16,
    "chest": (0.22, 0.28, 0.27), "chest_back": 0.06, "chest_drop": 0.2,
    "torso_blend": 0.15,
    "neck_base": 0.22, "neck_top": 0.17, "neck_blend": 0.12,
    "skull": (0.13, 0.15, 0.13), "skull_pitch": -0.5, "head_blend": 0.07,
    "snout_root": (0, 0.11, -0.06), "snout_base": 0.085, "snout_end": 0.058, "snout_blend": 0.05,
    "jaw_base": 0.06, "jaw_end": 0.035, "jaw_blend": 0.025,
    "ear_width": 0.075, "ear_thick": 0.006, "ear_round": 0.008, "ear_yaw": 0.4, "ear_sink": 0.02,
    "ear_voxel": 0.003, "ear_fur": 0.015,
    "scapula": (0.1, 0.14, 0.18), "scapula_up": 0.11, "scapula_pitch": 0.3,
    "upper_arm": (0.11, 0.07), "forearm": (0.055, 0.04), "front_paw": (0.04, 0.036),
    "thigh": (0.14, 0.2, 0.2), "thigh_drop": 0.09, "thigh_pitch": -0.25,
    "upper_leg": (0.12, 0.07), "shin": (0.055, 0.04), "hind_paw": (0.04, 0.036),
    "limb_blend": 0.1, "joint_blend": 0.03,
    "tail": (0.02, 0.015, 0.012, 0.028), "tail_blend": 0.015,
}

COLORS = {
    "coat": "#463a30",
    "grizzle": "#7b6a58",
    "dark": "#1f1915",
    "disc": "#8f7368",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("coat")
    p.where("grizzle", lambda v, n: p.smooth(n[:, 2], 0.0, 0.6), 0.35)
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "dark", 0.8)
    p.region("mane", "dark", 0.7)
    p.region_where("snout", "disc", lambda v, n: p.smooth(v[:, 1] - 0.88, 0.0, 0.02))
    p.region("tail_tip", "dark")
    p.speckle(0.3)
    return p.colors


def make():
    c = quadruped("wild_boar", J, R, paint=paint, tiles_long=1.8)
    c.voxel = 0.006
    # The bristly mane along the spine, rising over the shoulders.
    c.shapes.append(ellipsoid((0, 0.08, 0.95), (0.055, 0.36, 0.07), "mane", "chest", blend=0.07, pitch=0.12))
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.1, 0.62, 0.6), (0.07, 0.1, 0.08), "cheek", "head", blend=0.05))
        # Tusks curving up out of the lower jaw.
        c.extras.append(Extra("cone", "tusk", "head", center=(side * 0.05, 0.83, 0.5), tip=(side * 0.075, 0.86, 0.6),
                              radius=0.012, tip_radius=0.002))
    add_face(c, eye_dir=(-0.65, 0.65, 0.4), eye_radius=0.011, eye_sink=0.006, nose_radius=0.045, nose_sink=0.03,
             iris="#2a160c", pupil="round")
    c.extras[-1].color = "#5e4a44"
    c.fur = {"variation": 0.25, "sheen": 0.2, "bump": 0.4, "length": 0.045, "density": 14000, "hair_gamma": 2.0,
             "frizz": 0.006, "clump": 0.5, "lift": 0.8,
             "lengths": {"mane": 1.8, "snout": 0.15, "front_paw": 0.0, "hind_paw": 0.0, "tail_tip": 1.5}}
    c.motion = {"gait": "trot", "attack": "charge", "stride": 0.95, "charge_reach": 0.4}
    return c
