"""Spotted hyena (the card is two of them): a big-headed, round-eared hyena
with a sloping back, high strong shoulders, low hips and a short bushy tail.
Sandy coat covered in dark round spots, a dark muzzle, a short bristly mane
and a dark tail tip. Made cheerful: a wide grin and bright eyes.

Real size: about 80 cm at the shoulder, 70 cm at the hips.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import wolf_pack as W

J = dict(W.J)
J.update({
    "pelvis": (0, -0.38, 0.62),
    "spine_mid": (0, -0.04, 0.72),
    "withers": (0, 0.3, 0.84),
    "neck_base": (0, 0.37, 0.78),
    "head_base": (0, 0.5, 0.86),
    "skull": (0, 0.56, 0.88),
    "snout_tip": (0, 0.74, 0.8),
    "jaw_hinge": (0, 0.55, 0.8),
    "chin": (0, 0.71, 0.765),
    "ear_base": (-0.07, 0.53, 0.95),
    "ear_tip": (-0.098, 0.518, 1.04),
    "shoulder": (-0.1, 0.37, 0.64),
    "elbow": (-0.105, 0.27, 0.44),
    "wrist": (-0.1, 0.3, 0.11),
    "front_toe": (-0.1, 0.37, 0.025),
    "hip": (-0.095, -0.38, 0.55),
    "knee": (-0.1, -0.27, 0.36),
    "hock": (-0.095, -0.48, 0.15),
    "hind_toe": (-0.09, -0.41, 0.025),
    "tail_base": (0, -0.52, 0.6),
    "tail_mid": (0, -0.6, 0.46),
    "tail_end": (0, -0.64, 0.34),
})
R = dict(W.R)
R.update({
    "rump": (0.13, 0.17, 0.13), "rump_drop": 0.06,
    "belly": (0.15, 0.34, 0.14), "belly_drop": 0.12,
    "chest": (0.17, 0.24, 0.22), "chest_drop": 0.15,
    "neck_base": 0.17, "neck_top": 0.12,
    "skull": (0.11, 0.11, 0.095), "snout_base": 0.072, "snout_end": 0.045, "snout_root": (0, 0.07, -0.03),
    "jaw_base": 0.05, "jaw_end": 0.032,
    "ear_width": 0.075, "ear_round": 0.035, "ear_yaw": 0.35,
    "upper_arm": (0.095, 0.062), "forearm": (0.054, 0.04), "front_paw": (0.04, 0.042),
    "thigh": (0.1, 0.13, 0.13), "upper_leg": (0.09, 0.055), "shin": (0.048, 0.036), "hind_paw": (0.038, 0.04),
    "tail": (0.035, 0.05, 0.06, 0.03),
})

COLORS = {
    "sand": "#c9ab7c",
    "spot": "#4a3526",
    "light": "#e6d5b3",
    "dark": "#2b211b",
    "ear_inner": "#d9c4a4",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("sand")
    p.region_underside("torso", "light", below=-0.5, soft=0.3, strength=0.7)
    body = 1 - p.mesh.region_weight("head") - p.mesh.region_weight("snout") - p.mesh.region_weight("jaw") - p.mesh.region_weight("ear")
    p.spots("spot", cell=0.075, radius=0.026, mask=body * (1 - p.mesh.region_weight("mane")), seed=9)
    p.region("snout", "dark", 0.75)
    p.region_where("jaw", "dark", lambda v, n: p.smooth(v[:, 1] - 0.62, 0.0, 0.04), 0.6)
    p.region("ear", "sand")
    p.region_where("ear", "ear_inner", lambda v, n: p.smooth(n[:, 1], 0.3, 0.4))
    p.region_where("ear", "dark", lambda v, n: p.smooth(v[:, 2] - 1.03, 0.0, 0.015), 0.7)
    p.region("mane", "spot", 0.6)
    p.region("tail_tip", "dark")
    for leg in ("front_paw", "hind_paw"):
        p.region(leg, "spot", 0.5)
    p.speckle(0.18)
    return p.colors


def make():
    c = quadruped("spotted_hyenas", J, R, paint=paint, tiles_long=1.45)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.08, 0.55, 0.83), (0.07, 0.08, 0.075), "cheek", "head", blend=0.06, yaw=side * 0.3))
    # A short bristly mane from the head down over the shoulders.
    c.shapes.append(ellipsoid((0, 0.3, 0.93), (0.04, 0.2, 0.06), "mane", "chest", blend=0.06, pitch=-0.35))
    tail_mid, tail_end = np.asarray(J["tail_mid"]), np.asarray(J["tail_end"])
    c.shapes.append(ellipsoid(tuple(tail_end), (0.05, 0.08, 0.05), "tail_tip", "tail2", blend=0.04))
    add_face(c, eye_dir=(-0.62, 0.72, 0.32), eye_radius=0.014, eye_sink=0.008, nose_radius=0.024, nose_sink=0.008,
             iris="#6b3e1a", pupil="round")
    c.fur = {"variation": 0.18, "sheen": 0.25, "bump": 0.3, "length": 0.035, "density": 20000, "hair_gamma": 2.0,
             "lengths": {"mane": 2.2, "tail_tip": 1.8}}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 1.05, "gape": 0.7}
    return c
