"""Red Fox: slender body on long thin legs, narrow pointed muzzle, big
pointed ears, long bushy tail with a white tip. Orange-red coat, white
throat, chest and lower muzzle, black "stockings" and black ear backs.

Real size: about 38 cm at the shoulder, 65 cm head and body, 40 cm tail.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from sdf import ellipsoid
from paint import Painter

J = {
    # Spine and torso
    "pelvis": (0, -0.20, 0.365),
    "spine_mid": (0, -0.02, 0.372),
    "withers": (0, 0.17, 0.385),
    # Neck and head
    "neck_base": (0, 0.20, 0.335),
    "head_base": (0, 0.295, 0.43),
    "skull": (0, 0.325, 0.452),
    "snout_tip": (0, 0.455, 0.415),
    "jaw_hinge": (0, 0.325, 0.418),
    "chin": (0, 0.43, 0.397),
    "ear_base": (-0.031, 0.312, 0.488),
    "ear_tip": (-0.052, 0.302, 0.572),
    # Front leg: point of shoulder, elbow at the bottom of the chest, wrist, toes
    "shoulder": (-0.048, 0.205, 0.300),
    "elbow": (-0.052, 0.140, 0.210),
    "wrist": (-0.048, 0.155, 0.060),
    "front_toe": (-0.047, 0.195, 0.014),
    # Hind leg: hip, knee forward, hock back, toes
    "hip": (-0.052, -0.200, 0.330),
    "knee": (-0.058, -0.130, 0.215),
    "hock": (-0.052, -0.268, 0.100),
    "hind_toe": (-0.048, -0.232, 0.014),
    # Tail, carried low
    "tail_base": (0, -0.290, 0.352),
    "tail_mid": (0, -0.460, 0.268),
    "tail_end": (0, -0.615, 0.190),
}

R = {
    "rump": (0.074, 0.115, 0.078), "rump_back": 0.01, "rump_drop": 0.052,
    "belly": (0.084, 0.21, 0.073), "belly_drop": 0.068,
    "chest": (0.078, 0.13, 0.098), "chest_back": 0.04, "chest_drop": 0.09,
    "torso_blend": 0.12,
    "neck_base": 0.072, "neck_top": 0.05, "neck_blend": 0.07,
    "skull": (0.052, 0.058, 0.047), "skull_pitch": -0.15, "head_blend": 0.04,
    "snout_root": (0, 0.04, -0.014), "snout_base": 0.032, "snout_end": 0.0115, "snout_blend": 0.03,
    "jaw_base": 0.021, "jaw_end": 0.009, "jaw_blend": 0.012,
    "ear_width": 0.056, "ear_thick": 0.0034, "ear_yaw": 0.6, "ear_sink": 0.014,
    "scapula": (0.034, 0.055, 0.075), "scapula_up": 0.05, "scapula_pitch": 0.35,
    "upper_arm": (0.04, 0.027), "forearm": (0.022, 0.015), "front_paw": (0.0145, 0.0155),
    "thigh": (0.05, 0.075, 0.08), "thigh_drop": 0.035, "thigh_pitch": -0.25,
    "upper_leg": (0.047, 0.028), "shin": (0.022, 0.0145), "hind_paw": (0.0145, 0.0155),
    "limb_blend": 0.05, "joint_blend": 0.016,
    "tail": (0.03, 0.05, 0.058, 0.03), "tail_blend": 0.045,
}

COLORS = {
    "coat": "#b84a19",
    "back": "#8c3412",
    "white": "#efe9df",
    "black": "#1d1714",
    "ear_inner": "#e9d8c4",
    "tail_dark": "#7e3a1a",
    "flank": "#cf7a36",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("coat")
    # Lighter, yellower flanks and a darker red back, like a real coat.
    p.where("flank", lambda v, n: p.smooth(np.abs(n[:, 0]), 0.5, 0.4) * p.smooth(0.36 - v[:, 2], 0.0, 0.08), 0.4)
    p.top_darken("back", start=0.45, strength=0.55)
    # White bib on the throat and chest, white belly.
    p.region_where("neck", "white", lambda v, n: p.smooth(n[:, 1] * 0.7 - n[:, 2] * 0.7, 0.1, 0.3) * p.smooth(0.42 - v[:, 2], 0.0, 0.03))
    p.region_where("torso", "white", lambda v, n: p.smooth(v[:, 1] - 0.12, 0.0, 0.05) * p.smooth(0.31 - v[:, 2], 0.0, 0.04)
                   * p.smooth(0.05 - np.abs(v[:, 0]), 0.0, 0.03))
    p.region_underside("torso", "white", below=-0.55, soft=0.25, strength=0.8)
    p.region("jaw", "white")
    p.region_where("cheek", "white", lambda v, n: p.smooth(0.44 - v[:, 2], 0.0, 0.02))
    # Lower half of the muzzle white (the classic fox "mask").
    p.region_where("snout", "white", lambda v, n: p.smooth(-n[:, 2] + 0.1, 0.0, 0.3) + p.smooth(0.418 - v[:, 2], 0.0, 0.01))
    p.region_where("head", "white", lambda v, n: p.smooth(0.432 - v[:, 2], 0.0, 0.012) * p.smooth(np.abs(v[:, 0]) - 0.02, 0.0, 0.02))
    # Black stockings: front leg below the elbow, hind leg below the knee.
    p.region("front_lower", "black")
    p.region("front_paw", "black")
    p.region_where("front_upper", "black", lambda v, n: p.smooth(0.24 - v[:, 2], 0.0, 0.03))
    p.region("hind_paw", "black")
    p.region_where("hind_lower", "black", lambda v, n: p.smooth(0.17 - v[:, 2], 0.0, 0.05))
    # Ears: black backs, pale inside the cup.
    p.region("ear", "black")
    p.region_where("ear", "ear_inner", lambda v, n: p.smooth(n[:, 1], 0.3, 0.4) * p.smooth(0.56 - v[:, 2], 0.0, 0.015))
    # Tail: darker on top, white tip.
    p.region_where("tail", "tail_dark", lambda v, n: p.smooth(n[:, 2], 0.3, 0.8) * 0.6)
    p.region("tail_tip", "white")
    p.region_where("tail", "white", lambda v, n: p.smooth(-0.64 - v[:, 1], 0.0, 0.03))
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("red_fox", J, R, paint=paint, tiles_long=1.6)
    # Fluffy cheeks that make the head a wedge, and a full plume of a tail.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.036, 0.322, 0.432), (0.03, 0.04, 0.032), "cheek", "head", blend=0.03, yaw=side * 0.3))
    tail_mid, tail_end = np.asarray(J["tail_mid"]), np.asarray(J["tail_end"])
    plume = ellipsoid((tail_mid + tail_end) / 2, (0.062, 0.15, 0.06), "tail", "tail2", blend=0.06,
                      pitch=np.arctan2(tail_mid[2] - tail_end[2], tail_mid[1] - tail_end[1]))
    c.shapes.append(plume)
    add_face(c, eye_dir=(-0.6, 0.74, 0.3), eye_radius=0.0085, eye_sink=0.0055, nose_radius=0.0085, nose_sink=0.005,
             iris="#c8862a", pupil="slit")
    c.fur = {"variation": 0.14, "sheen": 0.3, "bump": 0.3}
    c.motion = {"gait": "trot", "attack": "pounce_bite", "weight": 0.3}
    c.palette = {"eye_line_size": 1.75}
    return c
