"""Sunda slow loris: a small, round, soft primate with huge round eyes in
dark rings, a white stripe down between them, tiny round ears, a dark
stripe down the back and short arms and legs. Gray-brown fur. It creeps
slowly and grips hard.

Real size: about 30 cm long.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter

J = {
    "pelvis": (0, -0.08, 0.12), "spine_mid": (0, 0.0, 0.13), "withers": (0, 0.07, 0.12),
    "neck_base": (0, 0.09, 0.12), "head_base": (0, 0.12, 0.14), "skull": (0, 0.14, 0.145),
    "snout_tip": (0, 0.18, 0.135), "jaw_hinge": (0, 0.14, 0.13), "chin": (0, 0.17, 0.125),
    "ear_base": (-0.025, 0.135, 0.17), "ear_tip": (-0.03, 0.13, 0.18),
    "shoulder": (-0.03, 0.07, 0.09), "elbow": (-0.04, 0.08, 0.05), "wrist": (-0.035, 0.09, 0.015), "front_toe": (-0.035, 0.105, 0.005),
    "hip": (-0.035, -0.08, 0.09), "knee": (-0.045, -0.05, 0.05), "hock": (-0.04, -0.1, 0.015), "hind_toe": (-0.04, -0.08, 0.005),
    "tail_base": (0, -0.12, 0.11), "tail_mid": (0, -0.13, 0.1), "tail_end": (0, -0.135, 0.095),
}
R = {
    "rump": (0.05, 0.05, 0.045), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.05, 0.07, 0.045), "belly_drop": 0.0,
    "chest": (0.045, 0.05, 0.045), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.02,
    "neck_base": 0.035, "neck_top": 0.03, "neck_blend": 0.015,
    "skull": (0.035, 0.033, 0.032), "head_blend": 0.012,
    "snout_root": (0, 0.015, -0.006), "snout_base": 0.014, "snout_end": 0.008, "snout_blend": 0.008,
    "jaw_base": 0.008, "jaw_end": 0.004, "jaw_blend": 0.003,
    "ear_width": 0.014, "ear_thick": 0.002, "ear_round": 0.007, "ear_yaw": 0.3, "ear_sink": 0.003, "ear_voxel": 0.0008,
    "scapula": (0.012, 0.015, 0.015), "scapula_up": 0.0,
    "upper_arm": (0.013, 0.011), "forearm": (0.011, 0.009), "front_paw": (0.01, 0.008),
    "thigh": (0.02, 0.025, 0.025), "thigh_drop": 0.0,
    "upper_leg": (0.016, 0.012), "shin": (0.011, 0.009), "hind_paw": (0.01, 0.008),
    "limb_blend": 0.008, "joint_blend": 0.004,
    "tail": (0.01, 0.008, 0.006), "tail_blend": 0.004,
}
COLORS = {"fur": "#a08066", "dark": "#4a3324", "white": "#f2ece2", "light": "#c9b29c"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    Wt = p.mesh.region_weight
    p.fill("fur")
    p.blend("light", p.smooth(-p.n[:, 2], 0.0, 0.4) * 0.6)
    # A dark stripe down the back.
    p.blend("dark", Wt("torso") * p.smooth(0.01 - np.abs(v[:, 0]), 0.0, 0.006) * p.smooth(p.n[:, 2], 0.5, 0.3) * 0.8)
    # Dark eye rings with a white stripe between them.
    for center, radius in creature.eyes:
        d = np.linalg.norm(v - np.asarray(center), axis=1)
        p.blend("dark", (Wt("head") + Wt("snout")) * p.smooth(radius * 2.4 - d, 0.0, radius * 0.5))
    p.blend("white", (Wt("head") + Wt("snout")) * p.smooth(0.005 - np.abs(v[:, 0]), 0.0, 0.003) * p.smooth(p.n[:, 1], 0.2, 0.3))
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("slow_loris", J, R, paint=paint, tiles_long=0.9)
    c.voxel = 0.0014
    add_face(c, eye_dir=(-0.45, 0.85, 0.25), eye_radius=0.0075, eye_sink=0.003, nose_radius=0.004, nose_sink=0.002,
             iris="#8a5a2a", pupil="round")
    c.fur = {"strands": False, "variation": 0.08, "sheen": 0.3, "bump": 0.2, "roughness": 0.65}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.7, "cycle_tiles": 0.4}
    return c
