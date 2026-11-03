"""Aardvark: a pig-sized African burrower with a long tube-shaped snout and
a round pink nose disc, tall rabbit-like ears, an arched back, a thick
tapering tail and short legs with big digging claws. Sparse pinkish-gray
skin, darker on the legs.

Real size: about 60 cm at the shoulder, 1.3 m long.
Built from the wild boar's skeleton.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
import wild_boar as WB

J = dict(WB.J)
J.update({"withers": (0, 0.3, 0.8), "spine_mid": (0, -0.05, 0.9), "pelvis": (0, -0.45, 0.8),
          "snout_tip": (0, 1.0, 0.42), "chin": (0, 0.85, 0.44), "ear_base": (-0.06, 0.57, 0.8), "ear_tip": (-0.1, 0.52, 1.08),
          "tail_mid": (0, -0.85, 0.48), "tail_end": (0, -1.05, 0.2)})
R = dict(WB.R)
R.update({"chest": (0.18, 0.26, 0.22), "skull": (0.1, 0.12, 0.1), "snout_base": 0.06, "snout_end": 0.035,
          "ear_width": 0.075, "ear_round": 0.02, "tail": (0.09, 0.06, 0.035, 0.015), "neck_base": 0.17, "neck_top": 0.12})

COLORS = {"skin": "#b89a8c", "dark": "#6f5a52", "pink": "#e8a6a4", "claw": "#e8dccb"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("skin")
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "dark", 0.8)
    p.region_where("snout", "pink", lambda v, n: p.smooth(v[:, 1] - 0.97, 0.0, 0.02))
    p.region_where("ear", "pink", lambda v, n: p.smooth(n[:, 1], 0.3, 0.4), 0.6)
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("aardvark", J, R, paint=paint, tiles_long=1.7)
    for side, bone in ((1, "fl_foot.R"), (-1, "fl_foot.L")):
        toe = np.asarray(WB.J["front_toe"], float) * (-side, 1, 1)
        for k in (-1, 0, 1):
            b = (toe[0] + k * 0.018, toe[1], 0.02)
            c.extras.append(Extra("cone", "claw", bone, center=b, tip=(b[0], toe[1] + 0.05, 0.004), radius=0.01, tip_radius=0.002, color="#e8dccb"))
    add_face(c, eye_dir=(-0.65, 0.65, 0.4), eye_radius=0.011, eye_sink=0.006, nose_radius=0.03, nose_sink=0.015,
             iris="#2a160c", pupil="round")
    c.extras[-1].color = "#e39a9a"
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.2, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "trot", "attack": "swipe", "rear": 0.3, "stride": 0.95}
    return c
