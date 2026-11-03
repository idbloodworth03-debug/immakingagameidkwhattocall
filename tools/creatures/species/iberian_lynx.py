"""Iberian lynx: a long-legged spotted wildcat with tall black ear tufts, a
flared "beard" of fur on its cheeks, a short black-tipped bobtail and a
tawny coat with bold dark spots.

Real size: about 65 cm at the shoulder.
Built from the leopard's skeleton.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import amur_leopard as L
from derive import scaled, scaled_r

K = 0.62
J = dict(L.J)
J["tail_mid"] = (0, -0.82, 0.82)
J["tail_end"] = (0, -0.9, 0.74)
J["ear_tip"] = (-0.112, 0.75, 1.1)
for k in ("elbow", "wrist", "front_toe", "knee", "hock", "hind_toe"):
    x, y, z = J[k]
    J[k] = (x, y, z)
J = {k: (v[0], v[1], v[2] + (0.08 if k not in ("wrist", "front_toe", "hock", "hind_toe", "elbow", "knee") else 0.0)) for k, v in J.items()}
R = dict(L.R)
R.update({"tail": (0.055, 0.05, 0.048, 0.04), "ear_width": 0.08, "ear_round": 0.01})

COLORS = {"tawny": "#c99a5e", "spot": "#2a1d14", "white": "#efe6d6", "dark": "#1c1512"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("tawny")
    p.region_underside("torso", "white", below=-0.35, soft=0.3)
    p.region("jaw", "white")
    p.region("ruff", "white", 0.6)
    body = np.clip(1 - Wt("head") - Wt("snout") - Wt("jaw") - Wt("ear") - Wt("ruff"), 0, 1)
    p.spots("spot", cell=0.08, radius=0.024, mask=body, seed=41)
    p.region("ear", "dark", 0.6)
    p.region("tail_tip", "dark")
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("iberian_lynx", scaled(J, K), scaled_r(R, K), paint=paint, tiles_long=1.7)
    c.voxel = 0.0045
    # The cheek ruff: a flared beard of fur on each side of the face.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.12 * K, 0.78 * K, 0.88 * K), (0.075 * K, 0.06 * K, 0.08 * K), "ruff", "head", blend=0.04 * K))
        # Black ear tufts.
        tip = np.asarray(J["ear_tip"], float) * (-side, 1, 1) * K
        c.extras.append(Extra("cone", "claw", "ear" + (".R" if side > 0 else ".L"), center=tuple(tip), tip=tuple(tip + (0, -0.005, 0.04 * K)),
                              radius=0.005, tip_radius=0.0015, color="#1c1512"))
    add_face(c, eye_dir=(-0.48, 0.82, 0.32), eye_radius=0.016 * K, eye_sink=0.009 * K, nose_radius=0.022 * K, nose_sink=0.01 * K,
             iris="#c9a43a", pupil="round")
    c.extras[-1].color = "#c98a7a"
    c.fur = {"strands": False, "variation": 0.06, "sheen": 0.3, "bump": 0.25, "roughness": 0.6}
    c.motion = {"gait": "trot", "attack": "pounce_bite", "stride": 1.1}
    c.palette = {"eye_line_size": 1.5}
    return c
