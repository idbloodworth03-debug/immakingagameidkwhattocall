"""Komodo dragon: the biggest lizard, long and heavy, with a long flat head,
a thick muscular tail as long as its body, bowed legs with curved claws
and a long yellow forked tongue. Gray-brown beaded skin with a few dull
orange flecks. It sways its head and tail as it walks.

Real size: about 2.5 m long.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import cone

J = {
    "pelvis": (0, -0.4, 0.3),
    "spine_mid": (0, 0.0, 0.33),
    "withers": (0, 0.38, 0.31),
    "neck_base": (0, 0.48, 0.31),
    "head_base": (0, 0.62, 0.34),
    "skull": (0, 0.69, 0.35),
    "snout_tip": (0, 0.9, 0.3),
    "jaw_hinge": (0, 0.68, 0.28),
    "chin": (0, 0.86, 0.26),
    "ear_base": (-0.08, 0.66, 0.37),
    "ear_tip": (-0.082, 0.658, 0.375),
    "shoulder": (-0.15, 0.37, 0.25),
    "elbow": (-0.29, 0.41, 0.21),
    "wrist": (-0.3, 0.45, 0.05),
    "front_toe": (-0.32, 0.55, 0.012),
    "hip": (-0.15, -0.42, 0.25),
    "knee": (-0.3, -0.36, 0.21),
    "hock": (-0.3, -0.48, 0.05),
    "hind_toe": (-0.32, -0.38, 0.012),
    "tail_base": (0, -0.6, 0.28),
    "tail_mid": (0, -1.0, 0.16),
    "tail_end": (0, -1.38, 0.04),
}

R = {
    "rump": (0.17, 0.25, 0.13), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.2, 0.42, 0.14), "belly_drop": 0.0,
    "chest": (0.18, 0.25, 0.13), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.1,
    "neck_base": 0.13, "neck_top": 0.11, "neck_blend": 0.07,
    "skull": (0.1, 0.12, 0.075), "head_blend": 0.05,
    "snout_root": (0, 0.08, -0.02), "snout_base": 0.08, "snout_end": 0.05, "snout_blend": 0.04,
    "jaw_base": 0.06, "jaw_end": 0.04, "jaw_blend": 0.025,
    "ear_width": 0.01, "ear_thick": 0.004, "ear_round": 0.004, "ear_yaw": 0.0, "ear_sink": 0.008, "ear_voxel": 0.003,
    "scapula": (0.06, 0.06, 0.06), "scapula_up": 0.0,
    "upper_arm": (0.07, 0.06), "forearm": (0.055, 0.045), "front_paw": (0.045, 0.03),
    "thigh": (0.09, 0.1, 0.09), "thigh_drop": 0.0,
    "upper_leg": (0.08, 0.065), "shin": (0.06, 0.05), "hind_paw": (0.05, 0.032),
    "limb_blend": 0.06, "joint_blend": 0.025,
    "tail": (0.12, 0.07, 0.035, 0.01), "tail_blend": 0.05,
}

COLORS = {"gray": "#7d705c", "dark": "#544a3c", "belly": "#b3a68c", "orange": "#c2864a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("gray")
    p.blend("dark", p.smooth(p.n[:, 2], 0.3, 0.4) * 0.35)
    p.blend("belly", p.smooth(-p.n[:, 2], 0.2, 0.4) * 0.7)
    p.spots("orange", cell=0.09, radius=0.016, mask=p.smooth(p.n[:, 2], 0.0, 0.5) * 0.6, seed=17)
    p.speckle(0.25)
    return p.colors


def tongue(c, J, length, radius, color="#f0c63c", bone="jaw"):
    """A forked tongue flicking out of the front of the mouth."""
    tip = np.asarray(J["snout_tip"], float) * (0, 1, 1) + (0, 0, -radius * 3)
    chin = np.asarray(J["chin"], float)
    root = chin + (tip - chin) * 0.5
    out = tip + (0, length, -length * 0.15)
    c.extras.append(Extra("cone", "claw", bone, center=tuple(root), tip=tuple(out), radius=radius, tip_radius=radius * 0.6, color=color))
    for side in (1, -1):
        c.extras.append(Extra("cone", "claw", bone, center=tuple(out), tip=tuple(out + (side * length * 0.18, length * 0.25, 0)),
                              radius=radius * 0.6, tip_radius=radius * 0.15, color=color))


def make():
    c = quadruped("komodo_dragon", J, R, paint=paint, tiles_long=2.4)
    c.voxel = 0.008
    tongue(c, J, 0.1, 0.012)
    for side, bone in ((1, "fl_foot.R"), (-1, "fl_foot.L")):
        for k in (-1, 0, 1):
            b = (side * (0.32 + k * 0.022), 0.55, 0.02)
            c.extras.append(Extra("cone", "claw", bone, center=b, tip=(b[0], 0.6, 0.004), radius=0.008, tip_radius=0.0015, color="#3b342c"))
    add_face(c, eye_dir=(-0.7, 0.55, 0.4), eye_radius=0.014, eye_sink=0.006, nose_radius=0.0, iris="#6b4a22", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.2, "bump": 0.35, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 1.0, "wiggle": 0.16, "gape": 0.8, "cycle_tiles": 0.9}
    return c
