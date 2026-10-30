"""Asian Elephant: the biggest land animal in Asia. Arched back, highest in
the middle, a twin-domed head, smaller rounded ears than an African
elephant's hanging down the sides of the neck, a long muscular trunk, short
tusks, thick column legs and a short tufted tail. Gray wrinkled skin with
pinkish patches on the face, ears and trunk.

Real size: about 2.6 m at the shoulder, 3.5 m long plus the trunk.
"""
import numpy as np

from anatomy import Bone, Extra, add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid

J = {
    "pelvis": (0, -1.1, 2.2),
    "spine_mid": (0, -0.3, 2.5),
    "withers": (0, 0.5, 2.42),
    "neck_base": (0, 0.75, 2.22),
    "head_base": (0, 1.05, 2.28),
    "skull": (0, 1.15, 2.42),
    "snout_tip": (0, 1.48, 1.95),
    "jaw_hinge": (0, 1.15, 1.95),
    "chin": (0, 1.35, 1.72),
    "ear_base": (-0.6, 0.97, 2.42),
    "ear_tip": (-0.72, 0.84, 1.8),
    "shoulder": (-0.42, 0.6, 1.75),
    "elbow": (-0.44, 0.48, 1.15),
    "wrist": (-0.42, 0.52, 0.35),
    "front_toe": (-0.42, 0.6, 0.05),
    "hip": (-0.42, -1.1, 1.95),
    "knee": (-0.44, -0.88, 1.2),
    "hock": (-0.42, -1.15, 0.45),
    "hind_toe": (-0.42, -1.08, 0.05),
    "tail_base": (0, -1.55, 2.08),
    "tail_mid": (0, -1.6, 1.7),
    "tail_end": (0, -1.62, 1.35),
}

TRUNK = {
    "trunk_base": (0, 1.46, 1.98),
    "trunk_mid": (0, 1.62, 1.32),
    "trunk_end": (0, 1.64, 0.72),
    "trunk_tip": (0, 1.56, 0.3),
}

R = {
    "rump": (0.6, 0.6, 0.6), "rump_back": 0.02, "rump_drop": 0.4,
    "belly": (0.74, 1.05, 0.74), "belly_drop": 0.62,
    "chest": (0.68, 0.7, 0.8), "chest_back": 0.12, "chest_drop": 0.62,
    "torso_blend": 0.22,
    "neck_base": 0.58, "neck_top": 0.5, "neck_blend": 0.14,
    "skull": (0.5, 0.48, 0.55), "skull_pitch": -0.3, "head_blend": 0.1,
    "snout_root": (0, 0.15, -0.25), "snout_base": 0.34, "snout_end": 0.26, "snout_blend": 0.12,
    "jaw_base": 0.24, "jaw_end": 0.15, "jaw_blend": 0.06,
    "ear_width": 0.62, "ear_thick": 0.028, "ear_round": 0.18, "ear_yaw": 1.0, "ear_sink": 0.0,
    "ear_voxel": 0.008,
    "scapula": (0.35, 0.4, 0.55), "scapula_up": 0.25, "scapula_pitch": 0.3,
    "upper_arm": (0.36, 0.28), "forearm": (0.26, 0.24), "front_paw": (0.25, 0.24),
    "thigh": (0.5, 0.55, 0.6), "thigh_drop": 0.25, "thigh_pitch": -0.2,
    "upper_leg": (0.42, 0.28), "shin": (0.26, 0.24), "hind_paw": (0.25, 0.24),
    "limb_blend": 0.25, "joint_blend": 0.1,
    "tail": (0.05, 0.04, 0.035, 0.07), "tail_blend": 0.04,
}

COLORS = {
    "gray": "#6a6560",
    "dusty": "#8a8279",
    "pink": "#c4a097",
    "dark": "#3e3a36",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    W = p.mesh.region_weight
    p.fill("gray")
    p.where("dusty", lambda v, n: p.smooth(n[:, 2], 0.4, 0.4), 0.4)
    # Pink freckled patches on the face, ear edges and the top of the trunk.
    face = np.clip(W("snout") + W("head") + W("trunk") * p.smooth(v[:, 2] - 1.3, 0.0, 0.2), 0, 1)
    p.blend("pink", face * p.smooth(n[:, 1], 0.2, 0.4) * p.smooth(p.noise(30.0, 4) + 0.25 * p.noise(70.0, 5), 0.6, 0.25) * 0.7)
    p.region("ear", "dark", 0.35)
    p.region_where("ear", "pink", lambda v, n: p.smooth(p.noise(25.0, 6), 0.55, 0.3) * p.smooth(1.95 - v[:, 2], 0.0, 0.2), 0.5)
    # Wrinkle rings round the trunk and the legs.
    trunk_axis = np.asarray(TRUNK["trunk_tip"]) - np.asarray(TRUNK["trunk_base"])
    along = lambda q: (q - np.asarray(TRUNK["trunk_base"])) @ trunk_axis / (trunk_axis @ trunk_axis)
    p.stripes("dark", along, frequency=28.0, width=0.12, wobble=0.3, breakup=0.8, mask=W("trunk") * 0.6)
    p.stripes("dark", lambda q: q[:, 2], frequency=12.0, width=0.08, wobble=0.5, breakup=1.0,
              mask=(W("front_lower") + W("hind_lower")) * 0.5)
    p.region("tail_tip", "dark")
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("asian_elephant", J, R, paint=paint, tiles_long=3.0)
    c.voxel = 0.016
    c.joints.update(TRUNK)
    c.bones += [
        Bone("trunk1", "trunk_base", "trunk_mid", "head"),
        Bone("trunk2", "trunk_mid", "trunk_end", "trunk1"),
        Bone("trunk3", "trunk_end", "trunk_tip", "trunk2"),
    ]
    P = lambda k: np.asarray(c.joints[k], float)
    c.shapes += [
        cone(P("trunk_base"), P("trunk_mid"), 0.21, 0.14, "trunk", "trunk1", "trunk2", blend=0.1),
        cone(P("trunk_mid"), P("trunk_end"), 0.14, 0.1, "trunk", "trunk2", "trunk3", blend=0.04),
        cone(P("trunk_end"), P("trunk_tip"), 0.1, 0.075, "trunk", "trunk3", blend=0.03),
    ]
    # The two domes on top of the head.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.16, 1.12, 2.72), (0.24, 0.26, 0.22), "head", "head", blend=0.12))
        c.extras.append(Extra("cone", "tusk", "head", center=(side * 0.14, 1.42, 1.78), tip=(side * 0.17, 1.66, 1.6),
                              radius=0.045, tip_radius=0.015))
    add_face(c, eye_dir=(-0.8, 0.55, 0.0), eye_radius=0.028, eye_sink=0.02, nose_radius=0, iris="#3a2010", pupil="round")
    c.fur = {"strands": False, "variation": 0.2, "sheen": 0.05, "bump": 1.0, "roughness": 0.85, "specular": 0.2,
             "streak_x": 40.0, "streak_y": 40.0, "streak_z": 40.0}
    c.motion = {"gait": "walk", "attack": "stomp", "rear": 0.2, "stride": 0.75}
    c.palette = {"eye_line": "#3a3430", "eye_line_size": 1.6}
    return c
