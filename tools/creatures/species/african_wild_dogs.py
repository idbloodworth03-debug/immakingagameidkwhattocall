"""African Wild Dog (the card is four of them): lean and long-legged with
huge rounded ears, a short broad muzzle and a bushy tail. The "painted"
coat is a patchwork of black, tan and cream blotches, different on every
dog, with a black face, a dark stripe up the forehead and a white tail tip.

Real size: about 70 cm at the shoulder, 1 m head and body.
Built from the wolf's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.40, 0.74),
    "spine_mid": (0, -0.05, 0.75),
    "withers": (0, 0.30, 0.78),
    "neck_base": (0, 0.36, 0.70),
    "head_base": (0, 0.52, 0.86),
    "skull": (0, 0.57, 0.89),
    "snout_tip": (0, 0.74, 0.82),
    "jaw_hinge": (0, 0.56, 0.82),
    "chin": (0, 0.7, 0.785),
    "ear_base": (-0.065, 0.535, 0.93),
    "ear_tip": (-0.1, 0.52, 1.1),
    "shoulder": (-0.09, 0.37, 0.60),
    "elbow": (-0.095, 0.26, 0.42),
    "wrist": (-0.09, 0.29, 0.11),
    "front_toe": (-0.088, 0.36, 0.025),
    "hip": (-0.095, -0.40, 0.66),
    "knee": (-0.105, -0.26, 0.44),
    "hock": (-0.095, -0.53, 0.19),
    "hind_toe": (-0.09, -0.46, 0.025),
    "tail_base": (0, -0.55, 0.70),
    "tail_mid": (0, -0.70, 0.50),
    "tail_end": (0, -0.79, 0.30),
}

R = {
    "rump": (0.13, 0.19, 0.14), "rump_back": 0.02, "rump_drop": 0.10,
    "belly": (0.12, 0.36, 0.11), "belly_drop": 0.14,
    "chest": (0.135, 0.23, 0.19), "chest_back": 0.07, "chest_drop": 0.17,
    "torso_blend": 0.2,
    "neck_base": 0.15, "neck_top": 0.10, "neck_blend": 0.12,
    "skull": (0.098, 0.105, 0.088), "skull_pitch": -0.1, "head_blend": 0.07,
    "snout_root": (0, 0.08, -0.03), "snout_base": 0.07, "snout_end": 0.036, "snout_blend": 0.05,
    "jaw_base": 0.046, "jaw_end": 0.025, "jaw_blend": 0.022,
    "ear_width": 0.13, "ear_thick": 0.006, "ear_round": 0.04, "ear_yaw": 0.45, "ear_sink": 0.025, "ear_voxel": 0.003, "ear_fur": 0.014,
    "scapula": (0.065, 0.1, 0.15), "scapula_up": 0.1, "scapula_pitch": 0.35,
    "upper_arm": (0.088, 0.058), "forearm": (0.05, 0.036), "front_paw": (0.035, 0.038),
    "thigh": (0.105, 0.15, 0.16), "thigh_drop": 0.07, "thigh_pitch": -0.25,
    "upper_leg": (0.1, 0.06), "shin": (0.05, 0.035), "hind_paw": (0.035, 0.038),
    "limb_blend": 0.09, "joint_blend": 0.03,
    "tail": (0.05, 0.085, 0.08, 0.04), "tail_blend": 0.07,
}

COLORS = {
    "tan": "#b5843f",
    "black": "#1b1612",
    "cream": "#e4d8c2",
    "brown": "#6b4a2a",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    W = p.mesh.region_weight
    p.fill("tan")
    # The painted coat: blotches of black, cream and brown from noise. The
    # finer noise roughens their edges; cartoon coats keep them smooth.
    seed = int(creature.motion.get("coat_seed", 4))
    p.blend("black", p.smooth(p.noise(26.0, seed, markings=True) + 0.3 * p.noise(55.0, seed + 5), 0.05, 0.22))
    p.blend("cream", p.smooth(p.noise(30.0, seed + 1, markings=True) + 0.3 * p.noise(60.0, seed + 6), 0.6, 0.2) * 0.9)
    p.blend("brown", p.smooth(p.noise(22.0, seed + 2, markings=True), 0.45, 0.25) * 0.6)
    # Black face and muzzle, dark stripe up the forehead, dark ears.
    face = np.clip(W("snout") + W("jaw") + W("cheek"), 0, 1)
    p.blend("black", face)
    p.blend("black", W("head") * p.smooth(0.018 - np.abs(v[:, 0]), 0.0, 0.01) * p.smooth(n[:, 2], 0.2, 0.3))
    p.region("ear", "black", 0.85)
    # Tail: tan base, black middle, white tip.
    tb, te = np.asarray(creature.joints["tail_base"]), np.asarray(creature.joints["tail_tip_end"])
    along = lambda q: (q - tb) @ (te - tb) / ((te - tb) @ (te - tb))
    tail = W("tail") + W("tail_tip")
    p.blend("tan", tail * p.smooth(0.35 - along(v), 0.0, 0.1))
    p.blend("black", tail * p.smooth(along(v) - 0.35, 0.0, 0.1) * p.smooth(0.7 - along(v), 0.0, 0.08))
    p.blend("cream", tail * p.smooth(along(v) - 0.7, 0.0, 0.08))
    p.speckle(0.12)
    return p.colors


def make():
    c = quadruped("african_wild_dogs", J, R, paint=paint, tiles_long=1.4)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.075, 0.555, 0.835), (0.065, 0.075, 0.07), "cheek", "head", blend=0.06, yaw=side * 0.3))
    tail_mid, tail_end = np.asarray(J["tail_mid"]), np.asarray(J["tail_end"])
    c.shapes.append(ellipsoid((tail_mid + tail_end) / 2, (0.075, 0.17, 0.07), "tail", "tail2", blend=0.07,
                              pitch=np.arctan2(tail_mid[2] - tail_end[2], tail_mid[1] - tail_end[1])))
    add_face(c, eye_dir=(-0.62, 0.72, 0.32), eye_radius=0.013, eye_sink=0.008, nose_radius=0.02, nose_sink=0.008,
             iris="#3a2410", pupil="round")
    c.fur = {"variation": 0.15, "sheen": 0.3, "bump": 0.3, "length": 0.03, "density": 26000, "hair_gamma": 1.9,
             "lengths": {"tail": 2.0, "tail_tip": 2.0, "neck": 1.0, "cheek": 0.6}}
    c.motion = {"gait": "gallop", "attack": "bite", "stride": 1.15, "coat_seed": 4}
    return c
