"""Coyote (the Coyote Pack card is two of them): a slimmer, smaller cousin
of the wolf with big pointed ears, a narrow muzzle and long thin legs.
Grizzled gray-tan coat, rusty legs and ears, a cream throat and belly and
a bushy black-tipped tail carried low.

Real size: about 60 cm at the shoulder.
"""
from anatomy import add_face, quadruped
from sdf import ellipsoid
import numpy as np
import wolf_pack as W

J = dict(W.J)
J["ear_tip"] = (-0.1, 0.51, 1.15)
J["snout_tip"] = (0, 0.8, 0.8)
J["chin"] = (0, 0.75, 0.775)
R = dict(W.R)
R.update({"chest": (0.13, 0.22, 0.18), "belly": (0.12, 0.34, 0.11), "rump": (0.115, 0.17, 0.125),
          "neck_base": 0.13, "neck_top": 0.09, "skull": (0.09, 0.1, 0.082),
          "snout_base": 0.062, "snout_end": 0.03, "ear_width": 0.115,
          "upper_arm": (0.075, 0.05), "forearm": (0.042, 0.03), "upper_leg": (0.09, 0.052), "shin": (0.043, 0.03),
          "tail": (0.045, 0.08, 0.075, 0.035)})

COLORS = {
    "gray": "#9b8a73",
    "saddle": "#5b4f43",
    "cream": "#eadfca",
    "tan": "#c39568",
    "dark": "#2a2420",
    "ear_inner": "#e9dcc6",
}


def paint(mesh, creature):
    old = dict(W.COLORS)
    W.COLORS.update(COLORS)
    try:
        return W.paint(mesh, creature)
    finally:
        W.COLORS.clear()
        W.COLORS.update(old)


def make():
    c = quadruped("coyote_pack", J, R, paint=paint, tiles_long=1.3)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.07, 0.555, 0.835), (0.055, 0.065, 0.06), "cheek", "head", blend=0.05, yaw=side * 0.3))
    tail_mid, tail_end = np.asarray(J["tail_mid"]), np.asarray(J["tail_end"])
    c.shapes.append(ellipsoid((tail_mid + tail_end) / 2, (0.07, 0.16, 0.065), "tail", "tail2", blend=0.07,
                              pitch=np.arctan2(tail_mid[2] - tail_end[2], tail_mid[1] - tail_end[1])))
    add_face(c, eye_dir=(-0.62, 0.72, 0.32), eye_radius=0.013, eye_sink=0.008, nose_radius=0.018, nose_sink=0.008,
             iris="#d4a23a", pupil="round")
    c.fur = {"variation": 0.18, "sheen": 0.3, "bump": 0.3, "length": 0.05, "density": 22000, "hair_gamma": 2.0}
    c.motion = {"gait": "trot", "attack": "bite", "stride": 1.1}
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "pounce_bite"
    return c
