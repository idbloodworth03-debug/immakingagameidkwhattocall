"""Kakapo: the world's heaviest parrot, which can't fly: a chunky round
moss-green bird mottled with black and yellow, a pale yellow-green owl-like
face disc with soft whiskery feathers, a big pale gray beak, short wings
held at its sides, sturdy pink-gray legs and a short tail. It walks
everywhere.

Real size: about 60 cm long.
Built standing up like the primates: the "front legs" are its folded wings.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid

J = {
    "pelvis": (0, -0.08, 0.17), "spine_mid": (0, 0.0, 0.23), "withers": (0, 0.06, 0.3),
    "neck_base": (0, 0.08, 0.34), "head_base": (0, 0.11, 0.38), "skull": (0, 0.14, 0.4),
    "snout_tip": (0, 0.27, 0.36), "jaw_hinge": (0, 0.18, 0.355), "chin": (0, 0.235, 0.345),
    "ear_base": (-0.05, 0.13, 0.43), "ear_tip": (-0.051, 0.129, 0.433),
    "shoulder": (-0.085, 0.05, 0.29), "elbow": (-0.1, 0.0, 0.24), "wrist": (-0.1, -0.06, 0.19), "front_toe": (-0.095, -0.12, 0.16),
    "hip": (-0.05, -0.04, 0.12), "knee": (-0.055, -0.01, 0.075), "hock": (-0.055, -0.02, 0.03), "hind_toe": (-0.055, 0.04, 0.006),
    "tail_base": (0, -0.15, 0.15), "tail_mid": (0, -0.22, 0.11), "tail_end": (0, -0.27, 0.085),
}
R = {
    "rump": (0.1, 0.1, 0.1), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.12, 0.12, 0.12), "belly_drop": 0.0,
    "chest": (0.11, 0.1, 0.11), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.05,
    "neck_base": 0.07, "neck_top": 0.056, "neck_blend": 0.04,
    "skull": (0.08, 0.078, 0.072), "head_blend": 0.025,
    "snout_root": (0, 0.05, -0.01), "snout_base": 0.046, "snout_end": 0.02, "snout_blend": 0.01,
    "jaw_base": 0.016, "jaw_end": 0.006, "jaw_blend": 0.004,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.04, 0.04, 0.04), "scapula_up": 0.0,
    "upper_arm": (0.045, 0.04), "forearm": (0.04, 0.032), "front_paw": (0.03, 0.015),
    "thigh": (0.045, 0.045, 0.045), "thigh_drop": 0.0,
    "upper_leg": (0.026, 0.021), "shin": (0.019, 0.016), "hind_paw": (0.02, 0.01),
    "limb_blend": 0.025, "joint_blend": 0.01,
    "tail": (0.045, 0.04, 0.03), "tail_blend": 0.02,
}

COLORS = {"moss": "#7aa23a", "black": "#2a3218", "yellow": "#c9c45c", "face": "#c6cc7c", "beak": "#d6d0c6", "leg": "#b8a59f"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("moss")
    # Fine black and yellow barring all over the green.
    body = 1 - p.mesh.region_weight("face") - p.mesh.region_weight("snout") - p.mesh.region_weight("jaw")
    p.spots("black", cell=0.03, radius=0.007, mask=body * 0.7, seed=8)
    p.spots("yellow", cell=0.035, radius=0.008, mask=body * 0.6, seed=9)
    p.blend("yellow", p.smooth(-n[:, 2] + n[:, 1] * 0.3, 0.2, 0.4) * Wt("torso") * 0.6)
    p.region("face", "face")
    p.blend("face", p.mesh.region_weight("head") * p.smooth(p.n[:, 1], 0.3, 0.3) * 0.8)
    p.region("snout", "beak")
    p.region("jaw", "beak")
    for leg in ("hind_lower", "hind_paw"):
        p.region(leg, "leg")
    return p.colors


def make():
    c = quadruped("kakapo", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.0028
    sk = np.asarray(J["skull"], float)
    # The owl-like face disc and the hooked beak.
    c.shapes.append(ellipsoid(tuple(sk + (0, 0.05, -0.01)), (0.08, 0.032, 0.068), "face", "head", blend=0.02))
    tip = np.asarray(J["snout_tip"], float)
    c.shapes.append(cone(tip, tip + (0, -0.008, -0.065), 0.02, 0.006, "snout", "head", blend=0.006))
    add_face(c, eye_dir=(-0.55, 0.78, 0.25), eye_radius=0.011, eye_sink=0.004, nose_radius=0.0, iris="#1b140c", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "biped", "attack": "bite", "rear": 0.0, "stride": 0.8, "wiggle": 0.12, "cycle_tiles": 0.55}
    c.palette = {"eye_line": "#1b1f12"}
    # A Stun animal: a big wind-up before the blow that stuns.
    c.motion["special"] = True
    return c
