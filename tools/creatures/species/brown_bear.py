"""Brown Bear: massive, with a muscular shoulder hump higher than the hips,
a fairly small head with a dished face and small round ears, thick legs on
flat-footed paws, a stubby tail and a shaggy coat. Dark brown with lighter,
grizzled tips on the back and a tan muzzle.

Real size: about 1.05 m at the shoulder hump, 2 m long.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.55, 0.93),
    "spine_mid": (0, -0.05, 0.98),
    "withers": (0, 0.42, 1.06),
    "neck_base": (0, 0.55, 0.90),
    "head_base": (0, 0.76, 0.92),
    "skull": (0, 0.84, 0.93),
    "snout_tip": (0, 1.09, 0.83),
    "jaw_hinge": (0, 0.83, 0.84),
    "chin": (0, 1.02, 0.77),
    "ear_base": (-0.10, 0.82, 1.05),
    "ear_tip": (-0.125, 0.80, 1.13),
    "shoulder": (-0.17, 0.52, 0.78),
    "elbow": (-0.18, 0.40, 0.50),
    "wrist": (-0.17, 0.46, 0.13),
    "front_toe": (-0.17, 0.62, 0.05),
    "hip": (-0.18, -0.58, 0.84),
    "knee": (-0.19, -0.40, 0.52),
    "hock": (-0.18, -0.70, 0.15),
    "hind_toe": (-0.17, -0.47, 0.05),
    "tail_base": (0, -0.82, 0.90),
    "tail_mid": (0, -0.87, 0.84),
    "tail_end": (0, -0.90, 0.78),
}

R = {
    "rump": (0.30, 0.36, 0.31), "rump_back": 0.03, "rump_drop": 0.2,
    "belly": (0.33, 0.6, 0.33), "belly_drop": 0.27,
    "chest": (0.33, 0.42, 0.40), "chest_back": 0.12, "chest_drop": 0.3,
    "torso_blend": 0.3,
    "neck_base": 0.28, "neck_top": 0.2, "neck_blend": 0.18,
    "skull": (0.165, 0.16, 0.14), "skull_pitch": -0.05, "head_blend": 0.1,
    "snout_root": (0, 0.1, -0.05), "snout_base": 0.105, "snout_end": 0.065, "snout_blend": 0.07,
    "jaw_base": 0.07, "jaw_end": 0.045, "jaw_blend": 0.03,
    "ear_width": 0.095, "ear_thick": 0.014, "ear_round": 0.03, "ear_yaw": 0.3, "ear_sink": 0.03, "ear_voxel": 0.004,
    "ear_fur": 0.02,
    "scapula": (0.15, 0.22, 0.28), "scapula_up": 0.16, "scapula_pitch": 0.25,
    "upper_arm": (0.17, 0.13), "forearm": (0.125, 0.1), "front_paw": (0.09, 0.085),
    "thigh": (0.23, 0.3, 0.32), "thigh_drop": 0.14, "thigh_pitch": -0.2,
    "upper_leg": (0.2, 0.135), "shin": (0.125, 0.1), "hind_paw": (0.09, 0.085),
    "limb_blend": 0.16, "joint_blend": 0.06,
    "tail": (0.06, 0.055, 0.04, 0.02), "tail_blend": 0.05,
}

COLORS = {
    "brown": "#4f321e",
    "tips": "#8a6844",
    "dark": "#24170f",
    "muzzle": "#86654a",
    "nose": "#1a1210",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("brown")
    # Grizzled, sun-bleached tips over the hump and back.
    p.where("tips", lambda v, n: p.smooth(n[:, 2], 0.35, 0.5) * p.smooth(v[:, 2] - 0.85, 0.0, 0.2), 0.55)
    # Legs darken toward the paws.
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "dark", 0.75)
    p.region_where("front_upper", "dark", lambda v, n: p.smooth(0.6 - v[:, 2], 0.0, 0.15), 0.6)
    p.region_where("thigh", "dark", lambda v, n: p.smooth(0.55 - v[:, 2], 0.0, 0.15), 0.5)
    # Lighter muzzle.
    p.region("snout", "muzzle", 0.85)
    p.region("jaw", "muzzle", 0.6)
    p.region("ear", "dark", 0.4)
    p.speckle(0.18)
    return p.colors


def make():
    c = quadruped("brown_bear", J, R, paint=paint, tiles_long=2.3)
    # The shoulder hump: a big muscle mass over the front legs.
    c.shapes.append(ellipsoid((0, 0.36, 1.06), (0.26, 0.3, 0.16), "torso", "chest", blend=0.18))
    # A heavy brow and round cheeks for the dished face.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.12, 0.83, 0.88), (0.1, 0.11, 0.1), "cheek", "head", blend=0.08))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.017, eye_sink=0.012, nose_radius=0.04, nose_sink=0.016,
             iris="#4a2a14", pupil="round")
    c.fur = {"variation": 0.2, "sheen": 0.25, "bump": 0.35, "length": 0.07, "density": 9000, "hair_gamma": 2.1,
             "frizz": 0.004, "clump": 0.4,
             "lengths": {"cheek": 1.1, "tail": 0.9, "tail_tip": 0.9, "head": 0.5, "front_paw": 0.4, "hind_paw": 0.4}}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.32, "stride": 0.9}
    return c
