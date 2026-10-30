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
    "pelvis": (0, -0.55, 0.95),
    "spine_mid": (0, -0.05, 1.0),
    "withers": (0, 0.40, 1.08),
    "neck_base": (0, 0.52, 0.94),
    "head_base": (0, 0.80, 0.88),
    "skull": (0, 0.88, 0.89),
    "snout_tip": (0, 1.15, 0.79),
    "jaw_hinge": (0, 0.87, 0.80),
    "chin": (0, 1.08, 0.735),
    "ear_base": (-0.10, 0.86, 1.0),
    "ear_tip": (-0.125, 0.84, 1.08),
    "shoulder": (-0.17, 0.50, 0.82),
    "elbow": (-0.18, 0.38, 0.55),
    "wrist": (-0.17, 0.44, 0.14),
    "front_toe": (-0.17, 0.60, 0.05),
    "hip": (-0.18, -0.58, 0.86),
    "knee": (-0.19, -0.40, 0.56),
    "hock": (-0.18, -0.70, 0.16),
    "hind_toe": (-0.17, -0.47, 0.05),
    "tail_base": (0, -0.82, 0.92),
    "tail_mid": (0, -0.87, 0.86),
    "tail_end": (0, -0.90, 0.80),
}

R = {
    "rump": (0.24, 0.34, 0.27), "rump_back": 0.03, "rump_drop": 0.17,
    "belly": (0.29, 0.6, 0.27), "belly_drop": 0.23,
    "chest": (0.29, 0.38, 0.33), "chest_back": 0.1, "chest_drop": 0.25,
    "torso_blend": 0.16,
    "neck_base": 0.24, "neck_top": 0.17, "neck_blend": 0.12,
    "skull": (0.155, 0.15, 0.13), "skull_pitch": -0.05, "head_blend": 0.07,
    "snout_root": (0, 0.1, -0.045), "snout_base": 0.095, "snout_end": 0.06, "snout_blend": 0.05,
    "jaw_base": 0.065, "jaw_end": 0.042, "jaw_blend": 0.025,
    "ear_width": 0.095, "ear_thick": 0.014, "ear_round": 0.03, "ear_yaw": 0.3, "ear_sink": 0.03, "ear_voxel": 0.004,
    "ear_fur": 0.02,
    "scapula": (0.13, 0.2, 0.25), "scapula_up": 0.14, "scapula_pitch": 0.25,
    "upper_arm": (0.15, 0.115), "forearm": (0.11, 0.09), "front_paw": (0.085, 0.08),
    "thigh": (0.2, 0.27, 0.29), "thigh_drop": 0.12, "thigh_pitch": -0.2,
    "upper_leg": (0.18, 0.12), "shin": (0.11, 0.09), "hind_paw": (0.085, 0.08),
    "limb_blend": 0.11, "joint_blend": 0.05,
    "tail": (0.06, 0.055, 0.04, 0.02), "tail_blend": 0.05,
}

COLORS = {
    "brown": "#3d2717",
    "tips": "#7a5a3a",
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
    c.shapes.append(ellipsoid((0, 0.34, 1.08), (0.22, 0.28, 0.15), "torso", "chest", blend=0.12))
    # A heavy brow and round cheeks for the dished face.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.11, 0.86, 0.84), (0.085, 0.1, 0.09), "cheek", "head", blend=0.06))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.017, eye_sink=0.012, nose_radius=0.04, nose_sink=0.016,
             iris="#4a2a14", pupil="round")
    c.fur = {"variation": 0.2, "sheen": 0.25, "bump": 0.35, "length": 0.07, "density": 9000, "hair_gamma": 2.1,
             "frizz": 0.004, "clump": 0.4,
             "lengths": {"cheek": 1.1, "tail": 0.9, "tail_tip": 0.9, "head": 0.5, "front_paw": 0.4, "hind_paw": 0.4}}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.32, "stride": 0.9}
    return c
