"""Jaguar: the stockiest big cat, with a broad head, powerful jaws, short
thick legs and a shorter tail than a leopard's. Golden-orange coat with
big black rosettes, each with a dot or two inside, a white belly and
throat, and solid spots on the head and legs.

Real size: about 70 cm at the shoulder, 1.7 m head and body.
Built from the leopard's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from sdf import ellipsoid
import amur_leopard as L

K = 0.78
J = dict(L.J)
J["tail_mid"] = (0, -0.98, 0.58)
J["tail_end"] = (0, -1.16, 0.4)
R = dict(L.R)
R.update({"skull": (0.15, 0.145, 0.135), "snout_base": 0.1, "snout_end": 0.075, "jaw_base": 0.07, "jaw_end": 0.045,
          "neck_base": 0.22, "chest": (0.24, 0.33, 0.29), "upper_arm": (0.145, 0.1), "forearm": (0.09, 0.07),
          "front_paw": (0.075, 0.07), "shin": (0.085, 0.064), "hind_paw": (0.07, 0.068), "ear_width": 0.08})

COLORS = {
    "cream": "#dca552",
    "gold": "#c27a2c",
    "white": "#f3ebdc",
    "spot": "#17110e",
    "center": "#9a5a1e",
}


def paint(mesh, creature):
    old = dict(L.COLORS)
    L.COLORS.update(COLORS)
    try:
        return L.paint(mesh, creature)
    finally:
        L.COLORS.clear()
        L.COLORS.update(old)


def make():
    c = quadruped("jaguar", L._scaled(J, K), L._scaled_r(R, K), paint=paint, tiles_long=2.0)
    c.voxel = 0.005
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.11 * K, 0.8 * K, 0.86 * K), (0.095 * K, 0.1 * K, 0.09 * K), "cheek", "head",
                                  blend=0.06 * K, yaw=side * 0.3))
    add_face(c, eye_dir=(-0.48, 0.82, 0.32), eye_radius=0.016 * K, eye_sink=0.009 * K, nose_radius=0.026 * K, nose_sink=0.01 * K,
             iris="#d9a030", pupil="round")
    c.extras[-1].color = "#b9786a"
    c.fur = {"variation": 0.08, "sheen": 0.3, "bump": 0.25, "length": 0.035, "density": 20000, "hair_gamma": 1.95,
             "lengths": {"cheek": 1.1, "tail": 1.0, "neck": 1.0, "torso": 0.9}}
    c.motion = {"gait": "walk", "attack": "pounce_bite", "stride": 1.05, "gape": 0.8}
    c.palette = {"eye_line_size": 1.5}
    return c
