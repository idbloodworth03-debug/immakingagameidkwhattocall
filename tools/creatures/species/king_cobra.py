"""King cobra: the longest venomous snake, rearing up with its hood spread.
Olive-brown with pale yellow bands, a cream throat and hood front, a broad
head and big round eyes. It spits venom.

Real size: up to about 4 m long.
"""
import numpy as np

from anatomy import add_face
from bodies import snake
from paint import Painter

J = {
    "tail_end": (0.12, -0.42, 0.02), "tail_mid": (-0.14, -0.32, 0.03), "tail_base": (0.1, -0.18, 0.035),
    "pelvis": (-0.08, -0.05, 0.04), "spine_mid": (0.04, 0.08, 0.045), "withers": (0, 0.16, 0.12),
    "neck_base": (0, 0.17, 0.3), "head_base": (0, 0.19, 0.4), "skull": (0, 0.22, 0.415),
    "snout_tip": (0, 0.29, 0.405), "jaw_hinge": (0, 0.225, 0.395), "chin": (0, 0.28, 0.39),
}
R = {
    "body": (0.012, 0.022, 0.03, 0.036, 0.038, 0.036, 0.032, 0.028), "hood": (0.12, 0.026, 0.1),
    "skull": (0.034, 0.04, 0.026), "snout_root": (0, 0.03, -0.004), "snout": (0.022, 0.012), "jaw": (0.016, 0.01),
    "blend": 0.02,
}
COLORS = {"olive": "#6b6a3a", "band": "#d9cf8a", "cream": "#ecdfae", "dark": "#3c3a22"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("olive")
    body = p.mesh.region_weight("torso") + p.mesh.region_weight("tail")
    # Pale bands around the body, measured along its curve by height and length.
    p.stripes("band", lambda q: q[:, 1] + q[:, 2] * 0.6, frequency=14.0, width=0.14, mask=body * 0.8)
    hood = p.mesh.region_weight("hood")
    p.blend("cream", hood * p.smooth(n[:, 1], 0.0, 0.4))
    p.blend("cream", p.mesh.region_weight("jaw"))
    p.blend("cream", p.smooth(-n[:, 2], 0.3, 0.4) * body * 0.7)
    p.blend("dark", p.mesh.region_weight("head") * p.smooth(n[:, 2], 0.5, 0.3) * 0.4)
    return p.colors


def make():
    c = snake("king_cobra", J, R, paint=paint, tiles_long=1.8)
    c.voxel = 0.003
    add_face(c, eye_dir=(-0.7, 0.6, 0.3), eye_radius=0.008, eye_sink=0.003, nose_radius=0, iris="#d8a020", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.35, "bump": 0.1, "roughness": 0.45, "specular": 0.4}
    c.motion = {"body": "serpent", "attack": "spit", "gape": 0.5, "cycle_tiles": 1.0}
    return c
