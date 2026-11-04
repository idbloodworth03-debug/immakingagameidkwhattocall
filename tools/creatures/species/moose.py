"""Moose: the tallest deer, with long legs, a humped shoulder, a long
drooping muzzle with a big soft nose, a dangling "bell" under the throat,
big ears and wide flat palmate antlers. Dark brown with pale gray-tan legs.

Real size: about 1.9 m at the shoulder.
Built from the horse's skeleton (the Pegasus card's).
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid, plate
from pegasus import J as HJ, R as HR

J = dict(HJ)
J.update({"withers": (0, 0.25, 0.96), "neck_base": (0, 0.36, 0.92), "head_base": (0, 0.5, 0.98), "skull": (0, 0.56, 1.0),
          "snout_tip": (0, 0.8, 0.86), "jaw_hinge": (0, 0.56, 0.92), "chin": (0, 0.75, 0.82),
          "ear_base": (-0.07, 0.52, 1.07), "ear_tip": (-0.14, 0.48, 1.12),
          "tail_mid": (0, -0.52, 0.8), "tail_end": (0, -0.54, 0.74)})
R = dict(HR)
R.update({"chest": (0.2, 0.22, 0.24), "neck_base": 0.15, "neck_top": 0.1, "skull": (0.1, 0.12, 0.1),
          "snout_base": 0.085, "snout_end": 0.08, "ear_width": 0.075, "ear_round": 0.02,
          "tail": (0.04, 0.035, 0.025)})

COLORS = {"brown": "#3e2b1f", "dark": "#271a12", "legs": "#a99379", "antler": "#dcc6a2", "nose": "#2c201a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("brown")
    p.blend("dark", p.smooth(v[:, 2] - 0.9, 0.0, 0.1) * p.smooth(v[:, 1] - 0.15, 0.0, 0.1) * 0.5)
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "legs", 0.9)
    p.region_where("snout", "nose", lambda v, n: p.smooth(v[:, 1] - 0.74, 0.0, 0.03), 0.7)
    p.region("antler", "antler")
    p.region("bell", "dark", 0.6)
    p.speckle(0.12)
    return p.colors


def make():
    c = quadruped("moose", J, R, paint=paint, tiles_long=2.7)
    c.voxel = 0.01
    # Shoulder hump, the big soft nose and the bell under the throat.
    c.shapes.append(ellipsoid((0, 0.22, 1.02), (0.12, 0.2, 0.12), "torso", "chest", blend=0.1))
    c.shapes.append(ellipsoid((0, 0.77, 0.87), (0.075, 0.07, 0.07), "snout", "head", blend=0.05))
    c.shapes.append(ellipsoid((0, 0.56, 0.8), (0.03, 0.04, 0.09), "bell", "head", blend=0.04))
    # Wide palmate antlers with tines round the edge.
    for side in (1, -1):
        base = np.array([side * 0.07, 0.5, 1.1])
        a, b = base + (side * 0.24, -0.1, 0.12), base + (side * 0.2, 0.08, 0.2)
        c.shapes.append(plate(base, a, b, 0.018, 0.015, "antler", "head", blend=0.02))
        c.shapes.append(plate(base + (side * 0.08, 0, 0.04), a + (side * 0.06, 0.02, 0.0), b + (side * 0.06, 0.0, 0.02), 0.018, 0.015,
                              "antler", "head", blend=0.02))
        for u in np.linspace(0.0, 1.0, 5):
            at = a + (b - a) * u + (side * 0.06, 0.0, 0.0)
            c.extras.append(Extra("cone", "horn", "head", center=tuple(at), tip=tuple(at + (side * 0.06, -0.01, 0.07)),
                                  radius=0.016, tip_radius=0.004, color="#dcc6a2"))
    add_face(c, eye_dir=(-0.75, 0.5, 0.35), eye_radius=0.017, eye_sink=0.008, nose_radius=0.0, iris="#2b1a10", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.25, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "charge", "stride": 0.95, "charge_reach": 0.35}
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "stomp"
    return c
