"""Sunda pangolin: a shy anteater covered from head to tail in big
overlapping olive-brown scales like a living pinecone, with a small pointed
head, tiny eyes, a long thick tail, strong curved front claws and soft
pale skin on its face and belly.

Real size: about 90 cm including the tail.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.15, 0.17), "spine_mid": (0, 0.0, 0.2), "withers": (0, 0.14, 0.18),
    "neck_base": (0, 0.18, 0.16), "head_base": (0, 0.24, 0.15), "skull": (0, 0.27, 0.145),
    "snout_tip": (0, 0.35, 0.11), "jaw_hinge": (0, 0.27, 0.13), "chin": (0, 0.33, 0.105),
    "ear_base": (-0.026, 0.26, 0.16), "ear_tip": (-0.027, 0.258, 0.163),
    "shoulder": (-0.05, 0.14, 0.12), "elbow": (-0.06, 0.12, 0.07), "wrist": (-0.055, 0.15, 0.02), "front_toe": (-0.055, 0.18, 0.006),
    "hip": (-0.055, -0.15, 0.13), "knee": (-0.065, -0.1, 0.08), "hock": (-0.06, -0.18, 0.02), "hind_toe": (-0.06, -0.14, 0.006),
    "tail_base": (0, -0.24, 0.16), "tail_mid": (0, -0.38, 0.1), "tail_end": (0, -0.5, 0.04),
}
R = {
    "rump": (0.075, 0.1, 0.075), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.08, 0.14, 0.08), "belly_drop": 0.0,
    "chest": (0.07, 0.09, 0.07), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.04,
    "neck_base": 0.05, "neck_top": 0.038, "neck_blend": 0.025,
    "skull": (0.035, 0.04, 0.03), "head_blend": 0.015,
    "snout_root": (0, 0.03, -0.01), "snout_base": 0.022, "snout_end": 0.01, "snout_blend": 0.01,
    "jaw_base": 0.012, "jaw_end": 0.006, "jaw_blend": 0.005,
    "ear_width": 0.006, "ear_thick": 0.002, "ear_round": 0.003, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.025, 0.03, 0.03), "scapula_up": 0.0,
    "upper_arm": (0.025, 0.02), "forearm": (0.02, 0.016), "front_paw": (0.016, 0.012),
    "thigh": (0.035, 0.045, 0.04), "thigh_drop": 0.0,
    "upper_leg": (0.03, 0.022), "shin": (0.02, 0.016), "hind_paw": (0.016, 0.012),
    "limb_blend": 0.015, "joint_blend": 0.008,
    "tail": (0.06, 0.045, 0.03, 0.012), "tail_blend": 0.02,
}

COLORS = {"scale": "#8c6b43", "edge": "#5b4228", "light": "#b8955f", "skin": "#e0c9b8"}

# The spine the scales follow, with the body's radius at each point.
SPINE = [("neck_base", 0.05, "neck"), ("withers", 0.075, "chest"), ("spine_mid", 0.085, "chest"), ("pelvis", 0.08, "hips"),
         ("tail_base", 0.062, "tail1"), ("tail_mid", 0.046, "tail2"), ("tail_end", 0.03, "tail3")]


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("skin")
    scales = p.mesh.region_weight("scales")
    p.blend("scale", np.clip(scales + p.smooth(p.n[:, 2], -0.2, 0.4) * (p.mesh.region_weight("torso") + p.mesh.region_weight("tail")), 0, 1))
    p.blend("light", scales * p.smooth(p.n[:, 2], 0.6, 0.3) * 0.4)
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("sunda_pangolin", J, R, paint=paint, tiles_long=1.4)
    c.voxel = 0.0022
    # Overlapping scales in rows, like shingles, from the neck to the tail tip.
    pts = [(np.asarray(J[k], float), r, b) for k, r, b in SPINE]
    for i in range(len(pts) - 1):
        (a, ra, ba), (b, rb, bb) = pts[i], pts[i + 1]
        steps = 3 if i < 3 else 3
        for s in range(steps):
            u = s / steps
            at = a + (b - a) * u
            r = ra + (rb - ra) * u
            fwd = (b - a) / np.linalg.norm(b - a)
            pitch = np.arctan2(fwd[2], -fwd[1])
            n_across = 5 if r > 0.05 else 3
            for k in range(n_across):
                ang = (k - (n_across - 1) / 2) * 0.55 + (0.27 if s % 2 else 0.0)
                off = np.array([np.sin(ang) * r * 0.95, 0.0, np.cos(ang) * r * 0.95])
                c.shapes.append(ellipsoid(tuple(at + off), (r * 0.42, r * 0.38, r * 0.12), "scales", ba if u < 0.5 else bb,
                                          blend=r * 0.08, roll=-ang, pitch=-0.25 - pitch * 0.0))
    for side, bone in ((1, "fl_foot.R"), (-1, "fl_foot.L")):
        for k in (-1, 0, 1):
            b = (side * (0.055 + k * 0.007), 0.18, 0.01)
            c.extras.append(Extra("cone", "claw", bone, center=b, tip=(b[0], 0.2, 0.002), radius=0.004, tip_radius=0.0008, color="#e4d6c0"))
    add_face(c, eye_dir=(-0.7, 0.6, 0.35), eye_radius=0.006, eye_sink=0.002, nose_radius=0.006, nose_sink=0.002,
             iris="#140d0a", pupil="round")
    c.extras[-1].color = "#c99a8c"
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.35, "bump": 0.25, "roughness": 0.55}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.3, "stride": 0.85}
    return c
