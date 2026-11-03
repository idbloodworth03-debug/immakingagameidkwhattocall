"""Electric eel: a long, round, eel-like fish (really a knifefish) with a
broad flat head, a wide mouth, tiny eyes, dark gray-brown skin and an
orange-yellow throat and chin. It slithers along the ground.

Real size: about 2 m long.
Built on the snake's body plan, head held low.
"""
import numpy as np

from anatomy import add_face
from bodies import snake
from paint import Painter
from sdf import ellipsoid

J = {
    "tail_end": (0.1, -0.38, 0.02), "tail_mid": (-0.13, -0.3, 0.03), "tail_base": (0.11, -0.17, 0.035),
    "pelvis": (-0.09, -0.04, 0.04), "spine_mid": (0.06, 0.07, 0.042), "withers": (-0.03, 0.15, 0.045),
    "neck_base": (0, 0.2, 0.05), "head_base": (0, 0.24, 0.055), "skull": (0, 0.27, 0.06),
    "snout_tip": (0, 0.33, 0.05), "jaw_hinge": (0, 0.27, 0.04), "chin": (0, 0.32, 0.035),
}
R = {
    "body": (0.01, 0.02, 0.03, 0.036, 0.04, 0.04, 0.038, 0.036),
    "skull": (0.045, 0.045, 0.03), "snout_root": (0, 0.03, -0.004), "snout": (0.032, 0.02), "jaw": (0.024, 0.016),
    "blend": 0.02,
}
COLORS = {"gray": "#4a4740", "dark": "#2f2d29", "orange": "#e48a2e", "spot": "#6a6658"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    p.fill("gray")
    p.blend("dark", p.smooth(n[:, 2], 0.4, 0.4) * 0.5)
    p.blend("orange", (p.mesh.region_weight("jaw") + p.mesh.region_weight("snout") * p.smooth(-n[:, 2], 0.0, 0.4)
                       + p.mesh.region_weight("torso") * p.smooth(-n[:, 2], 0.3, 0.4) * 0.6))
    p.spots("spot", cell=0.03, radius=0.006, mask=p.smooth(n[:, 2], 0.0, 0.4) * 0.5, seed=3)
    return p.colors


def make():
    c = snake("electric_eel", J, R, paint=paint, tiles_long=1.5)
    c.voxel = 0.0028
    add_face(c, eye_dir=(-0.75, 0.55, 0.35), eye_radius=0.006, eye_sink=0.002, nose_radius=0, iris="#2a2018", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.45, "bump": 0.05, "roughness": 0.35, "specular": 0.45}
    c.motion = {"body": "serpent", "attack": "bite", "gape": 0.6, "cycle_tiles": 1.0}
    return c
