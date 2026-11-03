"""Jackalope: the antlered rabbit of American folk tales: a brown cottontail
with tall ears, a fluffy white tail, a white belly, and a little pair of
branching antlers. It flings antler darts.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from gray_squirrel import J as SJ, R as SR
from paint import Painter

J = dict(SJ)
sk = np.asarray(J["skull"], float)
J["ear_tip"] = tuple(np.asarray(J["ear_base"], float) + np.array([-0.006, -0.02, 0.042]))
J["tail_mid"] = tuple(np.asarray(J["tail_base"], float) + np.array([0, -0.025, 0.01]))
J["tail_end"] = tuple(np.asarray(J["tail_base"], float) + np.array([0, -0.04, 0.02]))
R = dict(SR, ear_width=SR["ear_width"] * 0.75, ear_round=SR["ear_width"] * 0.35, tail=(0.03, 0.035, 0.03, 0.015))
COLORS = {"brown": "#a9825c", "white": "#f6f2ea", "dark": "#6b4e34"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("brown")
    p.blend("white", p.smooth(-p.n[:, 2], 0.2, 0.4) * 0.9)
    p.region("tail", "white")
    p.region("tail_tip", "white")
    p.blend("dark", p.mesh.region_weight("ear") * 0.4)
    return p.colors


def make():
    c = quadruped("jackalope", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.0018
    r = R["skull"][0]
    for side in (1, -1):
        base = sk + np.array([side * r * 0.5, -r * 0.1, r * 0.7])
        top = base + np.array([side * r * 0.4, -r * 0.2, r * 1.6])
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(top), radius=r * 0.16, tip_radius=r * 0.05, color="#e8d2a8"))
        fork = base + (top - base) * 0.5
        c.extras.append(Extra("cone", "horn", "head", center=tuple(fork), tip=tuple(fork + np.array([side * r * 0.5, r * 0.3, r * 0.5])),
                              radius=r * 0.1, tip_radius=r * 0.04, color="#e8d2a8"))
    add_face(c, eye_dir=(-0.75, 0.5, 0.3), eye_radius=0.0055, eye_sink=0.004, nose_radius=0.004, iris="#2a1a10", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.3, "bump": 0.15, "roughness": 0.6}
    c.motion = {"gait": "gallop", "attack": "stomp", "rear": 0.4, "stride": 1.2}
    return c
