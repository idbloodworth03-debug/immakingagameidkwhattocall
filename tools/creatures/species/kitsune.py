"""Kitsune: the magical fox of Japanese folklore, made cute: a white fox with
red-orange markings on its ears, face and tail tips, golden eyes and three
fluffy tails. It throws blue foxfire.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from red_fox import J as FJ, R as FR
from sdf import cone

J = dict(FJ)
R = dict(FR)
COLORS = {"white": "#f8f5ee", "red": "#e8572a", "gold": "#f2b13a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("white")
    p.region("ear", "red", 0.85)
    tail = p.mesh.region_weight("tail") + p.mesh.region_weight("tail_tip") + p.mesh.region_weight("tails")
    tip = np.asarray(J["tail_end"])
    p.blend("red", tail * p.smooth(np.linalg.norm(v - tip, axis=1) * -1 + 0.12, 0.0, 0.04))
    head = p.mesh.region_weight("head")
    p.blend("red", head * p.smooth(n[:, 2], 0.6, 0.2) * p.smooth(0.012 - np.abs(v[:, 0]), 0.0, 0.006))
    p.blend("gold", p.mesh.region_weight("snout") * p.smooth(n[:, 2], 0.7, 0.2) * 0.5)
    return p.colors


def make():
    c = quadruped("kitsune", J, R, paint=paint, tiles_long=1.7)
    c.voxel = 0.004
    base, mid, end = (np.asarray(J[k], float) for k in ("tail_base", "tail_mid", "tail_end"))
    r = R["tail"]
    for side in (1, -1):
        swing = np.array([side * 0.12, 0.0, 0.05])
        c.shapes.append(cone(base, mid + swing * 0.6, r[0], r[1], "tails", "tail1", blend=0.03))
        c.shapes.append(cone(mid + swing * 0.6, end + swing, r[1], r[2] * 1.1, "tails", "tail2", blend=0.03))
    add_face(c, eye_dir=(-0.6, 0.7, 0.35), eye_radius=0.01, eye_sink=0.005, nose_radius=0.008, iris="#e8a020", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.1, "roughness": 0.55}
    c.motion = {"gait": "trot", "attack": "spit", "gape": 0.5}
    return c
