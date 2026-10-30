"""Amur Leopard: a stocky, low cat with a long and very thick tail, broad
head and small round ears. Its winter coat is long and pale cream-gold, with
big, widely spaced black rosettes (rings with a darker center), solid spots
on the head, legs and belly, a white belly and black-backed ears with a
white spot.

Real size: about 70 cm at the shoulder, 1.3 m head and body, 90 cm tail.
Built from the tiger's skeleton scaled down.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.55, 0.92),
    "spine_mid": (0, -0.05, 0.9),
    "withers": (0, 0.45, 0.95),
    "neck_base": (0, 0.52, 0.86),
    "head_base": (0, 0.72, 0.92),
    "skull": (0, 0.8, 0.93),
    "snout_tip": (0, 0.98, 0.86),
    "jaw_hinge": (0, 0.8, 0.85),
    "chin": (0, 0.93, 0.79),
    "ear_base": (-0.088, 0.77, 1.03),
    "ear_tip": (-0.11, 0.75, 1.1),
    "shoulder": (-0.13, 0.5, 0.72),
    "elbow": (-0.14, 0.38, 0.48),
    "wrist": (-0.13, 0.43, 0.12),
    "front_toe": (-0.13, 0.53, 0.03),
    "hip": (-0.14, -0.56, 0.82),
    "knee": (-0.15, -0.38, 0.55),
    "hock": (-0.14, -0.72, 0.2),
    "hind_toe": (-0.13, -0.62, 0.03),
    "tail_base": (0, -0.72, 0.86),
    "tail_mid": (0, -1.05, 0.55),
    "tail_end": (0, -1.3, 0.35),
}

R = {
    "rump": (0.19, 0.27, 0.21), "rump_back": 0.02, "rump_drop": 0.16,
    "belly": (0.2, 0.55, 0.19), "belly_drop": 0.2,
    "chest": (0.22, 0.33, 0.28), "chest_back": 0.08, "chest_drop": 0.24,
    "torso_blend": 0.16,
    "neck_base": 0.2, "neck_top": 0.15, "neck_blend": 0.13,
    "skull": (0.13, 0.13, 0.12), "skull_pitch": -0.05, "head_blend": 0.07,
    "snout_root": (0, 0.09, -0.04), "snout_base": 0.085, "snout_end": 0.062, "snout_blend": 0.05,
    "jaw_base": 0.06, "jaw_end": 0.036, "jaw_blend": 0.025,
    "ear_width": 0.085, "ear_thick": 0.008, "ear_round": 0.024, "ear_yaw": 0.45, "ear_sink": 0.025,
    "ear_voxel": 0.003, "ear_fur": 0.01,
    "scapula": (0.1, 0.14, 0.2), "scapula_up": 0.13, "scapula_pitch": 0.3,
    "upper_arm": (0.13, 0.09), "forearm": (0.08, 0.06), "front_paw": (0.065, 0.06),
    "thigh": (0.17, 0.25, 0.26), "thigh_drop": 0.12, "thigh_pitch": -0.25,
    "upper_leg": (0.15, 0.09), "shin": (0.075, 0.056), "hind_paw": (0.062, 0.06),
    "limb_blend": 0.12, "joint_blend": 0.04,
    "tail": (0.06, 0.05, 0.045, 0.042), "tail_blend": 0.04,
}

COLORS = {
    "cream": "#d3aa68",
    "gold": "#bd843e",
    "white": "#f0e9dc",
    "spot": "#191311",
    "center": "#a8692a",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    W = p.mesh.region_weight
    p.fill("cream")
    p.top_darken("gold", start=0.25, strength=0.55)
    p.region_underside("torso", "white", below=-0.35, soft=0.3)
    p.region_where("neck", "white", lambda v, n: p.smooth(-n[:, 2] * 0.8 + n[:, 1] * 0.4, 0.15, 0.3))
    p.region("jaw", "white")
    p.region_where("snout", "white", lambda v, n: p.smooth(-n[:, 2], -0.2, 0.35))
    face = np.clip(W("head") + W("cheek") + W("snout"), 0, 1)
    legs = np.clip(W("front_lower") + W("hind_lower") + W("front_paw") + W("hind_paw"), 0, 1)
    tail = np.clip(W("tail") + W("tail_tip"), 0, 1)
    body = np.clip(1 - face - legs - tail - W("ear") - W("jaw"), 0, 1)
    belly = p.smooth(-n[:, 2], 0.45, 0.3)
    # Rosettes on the body: a ring of black with a warm darker middle.
    p.rosettes("spot", "center", cell=0.08, radius=0.036, blob=0.42, mask=body * (1 - belly), seed=21)
    # Solid spots on the head, legs, belly and tail.
    p.spots("spot", cell=0.03, radius=0.007, mask=face * p.smooth(np.abs(v[:, 0]) - 0.03, 0.0, 0.02), seed=22)
    p.spots("spot", cell=0.06, radius=0.014, mask=legs + body * belly, seed=23)
    p.spots("spot", cell=0.08, radius=0.022, mask=tail, seed=24)
    p.region("ear", "spot", 0.85)
    p.region_where("ear", "white", lambda v, n: p.smooth(n[:, 1], 0.4, 0.3), 0.8)
    p.speckle(0.06)
    return p.colors


def _scaled(joints, k):
    return {name: tuple(x * k for x in p) for name, p in joints.items()}


def _scaled_r(r, k):
    out = {}
    for key, value in r.items():
        if key in ("skull_pitch", "scapula_pitch", "thigh_pitch", "ear_yaw"):
            out[key] = value
        elif isinstance(value, tuple):
            out[key] = tuple(x * k for x in value)
        else:
            out[key] = value * k
    return out


def make():
    c = quadruped("amur_leopard", _scaled(J, 0.72), _scaled_r(R, 0.72), paint=paint, tiles_long=2.0)
    c.voxel = 0.005
    k = 0.72
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.1 * k, 0.8 * k, 0.86 * k), (0.085 * k, 0.09 * k, 0.085 * k), "cheek", "head",
                                  blend=0.06 * k, yaw=side * 0.3))
    # Its famously thick tail.
    tm, te = np.asarray(c.joints["tail_mid"]), np.asarray(c.joints["tail_end"])
    c.shapes.append(ellipsoid((tm + te) / 2, (0.05, 0.16, 0.05), "tail", "tail2", blend=0.04,
                              pitch=np.arctan2(tm[2] - te[2], tm[1] - te[1])))
    add_face(c, eye_dir=(-0.48, 0.82, 0.32), eye_radius=0.016 * k, eye_sink=0.009 * k, nose_radius=0.024 * k, nose_sink=0.01 * k,
             iris="#a8b860", pupil="round")
    c.extras[-1].color = "#c98a7a"     # pinkish nose
    c.fur = {"variation": 0.08, "sheen": 0.3, "bump": 0.25, "length": 0.045, "density": 20000, "hair_gamma": 1.95,
             "lengths": {"cheek": 1.2, "tail": 1.3, "tail_tip": 1.2, "neck": 1.0, "torso": 0.9}}
    c.motion = {"gait": "gallop", "attack": "pounce_bite", "stride": 1.15}
    c.palette = {"eye_line_size": 1.5}
    return c
