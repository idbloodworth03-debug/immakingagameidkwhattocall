"""Mongolian death worm, made a silly desert noodle: a fat, bright red worm
with soft pale rings, a round blunt head with big friendly eyes and a
little round mouth. It slithers through the sand.

Mythical. Built on the snake's body plan, held low.
"""
import numpy as np

from anatomy import add_face
from bodies import snake
from paint import Painter

J = {
    "tail_end": (0.09, -0.34, 0.03), "tail_mid": (-0.12, -0.28, 0.04), "tail_base": (0.1, -0.16, 0.045),
    "pelvis": (-0.08, -0.04, 0.05), "spine_mid": (0.06, 0.07, 0.052), "withers": (-0.02, 0.15, 0.06),
    "neck_base": (0, 0.2, 0.075), "head_base": (0, 0.24, 0.09), "skull": (0, 0.27, 0.1),
    "snout_tip": (0, 0.32, 0.095), "jaw_hinge": (0, 0.27, 0.085), "chin": (0, 0.31, 0.08),
}
R = {
    "body": (0.025, 0.035, 0.045, 0.05, 0.052, 0.052, 0.05, 0.048),
    "skull": (0.05, 0.05, 0.048), "snout_root": (0, 0.03, -0.004), "snout": (0.035, 0.03), "jaw": (0.02, 0.016),
    "blend": 0.02,
}
COLORS = {"red": "#d6463a", "ring": "#f19a86", "mouth": "#7a1e1e"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("red")
    p.stripes("ring", lambda q: q[:, 0] * 0.6 + q[:, 1] + q[:, 2] * 0.5, frequency=28.0, width=0.18,
              mask=Wt("torso") + Wt("tail"))
    return p.colors


def make():
    c = snake("mongolian_death_worm", J, R, paint=paint, tiles_long=1.5)
    c.voxel = 0.003
    add_face(c, eye_dir=(-0.6, 0.6, 0.5), eye_radius=0.008, eye_sink=0.003, nose_radius=0, iris="#1a1210", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.45, "bump": 0.05, "roughness": 0.4, "specular": 0.4}
    c.motion = {"body": "serpent", "attack": "bite", "gape": 0.6, "cycle_tiles": 1.0}
    c.palette = {"mouth": "#7a1e1e"}
    return c
