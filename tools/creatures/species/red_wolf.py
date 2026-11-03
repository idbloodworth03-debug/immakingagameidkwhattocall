"""Red wolf: a lanky wolf of the southeastern US, between a gray wolf and a
coyote in size, with long legs, tall ears and a cinnamon-red coat: tawny
legs, ears and muzzle, a darker grizzled back, cream throat and a
black-tipped tail.

Real size: about 70 cm at the shoulder.
"""
from anatomy import add_face, quadruped
from sdf import ellipsoid
import numpy as np
import wolf_pack as W

J = dict(W.J)
J["ear_tip"] = (-0.095, 0.514, 1.115)
R = dict(W.R)
R.update({"chest": (0.14, 0.23, 0.19), "belly": (0.13, 0.35, 0.12), "rump": (0.12, 0.18, 0.13),
          "neck_base": 0.14, "ear_width": 0.102, "snout_base": 0.066, "snout_end": 0.033,
          "upper_arm": (0.08, 0.054), "forearm": (0.046, 0.033), "upper_leg": (0.095, 0.056), "shin": (0.046, 0.032)})

COLORS = {
    "gray": "#8f6a50",
    "saddle": "#3f3029",
    "cream": "#ead8bf",
    "tan": "#c8794a",
    "dark": "#221a16",
    "ear_inner": "#efd9c0",
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
    c = quadruped("red_wolf", J, R, paint=paint, tiles_long=1.45)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.072, 0.555, 0.835), (0.06, 0.07, 0.065), "cheek", "head", blend=0.06, yaw=side * 0.3))
    c.shapes.append(ellipsoid((0, 0.43, 0.76), (0.14, 0.12, 0.15), "neck", "neck", blend=0.08, pitch=0.5))
    tail_mid, tail_end = np.asarray(J["tail_mid"]), np.asarray(J["tail_end"])
    c.shapes.append(ellipsoid((tail_mid + tail_end) / 2, (0.07, 0.16, 0.065), "tail", "tail2", blend=0.07,
                              pitch=np.arctan2(tail_mid[2] - tail_end[2], tail_mid[1] - tail_end[1])))
    add_face(c, eye_dir=(-0.62, 0.72, 0.32), eye_radius=0.013, eye_sink=0.008, nose_radius=0.02, nose_sink=0.008,
             iris="#d9a531", pupil="round")
    c.fur = {"variation": 0.18, "sheen": 0.3, "bump": 0.3, "length": 0.055, "density": 22000, "hair_gamma": 2.0}
    c.motion = {"gait": "trot", "attack": "pounce_bite", "stride": 1.1}
    return c
