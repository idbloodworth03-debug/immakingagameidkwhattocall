"""Humpback whale, made cartoon-small: a chunky whale with very long white
flippers, a knobbly head, a pleated white throat, a small hump of a dorsal
fin and a wide fluke with a white underside. Dark blue-gray on top. On
land it flops along on its belly with its flippers out.

Real size: about 15 m long.
Built on the dolphin's body plan.
"""
import numpy as np

from anatomy import add_face
from bodies import fish
from paint import Painter
from sdf import ellipsoid

J = {
    "snout_tip": (0, 0.66, 0.14), "skull": (0, 0.46, 0.2), "head_base": (0, 0.34, 0.2), "withers": (0, 0.18, 0.21),
    "spine_mid": (0, -0.04, 0.2), "pelvis": (0, -0.26, 0.17), "tail_base": (0, -0.34, 0.16), "tail_mid": (0, -0.48, 0.15),
    "tail_end": (0, -0.6, 0.14), "caudal_a": (-0.24, -0.72, 0.14), "caudal_b": (0.24, -0.72, 0.14),
    "jaw_hinge": (0, 0.44, 0.11), "chin": (0, 0.64, 0.1),
    "dorsal_front": (0, -0.14, 0.33), "dorsal_back": (0, -0.24, 0.29), "dorsal_tip": (0, -0.22, 0.36),
    "pect_base": (-0.13, 0.24, 0.07), "pect_back": (-0.12, 0.12, 0.06), "pect_tip": (-0.46, 0.04, 0.02),
}
R = {
    "body": (0.19, 0.32, 0.17), "front": (0.19, 0.2, 0.17),
    "skull": (0.13, 0.15, 0.1), "snout_root": (0, 0.1, -0.04), "snout": (0.08, 0.04), "snout_blend": 0.05,
    "jaw": (0.08, 0.04), "tail": (0.12, 0.07, 0.03), "blend": 0.09,
    "fin_thick": 0.014, "fin_round": 0.03, "fin_blend": 0.02, "fin_root": 0.04, "pect_thick": 1.1,
}
COLORS = {"blue": "#3d4a5a", "white": "#eef0f0", "knob": "#2e3946"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("blue")
    # The white pleated throat and belly, the white flippers.
    belly = p.smooth(-n[:, 2], 0.2, 0.4)
    p.blend("white", belly * 0.9)
    p.stripes("blue", lambda q: q[:, 0], frequency=40.0, width=0.18, mask=belly * Wt("jaw") * 0.6 + belly * Wt("torso") * p.smooth(v[:, 1] - 0.1, 0.0, 0.1) * 0.5)
    p.region("flipper", "white")
    p.region("knob", "knob")
    return p.colors


def make():
    c = fish("humpback_whale", J, R, fluke=True, paint=paint, tiles_long=2.6)
    c.voxel = 0.008
    # Knobbly bumps on the head.
    for y in (0.5, 0.56, 0.62):
        for x in (-0.04, 0.04):
            c.shapes.append(ellipsoid((x, y, 0.2 - (y - 0.5) * 0.4), (0.016, 0.016, 0.014), "knob", "head", blend=0.01))
    add_face(c, eye_dir=(-0.85, 0.35, 0.15), eye_radius=0.014, eye_sink=0.006, nose_radius=0, iris="#1a1414", pupil="round")
    c.cartoon = {"head": 1.3, "muzzle": 0.9}
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.4, "bump": 0.05, "roughness": 0.4, "specular": 0.45}
    c.motion = {"body": "cetacean", "attack": "snap", "gape": 0.4, "cycle_tiles": 1.4}
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "tail_slap"
    return c
