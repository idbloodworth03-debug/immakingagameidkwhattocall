"""West Indian manatee: a big, gentle, wrinkly gray "sea cow" with a round
body, a whiskery square snout, tiny eyes, two paddle flippers and a broad
round paddle tail. On land it belly-flops along.

Real size: about 3 m long.
Built on the dolphin's body plan, with a round paddle for a tail.
"""
import numpy as np

from anatomy import add_face
from bodies import fish
from paint import Painter
from sdf import ellipsoid

J = {
    "snout_tip": (0, 0.6, 0.16), "skull": (0, 0.44, 0.2), "head_base": (0, 0.34, 0.2), "withers": (0, 0.18, 0.2),
    "spine_mid": (0, -0.04, 0.2), "pelvis": (0, -0.26, 0.17), "tail_base": (0, -0.34, 0.16), "tail_mid": (0, -0.46, 0.14),
    "tail_end": (0, -0.56, 0.13), "caudal_a": (-0.12, -0.66, 0.13), "caudal_b": (0.12, -0.66, 0.13),
    "jaw_hinge": (0, 0.46, 0.13), "chin": (0, 0.58, 0.11),
    "dorsal_front": (0, 0.0, 0.3), "dorsal_back": (0, -0.08, 0.3), "dorsal_tip": (0, -0.05, 0.305),
    "pect_base": (-0.13, 0.22, 0.08), "pect_back": (-0.12, 0.12, 0.07), "pect_tip": (-0.26, 0.16, 0.02),
}
R = {
    "body": (0.2, 0.3, 0.16), "front": (0.18, 0.18, 0.16),
    "skull": (0.11, 0.12, 0.1), "snout_root": (0, 0.06, -0.03), "snout": (0.085, 0.07), "snout_blend": 0.05,
    "jaw": (0.05, 0.04), "tail": (0.12, 0.08, 0.05), "blend": 0.09,
    "fin_thick": 0.014, "fin_round": 0.03, "fin_blend": 0.02, "fin_root": 0.04,
}
COLORS = {"gray": "#8c8a86", "dark": "#6a6864", "belly": "#a9a49c", "whisker": "#d9d2c4"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("gray")
    p.blend("dark", p.smooth(n[:, 2], 0.4, 0.4) * 0.5)
    p.blend("belly", p.smooth(-n[:, 2], 0.2, 0.4) * 0.6)
    p.stripes("dark", lambda q: q[:, 1], frequency=30.0, width=0.12, mask=p.mesh.region_weight("torso") * 0.4)
    p.region("paddle", "gray")
    p.region_where("snout", "whisker", lambda v, n: p.smooth(v[:, 1] - 0.58, 0.0, 0.03), 0.5)
    p.speckle(0.12)
    return p.colors


def make():
    c = fish("west_indian_manatee", J, R, fluke=True, paint=paint, tiles_long=2.3)
    c.voxel = 0.008
    # The broad round paddle tail.
    c.shapes.append(ellipsoid((0, -0.66, 0.13), (0.17, 0.12, 0.022), "paddle", "tail3", blend=0.04))
    add_face(c, eye_dir=(-0.8, 0.45, 0.3), eye_radius=0.011, eye_sink=0.005, nose_radius=0, iris="#1e1612", pupil="round")
    c.cartoon = {"head": 1.4, "muzzle": 0.9}
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.25, "bump": 0.35, "roughness": 0.6}
    c.motion = {"body": "cetacean", "attack": "snap", "gape": 0.3, "cycle_tiles": 1.2}
    return c
