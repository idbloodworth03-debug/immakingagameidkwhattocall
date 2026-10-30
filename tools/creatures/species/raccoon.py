"""Raccoon: hunched back with the rump higher than the shoulders, broad head
with fluffy cheeks, short pointed muzzle, round white-rimmed ears, the
black bandit mask with white brows and muzzle, grizzled gray coat and a
thick ringed tail.

Real size: about 30 cm at the shoulder, 60 cm head and body, 25 cm tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.17, 0.33),
    "spine_mid": (0, 0.0, 0.315),
    "withers": (0, 0.15, 0.27),
    "neck_base": (0, 0.17, 0.245),
    "head_base": (0, 0.245, 0.275),
    "skull": (0, 0.275, 0.285),
    "snout_tip": (0, 0.37, 0.245),
    "jaw_hinge": (0, 0.275, 0.253),
    "chin": (0, 0.34, 0.233),
    "ear_base": (-0.038, 0.262, 0.322),
    "ear_tip": (-0.05, 0.252, 0.36),
    "shoulder": (-0.05, 0.17, 0.2),
    "elbow": (-0.055, 0.12, 0.13),
    "wrist": (-0.045, 0.15, 0.04),
    "front_toe": (-0.045, 0.19, 0.012),
    "hip": (-0.055, -0.17, 0.27),
    "knee": (-0.06, -0.09, 0.17),
    "hock": (-0.05, -0.2, 0.05),
    "hind_toe": (-0.045, -0.12, 0.012),
    "tail_base": (0, -0.27, 0.30),
    "tail_mid": (0, -0.39, 0.23),
    "tail_end": (0, -0.48, 0.16),
}

R = {
    "rump": (0.095, 0.115, 0.095), "rump_back": 0.01, "rump_drop": 0.05,
    "belly": (0.102, 0.17, 0.09), "belly_drop": 0.065,
    "chest": (0.088, 0.1, 0.085), "chest_back": 0.02, "chest_drop": 0.06,
    "torso_blend": 0.08,
    "neck_base": 0.06, "neck_top": 0.046, "neck_blend": 0.05,
    "skull": (0.056, 0.052, 0.045), "skull_pitch": -0.1, "head_blend": 0.035,
    "snout_root": (0, 0.035, -0.012), "snout_base": 0.028, "snout_end": 0.012, "snout_blend": 0.022,
    "jaw_base": 0.018, "jaw_end": 0.008, "jaw_blend": 0.01,
    "ear_width": 0.044, "ear_thick": 0.0035, "ear_round": 0.012, "ear_yaw": 0.4, "ear_sink": 0.01,
    "ear_fur": 0.006,
    "scapula": (0.03, 0.05, 0.06), "scapula_up": 0.04, "scapula_pitch": 0.3,
    "upper_arm": (0.04, 0.028), "forearm": (0.025, 0.019), "front_paw": (0.018, 0.017),
    "thigh": (0.05, 0.07, 0.075), "thigh_drop": 0.03, "thigh_pitch": -0.2,
    "upper_leg": (0.05, 0.033), "shin": (0.025, 0.019), "hind_paw": (0.018, 0.018),
    "limb_blend": 0.04, "joint_blend": 0.014,
    "tail": (0.035, 0.046, 0.042, 0.026), "tail_blend": 0.03,
}

COLORS = {
    "coat": "#56504a",
    "tips": "#8f887d",
    "under": "#7d7569",
    "legs": "#3c3631",
    "white": "#ebe7df",
    "mask": "#151210",
    "ring": "#1e1a17",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("coat")
    p.where("tips", lambda v, n: p.smooth(n[:, 2], 0.3, 0.5), 0.4)
    p.region_underside("torso", "under", below=-0.4, soft=0.3, strength=0.8)
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region(leg, "legs", 0.85)
    # Face: white muzzle and brows, black mask over the eyes.
    p.region("snout", "white", 0.9)
    p.region("jaw", "white")
    p.region_where("snout", "legs", lambda v, n: p.smooth(n[:, 2], 0.5, 0.3) * p.smooth(0.016 - np.abs(v[:, 0]), 0.0, 0.006), 0.8)
    if creature.eyes:
        eye_z = float(np.mean([e[0][2] for e in creature.eyes]))
        face = p.mesh.region_weight("head") + p.mesh.region_weight("cheek") + p.mesh.region_weight("snout")
        band = p.smooth(0.016 - np.abs(v[:, 2] - eye_z + 0.006), 0.0, 0.008) * p.smooth(v[:, 1] - 0.262, 0.0, 0.012)
        p.blend("white", face * p.smooth(v[:, 2] - eye_z - 0.012, 0.0, 0.006) * p.smooth(0.315 - v[:, 2], 0.0, 0.01) * p.smooth(v[:, 1] - 0.27, 0.0, 0.01))
        p.blend("mask", face * band)
    p.region_where("cheek", "white", lambda v, n: p.smooth(0.265 - v[:, 2], 0.0, 0.012), 0.8)
    # Ears: gray with white rims.
    p.region("ear", "coat")
    p.region_where("ear", "white", lambda v, n: p.smooth(v[:, 2] - 0.345, 0.0, 0.008))
    # Tail: buff with black rings and a black tip.
    p.region("tail", "tips", 0.5)
    tail_axis = np.asarray(creature.joints["tail_end"]) - np.asarray(creature.joints["tail_base"])
    along = lambda q: (q - np.asarray(creature.joints["tail_base"])) @ tail_axis / (tail_axis @ tail_axis)
    tail_mask = p.mesh.region_weight("tail") + p.mesh.region_weight("tail_tip")
    p.stripes("ring", along, frequency=5.0, width=0.22, mask=tail_mask * p.smooth(along(v), 0.08, 0.05))
    p.region("tail_tip", "ring")
    p.speckle(0.2)
    return p.colors


def make():
    c = quadruped("raccoon", J, R, paint=paint, tiles_long=1.3)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.042, 0.27, 0.26), (0.034, 0.038, 0.032), "cheek", "head", blend=0.03, yaw=side * 0.4))
    add_face(c, eye_dir=(-0.55, 0.78, 0.25), eye_radius=0.0085, eye_sink=0.005, nose_radius=0.0072, nose_sink=0.004,
             iris="#24170e", pupil="round")
    c.fur = {"variation": 0.2, "sheen": 0.3, "bump": 0.3, "length": 0.028, "density": 60000, "hair_gamma": 1.9,
             "lengths": {"cheek": 1.2, "tail": 1.3, "tail_tip": 1.2}}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.35, "stride": 1.1}
    c.palette = {"eye_line": "#151210"}
    return c
