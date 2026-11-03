"""Banded archerfish, flopping along on land: a deep, flat-sided silvery
body with black bands, a pointed snout for its famous water shots, big
eyes and yellowish fins with dark edges.

Real size: about 20 cm long.
"""
import numpy as np

from anatomy import add_face
from bodies import fish
from paint import Painter

J = {
    "snout_tip": (0, 0.165, 0.072),
    "skull": (0, 0.11, 0.088),
    "head_base": (0, 0.085, 0.082),
    "withers": (0, 0.05, 0.08),
    "spine_mid": (0, -0.01, 0.075),
    "pelvis": (0, -0.06, 0.072),
    "tail_base": (0, -0.08, 0.072),
    "tail_mid": (0, -0.12, 0.072),
    "tail_end": (0, -0.15, 0.072),
    "caudal_a": (0, -0.22, 0.125),
    "caudal_b": (0, -0.22, 0.022),
    "jaw_hinge": (0, 0.12, 0.062),
    "chin": (0, 0.162, 0.06),
    "dorsal_front": (0, -0.02, 0.135),
    "dorsal_back": (0, -0.1, 0.112),
    "dorsal_tip": (0, -0.09, 0.165),
    "anal_front": (0, -0.03, 0.025),
    "anal_back": (0, -0.1, 0.04),
    "anal_tip": (0, -0.11, 0.008),
    "pect_base": (-0.03, 0.06, 0.06),
    "pect_back": (-0.03, 0.03, 0.05),
    "pect_tip": (-0.08, 0.02, 0.04),
}

R = {
    "body": (0.034, 0.085, 0.074), "front": (0.033, 0.05, 0.064), "belly_drop": -0.004,
    "skull": (0.03, 0.04, 0.046), "snout_root": (0, 0.03, -0.012), "snout": (0.022, 0.008), "snout_blend": 0.015,
    "jaw": (0.014, 0.006), "tail": (0.022, 0.014, 0.01), "blend": 0.03,
    "fin_thick": 0.003, "fin_round": 0.012, "fin_blend": 0.006, "fin_root": 0.016,
}

COLORS = {
    "silver": "#dfe3e4",
    "back": "#a5ad72",
    "band": "#1e1e1e",
    "fin": "#d9c56a",
    "edge": "#2a2a24",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("silver")
    p.blend("back", p.smooth(v[:, 2] - 0.11, 0.0, 0.02) * 0.8)
    body = p.mesh.region_weight("torso") + p.mesh.region_weight("tail") + p.mesh.region_weight("head") * 0.6
    # Four black bands down the sides, the first through the eye.
    p.stripes("band", lambda q: q[:, 1] - 0.012, frequency=12.0, width=0.24, mask=body * p.smooth(v[:, 2] - 0.05, 0.0, 0.02))
    fins = p.mesh.region_weight("fin")
    p.blend("fin", fins)
    p.blend("edge", fins * p.smooth(np.abs(v[:, 2] - 0.072) - 0.06, 0.0, 0.01))
    p.speckle(0.04)
    return p.colors


def make():
    c = fish("archerfish", J, R, paint=paint, tiles_long=0.95)
    c.voxel = 0.0025
    add_face(c, eye_dir=(-0.8, 0.5, 0.3), eye_radius=0.0065, eye_sink=0.003, nose_radius=0, iris="#d8b23a", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.45, "bump": 0.0, "roughness": 0.35, "specular": 0.5}
    c.motion = {"body": "fish", "attack": "spit", "hop": 0.28, "gape": 0.5, "cycle_tiles": 0.8}
    return c
