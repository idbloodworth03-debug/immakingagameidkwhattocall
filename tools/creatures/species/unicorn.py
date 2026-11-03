"""Unicorn: a white horse with a spiraling golden horn, a pastel rainbow mane
and tail, and golden hooves. It shoots a shining beam from its horn.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from pegasus import J, R
from sdf import ellipsoid

COLORS = {"white": "#f8f6f2", "shade": "#e6e0ea", "pink": "#f6a6c8", "blue": "#9ec8f5", "yellow": "#f8e08a",
          "lilac": "#c8a8f0", "gold": "#e8bf52"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("white")
    p.blend("shade", p.smooth(-p.n[:, 2], 0.3, 0.4) * 0.5)
    mane = p.mesh.region_weight("mane") + p.mesh.region_weight("tail") + p.mesh.region_weight("tail_tip")
    p.blend("pink", mane)
    for name, phase in (("blue", 0.0), ("yellow", 2.1), ("lilac", 4.2)):
        p.blend(name, mane * p.smooth(np.sin(v[:, 2] * 20.0 + v[:, 1] * 8.0 + phase), 0.5, 0.3))
    p.region("front_paw", "gold")
    p.region("hind_paw", "gold")
    return p.colors


def make():
    c = quadruped("unicorn", J, R, paint=paint, tiles_long=2.2)
    c.voxel = 0.01
    neck = np.asarray(J["neck_base"], float), np.asarray(J["head_base"], float)
    for u in np.linspace(0.0, 1.0, 7):
        at = neck[0] + (neck[1] - neck[0]) * u + np.array([0, -0.1, 0.09])
        c.shapes.append(ellipsoid(tuple(at), (0.06, 0.1, 0.09), "mane", "neck", blend=0.05, pitch=0.6))
    c.shapes.append(ellipsoid((0, 0.6, 1.26), (0.065, 0.07, 0.06), "mane", "head", blend=0.04))
    sk = np.asarray(J["skull"], float)
    base = sk + np.array([0, 0.05, 0.08])
    c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(base + np.array([0, 0.12, 0.2])),
                          radius=0.022, tip_radius=0.002, color="#f2cf5a"))
    add_face(c, eye_dir=(-0.75, 0.5, 0.35), eye_radius=0.02, eye_sink=0.008, nose_radius=0, iris="#8a4fd4", pupil="round")
    c.cartoon = {"head": 1.6}
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.1, "roughness": 0.55}
    c.motion = {"gait": "gallop", "attack": "charge", "charge_reach": 0.15, "stride": 1.0}
    c.palette = {"eye_line": "#4a3a55"}
    return c
