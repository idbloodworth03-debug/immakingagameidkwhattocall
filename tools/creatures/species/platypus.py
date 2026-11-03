"""Platypus: a small, sleek, brown egg-laying mammal with a soft flat duck
bill, tiny eyes, short legs with webbed feet that sprawl out to the sides
and a broad flat beaver tail. Dark brown on top, golden-brown underneath,
a dark gray bill. It waddles on land.

Real size: about 45 cm long.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid, plate

J = {
    "pelvis": (0, -0.12, 0.08), "spine_mid": (0, 0.0, 0.09), "withers": (0, 0.1, 0.085),
    "neck_base": (0, 0.13, 0.085), "head_base": (0, 0.17, 0.09), "skull": (0, 0.19, 0.092),
    "snout_tip": (0, 0.26, 0.08), "jaw_hinge": (0, 0.19, 0.08), "chin": (0, 0.25, 0.076),
    "ear_base": (-0.028, 0.19, 0.11), "ear_tip": (-0.029, 0.189, 0.112),
    "shoulder": (-0.05, 0.1, 0.06), "elbow": (-0.08, 0.11, 0.04), "wrist": (-0.085, 0.13, 0.012), "front_toe": (-0.09, 0.16, 0.005),
    "hip": (-0.05, -0.11, 0.06), "knee": (-0.08, -0.1, 0.04), "hock": (-0.085, -0.13, 0.012), "hind_toe": (-0.09, -0.1, 0.005),
    "tail_base": (0, -0.17, 0.07), "tail_mid": (0, -0.23, 0.05), "tail_end": (0, -0.28, 0.035),
}
R = {
    "rump": (0.06, 0.07, 0.05), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.065, 0.1, 0.05), "belly_drop": 0.0,
    "chest": (0.06, 0.07, 0.05), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.03,
    "neck_base": 0.045, "neck_top": 0.04, "neck_blend": 0.02,
    "skull": (0.04, 0.04, 0.035), "head_blend": 0.015,
    "snout_root": (0, 0.03, -0.01), "snout_base": 0.018, "snout_end": 0.012, "snout_blend": 0.01,
    "jaw_base": 0.012, "jaw_end": 0.008, "jaw_blend": 0.005,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.02, 0.02, 0.02), "scapula_up": 0.0,
    "upper_arm": (0.018, 0.014), "forearm": (0.013, 0.011), "front_paw": (0.012, 0.006),
    "thigh": (0.025, 0.03, 0.025), "thigh_drop": 0.0,
    "upper_leg": (0.02, 0.014), "shin": (0.013, 0.011), "hind_paw": (0.012, 0.006),
    "limb_blend": 0.012, "joint_blend": 0.006,
    "tail": (0.03, 0.035, 0.03, 0.015), "tail_blend": 0.015,
}

COLORS = {"brown": "#5e3f2a", "gold": "#b58a5c", "bill": "#3d3c40", "foot": "#4a4548"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("brown")
    p.blend("gold", p.smooth(-p.n[:, 2], 0.0, 0.4) * 0.8)
    p.region("bill", "bill")
    p.region("front_paw", "foot", 0.8)
    p.region("hind_paw", "foot", 0.8)
    p.region("web", "foot")
    p.speckle(0.05)
    return p.colors


def make():
    c = quadruped("platypus", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.0018
    # The soft, flat duck bill and the broad flat tail.
    c.shapes.append(ellipsoid((0, 0.245, 0.082), (0.03, 0.045, 0.01), "bill", "head", blend=0.008))
    c.shapes.append(ellipsoid((0, -0.22, 0.05), (0.045, 0.07, 0.013), "tail", "tail1", blend=0.015, pitch=0.25))
    # Webbed feet.
    for side, sx in ((".L", 1), (".R", -1)):
        m = np.array([sx, 1, 1])
        for a, b in (("wrist", "front_toe"), ("hock", "hind_toe")):
            w, t = np.asarray(J[a], float) * m, np.asarray(J[b], float) * m
            bone = ("fl_foot" if a == "wrist" else "hl_foot") + side
            c.shapes.append(plate(w, t + (-sx * 0.02, 0, 0), t + (sx * 0.015, 0.008, 0), 0.004, 0.003, "web", bone, blend=0.004))
    add_face(c, eye_dir=(-0.75, 0.55, 0.35), eye_radius=0.0055, eye_sink=0.002, nose_radius=0.0, iris="#120d0b", pupil="round")
    c.fur = {"strands": False, "variation": 0.06, "sheen": 0.4, "bump": 0.15, "roughness": 0.5}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 1.0, "wiggle": 0.12, "gape": 0.4, "cycle_tiles": 0.6}
    return c
