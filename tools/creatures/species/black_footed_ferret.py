"""Black-footed ferret: a long, slim, bendy weasel of the prairie with a
buff coat, a cream face with a black bandit mask, round ears, black legs
and feet and a black tail tip. It bounds along with an arched back.

Real size: about 50 cm long including the tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.16, 0.13), "spine_mid": (0, 0.0, 0.145), "withers": (0, 0.14, 0.13),
    "neck_base": (0, 0.18, 0.13), "head_base": (0, 0.235, 0.15), "skull": (0, 0.262, 0.155),
    "snout_tip": (0, 0.31, 0.14), "jaw_hinge": (0, 0.262, 0.136), "chin": (0, 0.3, 0.128),
    "ear_base": (-0.022, 0.255, 0.172), "ear_tip": (-0.03, 0.25, 0.19),
    "shoulder": (-0.03, 0.15, 0.1), "elbow": (-0.034, 0.12, 0.06), "wrist": (-0.03, 0.135, 0.02), "front_toe": (-0.03, 0.155, 0.006),
    "hip": (-0.034, -0.16, 0.1), "knee": (-0.04, -0.11, 0.06), "hock": (-0.035, -0.19, 0.02), "hind_toe": (-0.035, -0.15, 0.006),
    "tail_base": (0, -0.22, 0.12), "tail_mid": (0, -0.3, 0.09), "tail_end": (0, -0.37, 0.06),
}
R = {
    "rump": (0.045, 0.07, 0.045), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.045, 0.12, 0.045), "belly_drop": 0.0,
    "chest": (0.045, 0.07, 0.045), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.03,
    "neck_base": 0.035, "neck_top": 0.03, "neck_blend": 0.02,
    "skull": (0.03, 0.03, 0.026), "head_blend": 0.015,
    "snout_root": (0, 0.02, -0.006), "snout_base": 0.017, "snout_end": 0.009, "snout_blend": 0.01,
    "jaw_base": 0.01, "jaw_end": 0.006, "jaw_blend": 0.005,
    "ear_width": 0.018, "ear_thick": 0.003, "ear_round": 0.008, "ear_yaw": 0.3, "ear_sink": 0.004, "ear_voxel": 0.001,
    "scapula": (0.015, 0.02, 0.02), "scapula_up": 0.0,
    "upper_arm": (0.018, 0.013), "forearm": (0.012, 0.01), "front_paw": (0.01, 0.009),
    "thigh": (0.022, 0.03, 0.03), "thigh_drop": 0.0,
    "upper_leg": (0.02, 0.014), "shin": (0.012, 0.01), "hind_paw": (0.01, 0.009),
    "limb_blend": 0.012, "joint_blend": 0.006,
    "tail": (0.016, 0.016, 0.014, 0.01), "tail_blend": 0.01,
}

COLORS = {"buff": "#d6bd8f", "cream": "#f3ead6", "black": "#201b18", "brown": "#8a6a45"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("buff")
    p.blend("brown", p.smooth(n[:, 2], 0.5, 0.3) * Wt("torso") * p.smooth(0.05 - np.abs(v[:, 1] + 0.02), 0.0, 0.05) * 0.4)
    p.blend("cream", p.smooth(-n[:, 2], 0.2, 0.4) * 0.6)
    for region in ("head", "snout", "jaw", "cheek"):
        p.region(region, "cream", 0.9)
    # The bandit mask across the eyes.
    p.blend("black", (Wt("head") + Wt("cheek")) * p.smooth(0.012 - np.abs(v[:, 2] - 0.162 + (v[:, 1] - 0.27) * 0.3), 0.0, 0.006)
            * p.smooth(v[:, 1] - 0.255, 0.0, 0.006))
    p.region_where("snout", "black", lambda v, n: p.smooth(v[:, 1] - 0.305, 0.0, 0.004))
    for leg in ("front_upper", "front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "black", 0.9)
    p.blend("black", p.smooth(0.075 - v[:, 2], 0.0, 0.02) * (1 - Wt("tail") - Wt("tail_tip")))
    p.region("tail_tip", "black")
    p.region_where("tail", "black", lambda v, n: p.smooth(-0.32 - v[:, 1], 0.0, 0.02))
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("black_footed_ferret", J, R, paint=paint, tiles_long=1.1)
    c.voxel = 0.0018
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.022, 0.265, 0.145), (0.017, 0.02, 0.016), "cheek", "head", blend=0.012, yaw=side * 0.3))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.0055, eye_sink=0.003, nose_radius=0.0045, nose_sink=0.002,
             iris="#140f0c", pupil="round")
    c.extras[-1].color = "#c98a7f"
    c.fur = {"strands": False, "variation": 0.08, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "gallop", "attack": "bite", "stride": 1.2, "gape": 0.8}
    return c
