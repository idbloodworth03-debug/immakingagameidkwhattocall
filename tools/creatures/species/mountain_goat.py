"""Mountain goat: a sure-footed white goat of the high cliffs, with a shaggy
coat, a beard, a hump at the shoulders, short black curved horns and black
hooves. It kicks stones down at its enemies.

Real size: about 1 m at the shoulder.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from pegasus import J as HJ, R as HR
from sdf import ellipsoid


def _scaled(d, k):
    return {key: tuple(np.asarray(v, float) * k) for key, v in d.items()}


K = 0.75
J = _scaled(HJ, K)
R = {key: (tuple(np.asarray(v) * K) if isinstance(v, tuple) else v * K) for key, v in HR.items()}
R["chest"] = tuple(np.asarray(R["chest"]) * np.array([1.1, 1.0, 1.15]))
COLORS = {"white": "#f2f0ea", "shade": "#ddd8cc", "black": "#1e1c1c"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("white")
    p.blend("shade", p.smooth(-p.n[:, 2], 0.3, 0.4) * 0.6)
    p.region("front_paw", "black")
    p.region("hind_paw", "black")
    return p.colors


def make():
    c = quadruped("mountain_goat", J, R, paint=paint, tiles_long=1.6)
    c.voxel = 0.008
    sk = np.asarray(J["skull"])
    # A shoulder hump, a beard and short black horns curving back.
    c.shapes.append(ellipsoid(tuple(np.asarray(J["withers"]) + (0, -0.03, 0.06)), (0.11, 0.14, 0.1), "torso", "chest", blend=0.08))
    c.shapes.append(ellipsoid(tuple(np.asarray(J["chin"]) + (0, -0.02, -0.05)), (0.035, 0.04, 0.06), "beard", "jaw", blend=0.03))
    for side in (1, -1):
        base = sk + np.array([side * 0.035, 0.0, 0.06])
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(base + np.array([side * 0.01, -0.07, 0.07])),
                              radius=0.016, tip_radius=0.003, color="#1e1c1c"))
    add_face(c, eye_dir=(-0.75, 0.5, 0.35), eye_radius=0.017, eye_sink=0.007, nose_radius=0, iris="#3a2a14", pupil="round")
    c.cartoon = {"head": 1.6}
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.2, "bump": 0.35, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "stomp", "rear": 0.3, "stride": 1.0}
    return c
