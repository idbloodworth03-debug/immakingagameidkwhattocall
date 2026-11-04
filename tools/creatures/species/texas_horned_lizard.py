"""Texas horned lizard: a flat, round, sandy lizard with a crown of horns,
a fringe of spiky scales along its sides, dark blotches down the back and
a short tail. It squirts a jet of blood from its eyes at predators.

Real size: about 10 cm long.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter

J = {
    "pelvis": (0, -0.06, 0.05),
    "spine_mid": (0, 0.0, 0.056),
    "withers": (0, 0.06, 0.055),
    "neck_base": (0, 0.08, 0.05),
    "head_base": (0, 0.1, 0.052),
    "skull": (0, 0.12, 0.056),
    "snout_tip": (0, 0.16, 0.045),
    "jaw_hinge": (0, 0.115, 0.04),
    "chin": (0, 0.155, 0.035),
    "ear_base": (-0.018, 0.11, 0.06),
    "ear_tip": (-0.02, 0.106, 0.066),
    "shoulder": (-0.035, 0.06, 0.045),
    "elbow": (-0.075, 0.07, 0.04),
    "wrist": (-0.085, 0.085, 0.008),
    "front_toe": (-0.09, 0.1, 0.004),
    "hip": (-0.035, -0.06, 0.045),
    "knee": (-0.08, -0.05, 0.04),
    "hock": (-0.09, -0.07, 0.008),
    "hind_toe": (-0.095, -0.05, 0.004),
    "tail_base": (0, -0.09, 0.048),
    "tail_mid": (0, -0.14, 0.03),
    "tail_end": (0, -0.18, 0.015),
}

R = {
    "rump": (0.05, 0.05, 0.026), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.066, 0.072, 0.029), "belly_drop": 0.0,
    "chest": (0.055, 0.05, 0.027), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.03,
    "neck_base": 0.028, "neck_top": 0.024, "neck_blend": 0.015,
    "skull": (0.031, 0.033, 0.02), "head_blend": 0.012,
    "snout_root": (0, 0.02, -0.005), "snout_base": 0.02, "snout_end": 0.01, "snout_blend": 0.01,
    "jaw_base": 0.012, "jaw_end": 0.006, "jaw_blend": 0.006,
    "ear_width": 0.006, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.3, "ear_sink": 0.004, "ear_voxel": 0.001,
    "scapula": (0.012, 0.015, 0.012), "scapula_up": 0.0,
    "upper_arm": (0.012, 0.01), "forearm": (0.009, 0.008), "front_paw": (0.007, 0.005),
    "thigh": (0.016, 0.02, 0.014), "thigh_drop": 0.0,
    "upper_leg": (0.014, 0.01), "shin": (0.01, 0.008), "hind_paw": (0.008, 0.005),
    "limb_blend": 0.01, "joint_blend": 0.006,
    "tail": (0.02, 0.012, 0.006, 0.002), "tail_blend": 0.01,
}

COLORS = {
    "sand": "#cfa877",
    "blotch": "#6b4a32",
    "light": "#efe0c2",
    "horn": "#e8d5ae",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("sand")
    up = p.smooth(n[:, 2], 0.3, 0.4)
    # Pairs of dark blotches down the back, either side of a pale stripe.
    blotches = up * p.smooth(0.03 - np.abs(np.abs(v[:, 0]) - 0.022), 0.0, 0.01)
    p.stripes("blotch", lambda q: q[:, 1], frequency=22.0, width=0.3, mask=blotches * p.smooth(0.09 - np.abs(v[:, 1]), 0.0, 0.02))
    p.blend("light", up * p.smooth(0.005 - np.abs(v[:, 0]), 0.0, 0.003))
    p.blend("light", p.smooth(-n[:, 2], 0.2, 0.4) * 0.8)
    p.speckle(0.08)
    return p.colors


def make():
    c = quadruped("texas_horned_lizard", J, R, paint=paint, tiles_long=0.9)
    c.voxel = 0.0018
    # A crown of horns at the back of the head, two big ones in the middle.
    for x, length, rise in ((0.008, 0.036, 0.45), (0.018, 0.028, 0.35), (0.027, 0.02, 0.25)):
        for side in (1, -1):
            base = (side * x, 0.103, 0.068)
            tip = (side * (x + 0.006), 0.103 - length, 0.068 + length * rise)
            c.extras.append(Extra("cone", "horn", "head", center=base, tip=tip, radius=0.0055, tip_radius=0.0006, color="#d9bf8f"))
    # A fringe of spiky scales along each side.
    for y in np.linspace(-0.05, 0.05, 6):
        for side in (1, -1):
            base = (side * 0.06, float(y), 0.05)
            tip = (side * 0.083, float(y) - 0.005, 0.053)
            c.extras.append(Extra("cone", "horn", "chest" if y > 0 else "hips", center=base, tip=tip, radius=0.0055,
                                  tip_radius=0.0004, color="#d9b98a"))
    add_face(c, eye_dir=(-0.75, 0.55, 0.35), eye_radius=0.006, eye_sink=0.002, nose_radius=0, iris="#3a2414", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.2, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "spit", "stride": 1.2, "wiggle": 0.12, "gape": 0.3, "cycle_tiles": 0.6}
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "bite"
    return c
