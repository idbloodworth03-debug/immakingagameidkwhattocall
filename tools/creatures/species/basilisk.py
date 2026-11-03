"""Basilisk, the king of serpents, made regal rather than deadly: an
emerald-green snake holding its head up, with a golden crown of little
points, a red crest behind it and a pale golden belly.

Mythical. Built on the cobra's body plan, without the hood.
"""
import numpy as np

from anatomy import Extra, add_face
from bodies import snake
from paint import Painter
from sdf import plate
import king_cobra as KC

J = dict(KC.J)
R = dict(KC.R)
R.update({"hood": 0})

COLORS = {"green": "#3f9a52", "dark": "#2a6a3a", "belly": "#f0dc8a", "crest": "#d8433a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    Wt = p.mesh.region_weight
    p.fill("green")
    p.stripes("dark", lambda q: q[:, 1] + q[:, 2] * 0.6, frequency=14.0, width=0.12, mask=(Wt("torso") + Wt("tail")) * 0.6)
    p.blend("belly", p.smooth(-n[:, 2], 0.3, 0.4) * (Wt("torso") + Wt("tail")) * 0.8)
    p.blend("belly", Wt("jaw"))
    p.region("crest", "crest")
    return p.colors


def make():
    c = snake("basilisk", J, R, paint=paint, tiles_long=1.8)
    c.voxel = 0.003
    sk = np.asarray(J["skull"], float)
    # A golden crown: a ring of little points on top of the head.
    for a in np.linspace(0, 2 * np.pi, 7, endpoint=False):
        base = sk + (np.sin(a) * 0.022, np.cos(a) * 0.026 - 0.005, 0.022)
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(base + (0, 0, 0.022)),
                              radius=0.007, tip_radius=0.0015, color="#f2c13a"))
    c.shapes.append(plate(sk + (0, -0.02, 0.02), sk + (0, -0.07, 0.0), sk + (0, -0.06, 0.05), 0.004, 0.004, "crest", "head", blend=0.006))
    add_face(c, eye_dir=(-0.7, 0.6, 0.3), eye_radius=0.008, eye_sink=0.003, nose_radius=0, iris="#e8b020", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.4, "bump": 0.1, "roughness": 0.4, "specular": 0.4}
    c.motion = {"body": "serpent", "attack": "bite", "gape": 0.5, "cycle_tiles": 1.0}
    return c
