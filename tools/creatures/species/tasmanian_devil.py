"""Tasmanian devil: a stocky, black, dog-sized marsupial with a big blocky
head, strong jaws, small eyes, pink rounded ears that flush red, a white
stripe across the chest and a thick short tail. It scurries in a loping
run. Made cheerful: a wide toothy grin.

Real size: about 30 cm at the shoulder, 65 cm long.
Built from the raccoon's skeleton, heavier in front.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import raccoon as RC

J = dict(RC.J)
J.update({"snout_tip": (0, 0.36, 0.245), "ear_base": (-0.042, 0.258, 0.32), "ear_tip": (-0.055, 0.25, 0.35),
          "pelvis": (0, -0.17, 0.3), "withers": (0, 0.15, 0.29), "tail_mid": (0, -0.34, 0.25), "tail_end": (0, -0.39, 0.2)})
R = dict(RC.R)
R.update({"skull": (0.065, 0.06, 0.052), "snout_base": 0.036, "snout_end": 0.024, "jaw_base": 0.026, "jaw_end": 0.016,
          "chest": (0.095, 0.1, 0.09), "neck_base": 0.07, "ear_width": 0.038, "ear_round": 0.016,
          "tail": (0.035, 0.03, 0.022, 0.012)})

COLORS = {"black": "#1b1817", "white": "#f1ede6", "pink": "#ef9a9e", "nose": "#e5a0a0"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("black")
    # The white band across the chest.
    p.blend("white", (Wt("torso") + Wt("neck")) * p.smooth(0.018 - np.abs(v[:, 1] - 0.2 - (v[:, 2] - 0.2) * 0.3), 0.0, 0.008)
            * p.smooth(-n[:, 2] + n[:, 1], 0.0, 0.4))
    p.region("ear", "pink")
    p.region_where("snout", "nose", lambda v, n: p.smooth(v[:, 1] - 0.35, 0.0, 0.008), 0.8)
    p.speckle(0.05)
    return p.colors


def make():
    c = quadruped("tasmanian_devil", J, R, paint=paint, tiles_long=1.25)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.048, 0.27, 0.255), (0.038, 0.042, 0.035), "cheek", "head", blend=0.03, yaw=side * 0.4))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.008, eye_sink=0.005, nose_radius=0.008, nose_sink=0.004,
             iris="#120d0b", pupil="round")
    c.extras[-1].color = "#e08f98"
    c.fur = {"strands": False, "variation": 0.08, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "gallop", "attack": "bite", "stride": 1.1, "gape": 1.1}
    c.palette = {"eye_line": "#151210"}
    return c
