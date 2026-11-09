"""Cerberus, made a lovable guard dog: a big dark-chocolate dog with three
happy puppy heads side by side, floppy ears, a red studded collar on each
neck and a waggy tail.

Mythical. Built from the gray wolf's skeleton, with two extra heads.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from cartoon import add_cartoon_eyes
from paint import Painter
from sdf import cone, ellipsoid
import wolf_pack as W

J = dict(W.J)
J.update({"ear_tip": (-0.12, 0.52, 0.86), "snout_tip": (0, 0.76, 0.83), "chin": (0, 0.72, 0.79)})
R = dict(W.R)
R.update({"skull": (0.11, 0.11, 0.1), "ear_width": 0.09, "ear_round": 0.04, "chest": (0.17, 0.25, 0.21), "neck_base": 0.18})

COLORS = {"brown": "#4a3328", "tan": "#a8754e", "dark": "#2c1f19", "collar": "#d23b3b", "stud": "#f3c64a"}

SIDE = [(-0.22, -0.05, -0.05), (0.22, -0.05, -0.05)]


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    Wt = p.mesh.region_weight
    p.fill("brown")
    p.blend("tan", p.smooth(-n[:, 2], 0.2, 0.4) * 0.7)
    for r in ("snout", "side_snout", "jaw"):
        p.region(r, "tan", 0.8)
    p.region("ear", "dark", 0.6)
    p.region("side_ear", "dark", 0.6)
    p.region("collar", "collar")
    p.region("tail_tip", "tan")
    return p.colors


def _after(c):
    for s in c.shapes:
        if s.region == "side_skull":
            add_cartoon_eyes(c, s.a, (-0.45, 0.84, 0.3), bone="neck", size=0.95)


def make():
    c = quadruped("cerberus", J, R, paint=paint, tiles_long=1.8)
    sk, tip = np.asarray(J["skull"], float), np.asarray(J["snout_tip"], float)
    # The two side heads, as big as the middle one (a design's R skull sizes
    # all three) and side_spread apart from it, each on a neck of its own.
    k = R["skull"][0] / 0.11
    spread = R.get("side_spread", SIDE[1][0])
    # (A design may shorten the side heads' snouts, R side_snout_k, and give
    # them bigger floppy ears, R side_ear_k.)
    sn = R.get("side_snout_k", 1.0)
    ek = k * R.get("side_ear_k", 1.0)
    for off in SIDE:
        o = np.asarray(off) * np.array([spread / SIDE[1][0], 1.0, 1.0])
        hs, ht = sk + o, tip + o + (np.sign(o[0]) * 0.03, 0, 0)
        st = hs + (ht - hs) * k ** 0.5 * sn
        c.shapes.append(ellipsoid(tuple(hs), R["skull"], "side_skull", "neck", blend=0.05))
        c.shapes.append(cone(hs + (0, 0.06 * k, -0.03 * k), st, 0.065 * k, 0.04 * k, "side_snout", "neck", blend=0.04))
        c.shapes.append(cone(np.asarray(J["neck_base"], float) + o * 0.3, hs, 0.12, 0.1, "torso", "neck", blend=0.06))
        for side in (1, -1):
            eb = hs + (side * 0.08 * k, -0.02, 0.06 * k)
            c.shapes.append(ellipsoid(tuple(eb + (side * 0.03 * ek / k, -0.01, -0.06 * ek)), (0.03 * ek, 0.05 * ek, 0.08 * ek), "side_ear", "neck",
                                      blend=0.02, roll=side * 0.3))
        c.extras.append(Extra("ellipsoid", "nose", "neck", center=tuple(st + (0, 0.02, 0.01)), radii=(0.025, 0.018, 0.018)))
    # Red studded collars.
    for x in (0.0, -0.2, 0.2):
        center = np.asarray(J["neck_base"], float) + (x, 0.06, 0.06)
        for a in np.linspace(0, 2 * np.pi, 12, endpoint=False):
            at = center + np.array([np.sin(a) * 0.11, np.cos(a) * 0.03, np.cos(a) * 0.11])
            c.shapes.append(ellipsoid(tuple(at), (0.03, 0.025, 0.03), "collar", "neck", blend=0.015))
    add_face(c, eye_dir=(-0.45, 0.84, 0.3), eye_radius=0.014, eye_sink=0.008, nose_radius=0.022, nose_sink=0.008,
             iris="#3a2414", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "trot", "attack": "bite", "stride": 1.05, "gape": 0.8}
    c.cartoon = {"head": 1.0}
    c.after_cartoon = _after
    return c
