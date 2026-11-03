"""Walrus: a huge, wrinkly, cinnamon-pink seal with a broad whiskery
muzzle, two long ivory tusks, tiny eyes, no ear flaps and big flippers.
On land it galumphs along on its belly.

Real size: about 3 m long.
Built from the harbor seal, bigger and heavier.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import harbor_seal as HS

J = dict(HS.J)
J.update({"neck_base": (0, 0.42, 0.27), "head_base": (0, 0.55, 0.32), "skull": (0, 0.61, 0.34), "snout_tip": (0, 0.73, 0.29),
          "jaw_hinge": (0, 0.61, 0.28), "chin": (0, 0.7, 0.25), "ear_base": (-0.085, 0.6, 0.39), "ear_tip": (-0.087, 0.598, 0.396)})
R = dict(HS.R)
R.update({"rump": (0.17, 0.24, 0.14), "belly": (0.27, 0.4, 0.21), "chest": (0.26, 0.24, 0.22),
          "neck_base": 0.22, "neck_top": 0.18, "skull": (0.14, 0.13, 0.12), "snout_base": 0.1, "snout_end": 0.09,
          "front_paw": (0.04, 0.014), "hind_paw": (0.035, 0.014)})

COLORS = {"skin": "#a8705a", "pink": "#d19a84", "dark": "#6e4a3c", "whisker": "#efe2cc"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("skin")
    p.blend("pink", p.smooth(-n[:, 2], 0.0, 0.4) * 0.6)
    # Wrinkly folds round the neck and shoulders.
    p.stripes("dark", lambda q: q[:, 1], frequency=28.0, width=0.18, mask=p.mesh.region_weight("neck") + p.mesh.region_weight("torso") * p.smooth(v[:, 1] - 0.15, 0.0, 0.1), strength=0.35)
    p.region("front_paw", "dark", 0.5)
    p.region("hind_paw", "dark", 0.5)
    p.region_where("snout", "whisker", lambda v, n: p.smooth(v[:, 1] - 0.68, 0.0, 0.03) * p.smooth(0.31 - v[:, 2], 0.0, 0.02), 0.5)
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("walrus", J, R, paint=paint, tiles_long=2.4)
    c.voxel = 0.006
    # The big whisker pad and the tusks.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.06, 0.71, 0.28), (0.07, 0.055, 0.055), "snout", "head", blend=0.03))
        c.extras.append(Extra("cone", "tusk", "head", center=(side * 0.045, 0.73, 0.25), tip=(side * 0.06, 0.79, 0.03),
                              radius=0.022, tip_radius=0.007, color="#f3ead8"))
    HS.flippers(c, J, front=0.065, hind=0.085)
    add_face(c, eye_dir=(-0.6, 0.7, 0.4), eye_radius=0.012, eye_sink=0.006, nose_radius=0.0, iris="#1a110c", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.3, "bump": 0.3, "roughness": 0.6}
    c.motion = {"body": "pinniped", "attack": "bite", "gape": 0.4, "cycle_tiles": 0.7}
    return c
