"""Shoebill: a tall, slate-blue stork-like bird standing very still on long
dark legs, with a huge head, a big pale eye, a little crest at the back and
an enormous wide, shoe-shaped yellowish bill with a hooked tip. It stalks.

Real size: about 1.2 m tall.
Built standing up like the primates: the "front legs" are its folded wings.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid

J = {
    "pelvis": (0, -0.05, 0.62), "spine_mid": (0, 0.0, 0.72), "withers": (0, 0.04, 0.84),
    "neck_base": (0, 0.06, 0.9), "head_base": (0, 0.1, 1.02), "skull": (0, 0.12, 1.08),
    "snout_tip": (0, 0.34, 1.0), "jaw_hinge": (0, 0.15, 1.02), "chin": (0, 0.32, 0.97),
    "ear_base": (-0.07, 0.11, 1.1), "ear_tip": (-0.071, 0.109, 1.103),
    "shoulder": (-0.1, 0.04, 0.84), "elbow": (-0.12, -0.04, 0.76), "wrist": (-0.12, -0.12, 0.68), "front_toe": (-0.11, -0.2, 0.62),
    "hip": (-0.06, -0.02, 0.6), "knee": (-0.065, 0.04, 0.32), "hock": (-0.065, 0.0, 0.06), "hind_toe": (-0.065, 0.12, 0.005),
    "tail_base": (0, -0.16, 0.62), "tail_mid": (0, -0.22, 0.56), "tail_end": (0, -0.26, 0.52),
}
R = {
    "rump": (0.12, 0.12, 0.12), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.13, 0.14, 0.14), "belly_drop": 0.0,
    "chest": (0.12, 0.12, 0.12), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.06,
    "neck_base": 0.07, "neck_top": 0.065, "neck_blend": 0.04,
    "skull": (0.075, 0.08, 0.075), "head_blend": 0.03,
    "snout_root": (0, 0.05, -0.01), "snout_base": 0.07, "snout_end": 0.04, "snout_blend": 0.02,
    "jaw_base": 0.05, "jaw_end": 0.03, "jaw_blend": 0.01,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.05, 0.05, 0.05), "scapula_up": 0.0,
    "upper_arm": (0.06, 0.055), "forearm": (0.055, 0.045), "front_paw": (0.045, 0.02),
    "thigh": (0.05, 0.05, 0.06), "thigh_drop": 0.0,
    "upper_leg": (0.025, 0.02), "shin": (0.016, 0.014), "hind_paw": (0.014, 0.008),
    "limb_blend": 0.03, "joint_blend": 0.01,
    "tail": (0.05, 0.05, 0.04), "tail_blend": 0.02,
}
COLORS = {"slate": "#7f8c99", "wing": "#5e6a75", "bill": "#d7c69a", "spot": "#8a6a48", "leg": "#3d3f44"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("slate")
    for r in ("front_upper", "front_lower", "front_paw", "shoulder"):
        p.region(r, "wing", 0.8)
    p.region("snout", "bill")
    p.region("jaw", "bill")
    p.spots("spot", cell=0.03, radius=0.008, mask=(Wt("snout") + Wt("jaw")) * 0.7, seed=11)
    for leg in ("hind_lower", "hind_paw"):
        p.region(leg, "leg")
    p.blend("leg", p.smooth(0.5 - p.v[:, 2], 0.0, 0.05) * (1 - Wt("torso")))
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("shoebill", J, R, paint=paint, tiles_long=1.4)
    c.voxel = 0.004
    # The big shoe-shaped bill with its hooked tip, and a little crest.
    c.shapes.append(ellipsoid((0, 0.25, 1.0), (0.065, 0.11, 0.05), "snout", "head", blend=0.02))
    tip = np.asarray(J["snout_tip"], float)
    c.shapes.append(cone(tip + (0, -0.01, 0.01), tip + (0, 0.005, -0.04), 0.015, 0.004, "snout", "head", blend=0.008))
    sk = np.asarray(J["skull"], float)
    c.shapes.append(cone(sk + (0, -0.05, 0.04), sk + (0, -0.11, 0.06), 0.02, 0.006, "head", "head", blend=0.015))
    add_face(c, eye_dir=(-0.65, 0.6, 0.35), eye_radius=0.014, eye_sink=0.006, nose_radius=0.0, iris="#e6dfb0", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "biped", "attack": "bite", "rear": 0.0, "stride": 0.8, "cycle_tiles": 0.6}
    return c
