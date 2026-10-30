"""American Bison: enormous hump over the shoulders, a huge head carried low
with short black hooked horns and a beard, a woolly dark-brown cape over the
head, neck, hump and front legs, and sleeker, lighter hindquarters that look
small behind it. Thin tail with a tuft, black hooves.

Real size: about 1.8 m at the hump, 3 m long.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.9, 1.22),
    "spine_mid": (0, -0.3, 1.4),
    "withers": (0, 0.35, 1.68),
    "neck_base": (0, 0.55, 1.28),
    "head_base": (0, 0.92, 0.98),
    "skull": (0, 1.02, 0.9),
    "snout_tip": (0, 1.2, 0.68),
    "jaw_hinge": (0, 1.01, 0.79),
    "chin": (0, 1.14, 0.6),
    "ear_base": (-0.19, 0.98, 0.98),
    "ear_tip": (-0.27, 0.95, 0.98),
    "shoulder": (-0.22, 0.55, 0.98),
    "elbow": (-0.23, 0.42, 0.68),
    "wrist": (-0.21, 0.48, 0.25),
    "front_toe": (-0.21, 0.56, 0.03),
    "hip": (-0.2, -0.9, 1.1),
    "knee": (-0.21, -0.72, 0.74),
    "hock": (-0.19, -1.05, 0.38),
    "hind_toe": (-0.19, -0.96, 0.03),
    "tail_base": (0, -1.12, 1.18),
    "tail_mid": (0, -1.18, 0.95),
    "tail_end": (0, -1.2, 0.7),
}

R = {
    "rump": (0.26, 0.36, 0.23), "rump_back": 0.02, "rump_drop": 0.17,
    "belly": (0.34, 0.72, 0.4), "belly_drop": 0.32,
    "chest": (0.36, 0.46, 0.5), "chest_back": 0.12, "chest_drop": 0.45,
    "torso_blend": 0.22,
    "neck_base": 0.36, "neck_top": 0.27, "neck_blend": 0.12,
    "skull": (0.23, 0.25, 0.25), "skull_pitch": -0.6, "head_blend": 0.07,
    "snout_root": (0, 0.14, -0.12), "snout_base": 0.17, "snout_end": 0.13, "snout_blend": 0.08,
    "jaw_base": 0.11, "jaw_end": 0.08, "jaw_blend": 0.04,
    "ear_width": 0.1, "ear_thick": 0.01, "ear_round": 0.02, "ear_yaw": 0.8, "ear_sink": 0.04,
    "ear_voxel": 0.005, "ear_fur": 0.03,
    "scapula": (0.2, 0.28, 0.4), "scapula_up": 0.2, "scapula_pitch": 0.3,
    "upper_arm": (0.2, 0.14), "forearm": (0.1, 0.08), "front_paw": (0.08, 0.07),
    "thigh": (0.22, 0.3, 0.32), "thigh_drop": 0.16, "thigh_pitch": -0.25,
    "upper_leg": (0.21, 0.13), "shin": (0.1, 0.075), "hind_paw": (0.08, 0.07),
    "limb_blend": 0.16, "joint_blend": 0.05,
    "tail": (0.04, 0.035, 0.03, 0.07), "tail_blend": 0.03,
}

COLORS = {
    "cape": "#2c1f15",
    "body": "#46301e",
    "light": "#5e4229",
    "black": "#120d0a",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    W = p.mesh.region_weight
    p.fill("body")
    # Dark woolly cape over everything in front of the ribs.
    p.blend("cape", p.smooth(v[:, 1] + 0.35 + 0.08 * p.noise(9.0, 3), 0.0, 0.55))
    p.where("light", lambda v, n: p.smooth(n[:, 2], 0.3, 0.5) * p.smooth(-0.1 - v[:, 1], 0.0, 0.3), 0.4)
    p.region("beard", "black")
    for leg in ("front_paw", "hind_paw"):
        p.region(leg, "black")
    p.region_where("hind_lower", "cape", lambda v, n: p.smooth(0.3 - v[:, 2], 0.0, 0.1), 0.7)
    p.region("tail_tip", "black")
    p.region("snout", "cape")
    p.speckle(0.2)
    return p.colors


def make():
    c = quadruped("american_bison", J, R, paint=paint, tiles_long=2.5)
    c.voxel = 0.01
    # The hump and the beard.
    c.shapes.append(ellipsoid((0, 0.2, 1.52), (0.27, 0.52, 0.3), "torso", "chest", blend=0.14, pitch=0.25))
    c.shapes.append(ellipsoid((0, 1.07, 0.54), (0.1, 0.12, 0.16), "beard", "jaw", blend=0.06, pitch=0.3))
    # A broad woolly brow over the eyes.
    c.shapes.append(ellipsoid((0, 1.0, 1.0), (0.24, 0.14, 0.14), "head", "head", blend=0.08))
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.15, 1.02, 0.87), (0.11, 0.15, 0.15), "cheek", "head", blend=0.06))
        # Horns: out to the side, then hooking up.
        base = np.array([side * 0.2, 0.99, 1.02])
        mid = np.array([side * 0.35, 1.02, 1.07])
        tip = np.array([side * 0.36, 1.06, 1.22])
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(mid), radius=0.055, tip_radius=0.038,
                              color="#1e1915"))
        c.extras.append(Extra("cone", "horn", "head", center=tuple(mid), tip=tuple(tip), radius=0.039, tip_radius=0.007,
                              color="#1e1915"))
    add_face(c, eye_dir=(-0.75, 0.6, 0.25), eye_radius=0.022, eye_sink=0.014, nose_radius=0.06, nose_sink=0.035,
             iris="#1a0f08", pupil="round")
    c.fur = {"variation": 0.25, "sheen": 0.2, "bump": 0.4, "length": 0.06, "density": 9000, "hair_gamma": 2.0,
             "frizz": 0.01, "clump": 0.55, "lift": 0.75,
             "lengths": {"beard": 3.0, "head": 1.8, "cheek": 1.8, "neck": 2.0, "shoulder": 2.0, "front_upper": 1.8,
                         "torso": 1.0, "snout": 0.3, "front_paw": 0.0, "hind_paw": 0.0, "tail_tip": 2.0},
             # Long wool in front, short sleek hair behind the ribs.
             "weight_fn": lambda m: 0.35 + 0.65 * np.clip((m.verts[:, 1] + 0.35) / 0.4, 0, 1)}
    c.motion = {"gait": "walk", "attack": "charge", "stride": 0.85, "charge_reach": 0.3}
    return c
