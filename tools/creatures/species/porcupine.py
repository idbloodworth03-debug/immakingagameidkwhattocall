"""North American porcupine: a round, waddling rodent covered in long cream
quills with dark tips, over dark brown fur, with a small blunt face and
short legs. It shoots a volley of quills.

Real size: about 75 cm long.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from raccoon import J as RJ, R as RR

J = dict(RJ, tail_mid=(0, -0.36, 0.25), tail_end=(0, -0.42, 0.2))
R = dict(RR, belly=(0.12, 0.17, 0.11), rump=(0.12, 0.12, 0.11), tail=(0.05, 0.05, 0.035, 0.02),
         ear_width=0.022, ear_round=0.008)
COLORS = {"brown": "#3d3027", "face": "#5a4838"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("brown")
    p.region("snout", "face")
    return p.colors


def make():
    c = quadruped("porcupine", J, R, paint=paint, tiles_long=1.1)
    c.voxel = 0.0035
    rng = np.random.default_rng(5)
    # Quills fanning out over the back and tail.
    for i in range(70):
        u = rng.uniform(-0.28, 0.18)
        a = rng.uniform(-1.2, 1.2)
        base = np.array([np.sin(a) * 0.1, u, 0.3 + np.cos(a) * 0.05])
        out = np.array([np.sin(a) * 0.5, -0.6, np.cos(a) * 0.8])
        out /= np.linalg.norm(out)
        tip = base + out * rng.uniform(0.1, 0.15)
        bone = "chest" if u > 0.05 else "hips"
        c.extras.append(Extra("cone", "horn", bone, center=tuple(base), tip=tuple(tip), radius=0.009, tip_radius=0.0015,
                              color="#efe6d2"))
    add_face(c, eye_dir=(-0.55, 0.78, 0.25), eye_radius=0.0085, eye_sink=0.005, nose_radius=0.008, iris="#1a100a", pupil="round")
    c.fur = {"strands": False, "variation": 0.15, "sheen": 0.2, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "stomp", "rear": 0.15, "stride": 0.9}
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "charge"
    return c
