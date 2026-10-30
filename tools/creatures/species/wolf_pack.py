"""Gray Wolf (the Wolf Pack card is three of them): long-legged, deep narrow
chest, broad head with a thick ruff, ears shorter than a fox's, straight
bushy tail hanging low. Grizzled gray coat with a darker saddle, cream face,
throat, belly and legs, dark tail tip.

Real size: about 75 cm at the shoulder, 1.2 m head and body, 45 cm tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.40, 0.74),
    "spine_mid": (0, -0.05, 0.75),
    "withers": (0, 0.30, 0.78),
    "neck_base": (0, 0.36, 0.70),
    "head_base": (0, 0.52, 0.86),
    "skull": (0, 0.57, 0.89),
    "snout_tip": (0, 0.79, 0.81),
    "jaw_hinge": (0, 0.56, 0.82),
    "chin": (0, 0.74, 0.775),
    "ear_base": (-0.06, 0.54, 0.95),
    "ear_tip": (-0.092, 0.515, 1.105),
    "shoulder": (-0.09, 0.37, 0.60),
    "elbow": (-0.095, 0.26, 0.42),
    "wrist": (-0.09, 0.29, 0.11),
    "front_toe": (-0.088, 0.36, 0.025),
    "hip": (-0.095, -0.40, 0.66),
    "knee": (-0.105, -0.26, 0.44),
    "hock": (-0.095, -0.53, 0.19),
    "hind_toe": (-0.09, -0.46, 0.025),
    "tail_base": (0, -0.55, 0.70),
    "tail_mid": (0, -0.70, 0.50),
    "tail_end": (0, -0.79, 0.30),
}

R = {
    "rump": (0.13, 0.19, 0.14), "rump_back": 0.02, "rump_drop": 0.10,
    "belly": (0.145, 0.36, 0.13), "belly_drop": 0.135,
    "chest": (0.15, 0.24, 0.20), "chest_back": 0.07, "chest_drop": 0.17,
    "torso_blend": 0.2,
    "neck_base": 0.15, "neck_top": 0.10, "neck_blend": 0.12,
    "skull": (0.098, 0.105, 0.088), "skull_pitch": -0.1, "head_blend": 0.07,
    "snout_root": (0, 0.08, -0.03), "snout_base": 0.07, "snout_end": 0.036, "snout_blend": 0.05,
    "jaw_base": 0.046, "jaw_end": 0.025, "jaw_blend": 0.022,
    "ear_width": 0.1, "ear_thick": 0.0065, "ear_yaw": 0.45, "ear_sink": 0.025, "ear_voxel": 0.003, "ear_fur": 0.014,
    "scapula": (0.065, 0.1, 0.15), "scapula_up": 0.1, "scapula_pitch": 0.35,
    "upper_arm": (0.088, 0.058), "forearm": (0.05, 0.036), "front_paw": (0.035, 0.038),
    "thigh": (0.105, 0.15, 0.16), "thigh_drop": 0.07, "thigh_pitch": -0.25,
    "upper_leg": (0.1, 0.06), "shin": (0.05, 0.035), "hind_paw": (0.035, 0.038),
    "limb_blend": 0.09, "joint_blend": 0.03,
    "tail": (0.05, 0.085, 0.08, 0.04), "tail_blend": 0.07,
}

COLORS = {
    "gray": "#6d675f",
    "saddle": "#38332e",
    "cream": "#d2c4ad",
    "tan": "#9a8b78",
    "dark": "#26221f",
    "ear_inner": "#d8cbb8",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("gray")
    # Tan-buff legs and lower flanks, cream underside, darker saddle on top.
    p.where("tan", lambda v, n: p.smooth(0.5 - v[:, 2], 0.0, 0.12) * (1 - p.mesh.region_weight("tail") - p.mesh.region_weight("tail_tip")), 0.7)
    p.top_darken("saddle", start=0.35, strength=0.65)
    p.region_underside("torso", "cream", below=-0.6, soft=0.25, strength=0.85)
    p.region_where("neck", "cream", lambda v, n: p.smooth(n[:, 1] * 0.5 - n[:, 2] * 0.9, 0.25, 0.3) * p.smooth(0.74 - v[:, 2], 0.0, 0.06), 0.85)
    p.region_where("torso", "cream", lambda v, n: p.smooth(v[:, 1] - 0.3, 0.0, 0.08) * p.smooth(0.52 - v[:, 2], 0.0, 0.08) * p.smooth(0.08 - np.abs(v[:, 0]), 0.0, 0.05))
    # Face mask: cream muzzle, cheeks and brows.
    p.region("jaw", "cream")
    p.region_where("snout", "cream", lambda v, n: p.smooth(-n[:, 2] + 0.3, 0.0, 0.4))
    p.region_where("cheek", "cream", lambda v, n: p.smooth(0.88 - v[:, 2], 0.0, 0.05))
    p.region_where("snout", "dark", lambda v, n: p.smooth(v[:, 1] - 0.74, 0.0, 0.03) * p.smooth(n[:, 2], 0.2, 0.3), 0.6)
    # Legs: buff, paler toward the paws.
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "tan", 0.6)
        p.region_where(leg, "cream", lambda v, n: p.smooth(0.2 - v[:, 2], 0.0, 0.1), 0.6)
    # Ears: gray backs with dark rims, pale inside.
    p.region("ear", "gray")
    p.region_where("ear", "ear_inner", lambda v, n: p.smooth(n[:, 1], 0.3, 0.4))
    p.region_where("ear", "dark", lambda v, n: p.smooth(v[:, 2] - 1.04, 0.0, 0.015), 0.8)
    # Tail: saddle-dark on top, black tip.
    p.region_where("tail", "saddle", lambda v, n: p.smooth(n[:, 2], 0.0, 0.6), 0.7)
    p.region("tail_tip", "dark")
    p.region_where("tail", "dark", lambda v, n: p.smooth(0.42 - v[:, 2], 0.0, 0.06))
    # Grizzled: light and dark guard hairs mixed through the coat.
    p.speckle(0.22)
    return p.colors


def make():
    c = quadruped("wolf_pack", J, R, paint=paint, tiles_long=1.45)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.075, 0.555, 0.835), (0.065, 0.075, 0.07), "cheek", "head", blend=0.06, yaw=side * 0.3))
    # The ruff: a thick collar of fur round the neck.
    c.shapes.append(ellipsoid((0, 0.43, 0.76), (0.16, 0.13, 0.16), "neck", "neck", blend=0.08, pitch=0.5))
    tail_mid, tail_end = np.asarray(J["tail_mid"]), np.asarray(J["tail_end"])
    c.shapes.append(ellipsoid((tail_mid + tail_end) / 2, (0.075, 0.17, 0.07), "tail", "tail2", blend=0.07,
                              pitch=np.arctan2(tail_mid[2] - tail_end[2], tail_mid[1] - tail_end[1])))
    add_face(c, eye_dir=(-0.62, 0.72, 0.32), eye_radius=0.013, eye_sink=0.008, nose_radius=0.02, nose_sink=0.008,
             iris="#c9a032", pupil="round")
    c.fur = {"variation": 0.18, "sheen": 0.3, "bump": 0.3, "length": 0.06, "density": 22000, "hair_gamma": 2.0}
    c.motion = {"gait": "trot", "attack": "bite", "stride": 1.05}
    return c
