"""Wolverine: a powerful, bear-like weasel on short strong legs with big
furry paws, a broad head with small round ears and a bushy tail. Dark
brown, with a pale tan stripe running from the shoulders along each side to
the tail, and a light brow.

Real size: about 40 cm at the shoulder, 90 cm long.
Built from the honey badger's skeleton, a little taller.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import honey_badger as HB
from derive import scaled, scaled_r

K = 1.15
J = scaled(HB.J, K)
J["ear_tip"] = tuple(np.asarray(J["ear_base"]) + (-0.01, -0.006, 0.03))
R = scaled_r(HB.R, K)
R.update({"ear_width": 0.03, "ear_round": 0.012, "tail": (0.035, 0.04, 0.036, 0.022), "front_paw": (0.032, 0.03), "hind_paw": (0.03, 0.028)})
J["tail_mid"] = tuple(np.asarray(J["tail_base"]) + (0, -0.08, -0.03))
J["tail_end"] = tuple(np.asarray(J["tail_base"]) + (0, -0.15, -0.07))

COLORS = {"brown": "#3a2a1f", "tan": "#c9a46c", "dark": "#1f1712", "brow": "#a38463"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("brown")
    # The tan side stripe, from the shoulders back to the tail.
    zc = 0.29 * K
    stripe = p.smooth(0.022 - np.abs(v[:, 2] - zc + np.abs(v[:, 0]) * 0.3), 0.0, 0.01) * p.smooth(np.abs(v[:, 0]) - 0.04, 0.0, 0.02)
    p.blend("tan", stripe * (Wt("torso") + Wt("tail")) * p.smooth(0.2 * K - v[:, 1], 0.0, 0.03))
    p.blend("brow", Wt("head") * p.smooth(n[:, 2], 0.4, 0.3) * 0.7)
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "dark", 0.8)
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("wolverine", J, R, paint=paint, tiles_long=1.3)
    c.voxel = 0.003
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.05 * K, 0.275 * K, 0.215 * K), (0.04, 0.045, 0.035), "cheek", "head", blend=0.03, yaw=side * 0.3))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.009, eye_sink=0.005, nose_radius=0.01, nose_sink=0.004,
             iris="#1a1210", pupil="round")
    c.fur = {"strands": False, "variation": 0.12, "sheen": 0.3, "bump": 0.3, "roughness": 0.65}
    c.motion = {"gait": "gallop", "attack": "bite", "stride": 1.1, "gape": 0.9}
    c.palette = {"eye_line": "#151210"}
    return c
