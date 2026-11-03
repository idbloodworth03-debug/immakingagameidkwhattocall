"""Amazon pink river dolphin, sliding along on its belly: pink skin, a long
thin beak, a round bulging forehead, small eyes, big paddle flippers, a low
ridge for a dorsal fin and a broad fluke.

Real size: about 2.2 m long.
"""
import numpy as np

from anatomy import add_face
from bodies import fish
from paint import Painter

J = {
    "snout_tip": (0, 0.64, 0.12),
    "skull": (0, 0.4, 0.2),
    "head_base": (0, 0.3, 0.18),
    "withers": (0, 0.18, 0.17),
    "spine_mid": (0, -0.02, 0.16),
    "pelvis": (0, -0.2, 0.15),
    "tail_base": (0, -0.28, 0.15),
    "tail_mid": (0, -0.42, 0.14),
    "tail_end": (0, -0.55, 0.13),
    "caudal_a": (-0.19, -0.68, 0.13),
    "caudal_b": (0.19, -0.68, 0.13),
    "jaw_hinge": (0, 0.42, 0.12),
    "chin": (0, 0.61, 0.1),
    "dorsal_front": (0, 0.0, 0.27),
    "dorsal_back": (0, -0.18, 0.24),
    "dorsal_tip": (0, -0.14, 0.3),
    "pect_base": (-0.09, 0.2, 0.08),
    "pect_back": (-0.08, 0.06, 0.07),
    "pect_tip": (-0.27, 0.04, 0.03),
}

R = {
    "body": (0.14, 0.26, 0.13), "front": (0.14, 0.15, 0.13),
    "skull": (0.11, 0.12, 0.11), "snout_root": (0, 0.08, -0.06), "snout": (0.04, 0.022), "snout_blend": 0.04,
    "jaw": (0.03, 0.018), "tail": (0.09, 0.05, 0.025), "blend": 0.08,
    "fin_thick": 0.012, "fin_round": 0.04, "fin_blend": 0.02, "fin_root": 0.03,
}

COLORS = {
    "pink": "#f2a0b4",
    "top": "#cf8f9e",
    "belly": "#f9cdd6",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("pink")
    p.blend("top", p.smooth(n[:, 2], 0.4, 0.4) * 0.7)
    p.blend("belly", p.smooth(-n[:, 2], 0.2, 0.4) * 0.8)
    p.speckle(0.05)
    return p.colors


def make():
    c = fish("pink_river_dolphin", J, R, fluke=True, paint=paint, tiles_long=2.0)
    c.voxel = 0.008
    add_face(c, eye_dir=(-0.85, 0.35, 0.15), eye_radius=0.014, eye_sink=0.006, nose_radius=0, iris="#2a1a14", pupil="round")
    c.cartoon = {"head": 1.4, "muzzle": 0.82}
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.4, "bump": 0.0, "roughness": 0.4, "specular": 0.45}
    c.motion = {"body": "cetacean", "attack": "spit", "gape": 0.35, "cycle_tiles": 1.6}
    return c
