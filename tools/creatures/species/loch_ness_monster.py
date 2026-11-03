"""Loch Ness Monster ("Nessie"), made shy and sweet: a round green
plesiosaur with a long graceful neck, a small head with a gentle smile,
four big paddle flippers and a short tail, with darker green spots and a
pale belly. On land it rows along on its flippers.

Mythical.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import plate

J = {
    "pelvis": (0, -0.3, 0.25), "spine_mid": (0, 0.0, 0.27), "withers": (0, 0.25, 0.26),
    "neck_base": (0, 0.36, 0.33), "head_base": (0, 0.5, 0.78), "skull": (0, 0.55, 0.82),
    "snout_tip": (0, 0.66, 0.8), "jaw_hinge": (0, 0.55, 0.785), "chin": (0, 0.64, 0.775),
    "ear_base": (-0.05, 0.54, 0.86), "ear_tip": (-0.051, 0.539, 0.863),
    "shoulder": (-0.18, 0.2, 0.18), "elbow": (-0.3, 0.25, 0.1), "wrist": (-0.4, 0.25, 0.04), "front_toe": (-0.5, 0.18, 0.012),
    "hip": (-0.16, -0.28, 0.18), "knee": (-0.26, -0.32, 0.1), "hock": (-0.34, -0.36, 0.04), "hind_toe": (-0.42, -0.42, 0.012),
    "tail_base": (0, -0.45, 0.24), "tail_mid": (0, -0.6, 0.18), "tail_end": (0, -0.72, 0.12),
}
R = {
    "rump": (0.22, 0.22, 0.18), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.26, 0.32, 0.2), "belly_drop": 0.0,
    "chest": (0.24, 0.22, 0.19), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.08,
    "neck_base": 0.11, "neck_top": 0.065, "neck_blend": 0.06,
    "skull": (0.07, 0.08, 0.065), "head_blend": 0.03,
    "snout_root": (0, 0.04, -0.015), "snout_base": 0.045, "snout_end": 0.03, "snout_blend": 0.02,
    "jaw_base": 0.03, "jaw_end": 0.02, "jaw_blend": 0.01,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.07, 0.07, 0.06), "scapula_up": 0.0,
    "upper_arm": (0.07, 0.05), "forearm": (0.05, 0.035), "front_paw": (0.03, 0.015),
    "thigh": (0.08, 0.08, 0.07), "thigh_drop": 0.0,
    "upper_leg": (0.06, 0.045), "shin": (0.045, 0.03), "hind_paw": (0.028, 0.014),
    "limb_blend": 0.04, "joint_blend": 0.02,
    "tail": (0.09, 0.05, 0.02), "tail_blend": 0.03,
}
COLORS = {"green": "#5fa86e", "dark": "#3f7a4c", "belly": "#d8e8b0"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    p.fill("green")
    p.blend("belly", p.smooth(-n[:, 2], 0.1, 0.4) * 0.9)
    p.spots("dark", cell=0.1, radius=0.025, mask=p.smooth(n[:, 2], 0.0, 0.4) * 0.8, seed=14)
    p.region("front_paw", "dark", 0.5)
    p.region("hind_paw", "dark", 0.5)
    return p.colors


def make():
    c = quadruped("loch_ness_monster", J, R, paint=paint, tiles_long=2.4)
    c.voxel = 0.006
    for side, sx in ((".L", 1), (".R", -1)):
        m = np.array([sx, 1, 1])
        for a, b, bone, w in (("elbow", "front_toe", "fl_foot", 0.08), ("knee", "hind_toe", "hl_foot", 0.07)):
            e, t = np.asarray(J[a], float) * m, np.asarray(J[b], float) * m
            c.shapes.append(plate(e + (0, w, 0), e + (0, -w, 0), t, 0.016, 0.014, "front_paw" if bone == "fl_foot" else "hind_paw",
                                  bone + side, blend=0.02))
    add_face(c, eye_dir=(-0.6, 0.7, 0.35), eye_radius=0.013, eye_sink=0.005, nose_radius=0.0, iris="#2a1e12", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.35, "bump": 0.05, "roughness": 0.45}
    c.motion = {"gait": "flipper", "attack": "bite", "stride": 0.9, "gape": 0.5, "cycle_tiles": 0.8}
    c.cartoon = {"head": 1.3}
    return c
