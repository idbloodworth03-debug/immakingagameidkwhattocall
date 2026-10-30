"""Brown Rat (Sewer Rats is four of them): low hunched body, pointed snout
with whiskery muzzle, round pinkish ears, long nearly bare pink tail, pink
feet. Brown-gray coat with a paler belly.

Real size: about 8 cm at the shoulder, 22 cm head and body, 20 cm tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.06, 0.072),
    "spine_mid": (0, 0.0, 0.078),
    "withers": (0, 0.05, 0.066),
    "neck_base": (0, 0.062, 0.058),
    "head_base": (0, 0.086, 0.062),
    "skull": (0, 0.096, 0.063),
    "snout_tip": (0, 0.131, 0.049),
    "jaw_hinge": (0, 0.097, 0.053),
    "chin": (0, 0.12, 0.045),
    "ear_base": (-0.012, 0.092, 0.077),
    "ear_tip": (-0.019, 0.088, 0.093),
    "shoulder": (-0.016, 0.055, 0.044),
    "elbow": (-0.018, 0.04, 0.03),
    "wrist": (-0.016, 0.05, 0.008),
    "front_toe": (-0.016, 0.062, 0.003),
    "hip": (-0.019, -0.058, 0.055),
    "knee": (-0.021, -0.034, 0.035),
    "hock": (-0.019, -0.075, 0.01),
    "hind_toe": (-0.017, -0.05, 0.003),
    "tail_base": (0, -0.098, 0.06),
    "tail_mid": (0, -0.19, 0.03),
    "tail_end": (0, -0.27, 0.016),
}

R = {
    "rump": (0.031, 0.045, 0.032), "rump_back": 0.004, "rump_drop": 0.018,
    "belly": (0.033, 0.06, 0.03), "belly_drop": 0.022,
    "chest": (0.028, 0.038, 0.028), "chest_back": 0.006, "chest_drop": 0.02,
    "torso_blend": 0.025,
    "neck_base": 0.022, "neck_top": 0.017, "neck_blend": 0.015,
    "skull": (0.018, 0.021, 0.017), "skull_pitch": -0.15, "head_blend": 0.012,
    "snout_root": (0, 0.014, -0.004), "snout_base": 0.013, "snout_end": 0.0065, "snout_blend": 0.008,
    "jaw_base": 0.007, "jaw_end": 0.003, "jaw_blend": 0.004,
    "ear_width": 0.017, "ear_thick": 0.0012, "ear_round": 0.005, "ear_yaw": 0.5, "ear_sink": 0.003,
    "ear_voxel": 0.0006, "ear_fur": 0.0012,
    "scapula": (0.011, 0.016, 0.02), "scapula_up": 0.012, "scapula_pitch": 0.3,
    "upper_arm": (0.011, 0.007), "forearm": (0.006, 0.0045), "front_paw": (0.004, 0.0045),
    "thigh": (0.016, 0.022, 0.024), "thigh_drop": 0.01, "thigh_pitch": -0.2,
    "upper_leg": (0.014, 0.009), "shin": (0.0065, 0.005), "hind_paw": (0.0045, 0.005),
    "limb_blend": 0.012, "joint_blend": 0.004,
    "tail": (0.0075, 0.005, 0.0032, 0.0018), "tail_blend": 0.006,
}

COLORS = {
    "coat": "#5f4e40",
    "tips": "#8c7a66",
    "belly": "#b5a893",
    "pink": "#c99a90",
    "dark": "#2a201a",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("coat")
    p.where("tips", lambda v, n: p.smooth(n[:, 2], 0.2, 0.6), 0.45)
    p.region_underside("torso", "belly", below=-0.3, soft=0.3, strength=0.9)
    p.region("jaw", "belly", 0.7)
    p.region_where("snout", "belly", lambda v, n: p.smooth(-n[:, 2], 0.0, 0.4), 0.6)
    # Bare pink tail, feet and ears.
    for part in ("tail", "tail_tip", "front_paw", "hind_paw", "ear"):
        p.region(part, "pink")
    p.region_where("tail", "coat", lambda v, n: p.smooth(-0.13 - v[:, 1], 0.0, 0.03) * 0 + p.smooth(v[:, 1] + 0.12, 0.0, 0.02), 0.8)
    p.speckle(0.18)
    return p.colors


def make():
    c = quadruped("sewer_rats", J, R, paint=paint, tiles_long=0.85)
    c.voxel = 0.0018
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.013, 0.1, 0.055), (0.011, 0.014, 0.011), "cheek", "head", blend=0.008))
    add_face(c, eye_dir=(-0.6, 0.7, 0.35), eye_radius=0.0035, eye_sink=0.0016, nose_radius=0.003, nose_sink=0.0012,
             iris="#100808", pupil="round")
    c.extras[-1].color = "#c47a78"     # pink nose
    c.fur = {"variation": 0.18, "sheen": 0.3, "bump": 0.3, "length": 0.007, "density": 900000, "hair_gamma": 1.9,
             "strand": 0.0004, "lengths": {"tail": 0.0, "tail_tip": 0.0, "front_paw": 0.0, "hind_paw": 0.0, "snout": 0.15,
                                           "cheek": 0.8, "torso": 1.0}}
    c.motion = {"gait": "trot", "attack": "bite", "stride": 1.2}
    return c
