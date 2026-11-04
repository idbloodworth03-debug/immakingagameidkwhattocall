"""Striped skunk: black with a white stripe from the forehead that splits
into two down the back, and a huge bushy black-and-white tail held up. It
stamps its front feet, then sprays.

Real size: about 70 cm long including the tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from raccoon import J as RJ, R as RR

J = dict(RJ, tail_base=(0, -0.27, 0.33), tail_mid=(0, -0.33, 0.46), tail_end=(0, -0.25, 0.57),
         ear_tip=(-0.045, 0.255, 0.345))
R = dict(RR, tail=(0.05, 0.08, 0.075, 0.045), ear_width=0.036, ear_round=0.014)
COLORS = {"black": "#18171a", "white": "#f4f2ee"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("black")
    up = p.smooth(n[:, 2], 0.2, 0.4)
    # A thin white stripe up the forehead, then two down the back.
    head = p.mesh.region_weight("head") + p.mesh.region_weight("snout") * 0.6
    p.blend("white", head * p.smooth(0.008 - np.abs(v[:, 0]), 0.0, 0.004) * up)
    back = (p.mesh.region_weight("torso") + p.mesh.region_weight("neck")) * up
    p.blend("white", back * p.smooth(0.016 - np.abs(np.abs(v[:, 0]) - 0.03), 0.0, 0.01))
    tail = p.mesh.region_weight("tail") + p.mesh.region_weight("tail_tip")
    p.blend("white", tail * p.smooth(0.03 - np.abs(v[:, 0]), 0.0, 0.015))
    return p.colors


def make():
    c = quadruped("striped_skunk", J, R, paint=paint, tiles_long=1.2)
    c.voxel = 0.0035
    add_face(c, eye_dir=(-0.55, 0.78, 0.25), eye_radius=0.0085, eye_sink=0.005, nose_radius=0.0072, iris="#24170e", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "walk", "attack": "stomp", "rear": 0.2, "stride": 1.1}
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "handstand"
    return c
