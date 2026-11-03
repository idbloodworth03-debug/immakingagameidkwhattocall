"""Western diamondback rattlesnake: a heavy snake lying in loose S-curves
with its head raised a little, a broad triangular head, tan-gray scales
with dark diamonds outlined in cream down the back, a black-and-white
banded tail and a rattle held up at the tip.

Real size: about 1.2 m long.
Built on the cobra's body plan, with no hood.
"""
import numpy as np

from anatomy import add_face
from bodies import snake
from paint import Painter
from sdf import ellipsoid

J = {
    "tail_end": (0.1, -0.36, 0.02), "tail_mid": (-0.13, -0.3, 0.03), "tail_base": (0.11, -0.17, 0.035),
    "pelvis": (-0.09, -0.04, 0.04), "spine_mid": (0.06, 0.07, 0.042), "withers": (-0.02, 0.15, 0.07),
    "neck_base": (0, 0.18, 0.15), "head_base": (0, 0.2, 0.2), "skull": (0, 0.235, 0.21),
    "snout_tip": (0, 0.3, 0.2), "jaw_hinge": (0, 0.23, 0.19), "chin": (0, 0.29, 0.185),
}
R = {
    "body": (0.012, 0.022, 0.032, 0.038, 0.04, 0.037, 0.03, 0.024),
    "skull": (0.042, 0.042, 0.024), "snout_root": (0, 0.03, -0.004), "snout": (0.026, 0.012), "jaw": (0.018, 0.01),
    "blend": 0.02,
}

COLORS = {"tan": "#b7a27c", "diamond": "#5a4630", "cream": "#efe4c8", "black": "#231d18", "rattle": "#d8c39b"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("tan")
    body = Wt("torso")
    along = (v[:, 1] + v[:, 2] * 0.6) * 11.0
    s = np.abs(np.mod(along, 1.0) - 0.5) * 2
    side = 1 - np.clip(n[:, 2], 0, 1)
    d = s * 0.7 + side * 0.9
    p.blend("cream", body * p.smooth(0.85 - d, 0.0, 0.06))
    p.blend("diamond", body * p.smooth(0.68 - d, 0.0, 0.06))
    p.blend("cream", p.smooth(-n[:, 2], 0.2, 0.4) * body * 0.7)
    # The "coon tail": black and white rings.
    p.stripes("black", lambda q: q[:, 0] * 0.6 + q[:, 1], frequency=30.0, width=0.5, mask=Wt("tail"))
    p.region("rattle", "rattle")
    p.blend("diamond", Wt("head") * p.smooth(n[:, 2], 0.4, 0.3) * 0.5)
    p.blend("cream", Wt("jaw"))
    return p.colors


def make():
    c = snake("rattlesnake", J, R, paint=paint, tiles_long=1.5)
    c.voxel = 0.0028
    # Wide jaws at the back of the head make it triangular.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.025, 0.225, 0.205), (0.022, 0.026, 0.017), "head", "head", blend=0.012))
    # The rattle: a stack of rounded buttons held up off the ground.
    tip = np.asarray(J["tail_end"], float)
    for i in range(5):
        c.shapes.append(ellipsoid(tuple(tip + (0.0, -0.004 * i, 0.012 + 0.011 * i)), (0.011 - i * 0.0008, 0.008, 0.0065),
                                  "rattle", "tail3", blend=0.003))
    add_face(c, eye_dir=(-0.7, 0.55, 0.35), eye_radius=0.008, eye_sink=0.003, nose_radius=0, iris="#c9a23a", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.3, "bump": 0.15, "roughness": 0.5, "specular": 0.35}
    c.motion = {"body": "serpent", "attack": "bite", "gape": 0.7, "cycle_tiles": 1.0}
    return c
