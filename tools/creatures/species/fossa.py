"""Fossa: Madagascar's top predator, a sleek, cat-like animal with a long
low body, short legs, a small rounded head with big round ears and an
extremely long thick tail. Short, smooth reddish-brown coat, paler below.

Real size: about 35 cm at the shoulder, 1.5 m including the tail.
Built from the leopard's skeleton, lower and longer.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import amur_leopard as L
from derive import scaled, scaled_r

K = 0.55
J = dict(L.J)
J.update({"tail_mid": (0, -1.15, 0.6), "tail_end": (0, -1.6, 0.55), "ear_base": (-0.085, 0.77, 1.02), "ear_tip": (-0.11, 0.75, 1.12),
          "snout_tip": (0, 1.0, 0.86)})
R = dict(L.R)
R.update({"tail": (0.06, 0.055, 0.05, 0.04), "ear_width": 0.085, "ear_round": 0.035,
          "upper_arm": (0.12, 0.08), "forearm": (0.07, 0.055), "upper_leg": (0.14, 0.08), "shin": (0.07, 0.05)})

COLORS = {"red": "#8c5a38", "light": "#c49a74", "dark": "#5a3a26"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("red")
    p.top_darken("dark", start=0.3, strength=0.4)
    p.region_underside("torso", "light", below=-0.35, soft=0.3)
    p.region("jaw", "light", 0.8)
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("fossa", scaled(J, K), scaled_r(R, K), paint=paint, tiles_long=1.8)
    c.voxel = 0.004
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.1 * K, 0.8 * K, 0.86 * K), (0.075 * K, 0.08 * K, 0.075 * K), "cheek", "head", blend=0.05 * K))
    add_face(c, eye_dir=(-0.48, 0.82, 0.32), eye_radius=0.017 * K, eye_sink=0.009 * K, nose_radius=0.022 * K, nose_sink=0.01 * K,
             iris="#b08a3a", pupil="round")
    c.extras[-1].color = "#5a3a30"
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.35, "bump": 0.2, "roughness": 0.55}
    c.motion = {"gait": "gallop", "attack": "pounce_bite", "stride": 1.1}
    return c
