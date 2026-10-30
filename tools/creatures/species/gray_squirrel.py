"""Eastern Gray Squirrel: compact body, long folded hind legs for bounding,
short front legs with nimble paws, small upright ears, and the huge bushy
tail curled up over its back in an S. Gray coat washed with brown on the
back and face, white belly, white fringe around the tail. It throws.

Real size: about 25 cm head and body, 22 cm tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.055, 0.09),
    "spine_mid": (0, 0.0, 0.096),
    "withers": (0, 0.052, 0.088),
    "neck_base": (0, 0.066, 0.083),
    "head_base": (0, 0.09, 0.098),
    "skull": (0, 0.1, 0.103),
    "snout_tip": (0, 0.137, 0.09),
    "jaw_hinge": (0, 0.1, 0.091),
    "chin": (0, 0.126, 0.082),
    "ear_base": (-0.013, 0.097, 0.121),
    "ear_tip": (-0.016, 0.094, 0.14),
    "shoulder": (-0.017, 0.058, 0.066),
    "elbow": (-0.019, 0.044, 0.046),
    "wrist": (-0.017, 0.054, 0.012),
    "front_toe": (-0.017, 0.067, 0.004),
    "hip": (-0.021, -0.058, 0.08),
    "knee": (-0.025, -0.022, 0.05),
    "hock": (-0.021, -0.076, 0.024),
    "hind_toe": (-0.019, -0.034, 0.004),
    "tail_base": (0, -0.088, 0.085),
    "tail_mid": (0, -0.14, 0.145),
    "tail_end": (0, -0.095, 0.2),
}

R = {
    "rump": (0.031, 0.04, 0.033), "rump_back": 0.004, "rump_drop": 0.02,
    "belly": (0.031, 0.055, 0.03), "belly_drop": 0.022,
    "chest": (0.027, 0.034, 0.028), "chest_back": 0.006, "chest_drop": 0.02,
    "torso_blend": 0.022,
    "neck_base": 0.022, "neck_top": 0.017, "neck_blend": 0.014,
    "skull": (0.02, 0.021, 0.019), "skull_pitch": -0.1, "head_blend": 0.012,
    "snout_root": (0, 0.013, -0.004), "snout_base": 0.012, "snout_end": 0.0065, "snout_blend": 0.008,
    "jaw_base": 0.007, "jaw_end": 0.0035, "jaw_blend": 0.004,
    "ear_width": 0.012, "ear_thick": 0.0012, "ear_round": 0.0035, "ear_yaw": 0.35, "ear_sink": 0.003,
    "ear_voxel": 0.0006, "ear_fur": 0.002,
    "scapula": (0.011, 0.015, 0.02), "scapula_up": 0.012, "scapula_pitch": 0.3,
    "upper_arm": (0.011, 0.0075), "forearm": (0.0065, 0.005), "front_paw": (0.0045, 0.0045),
    "thigh": (0.019, 0.026, 0.028), "thigh_drop": 0.01, "thigh_pitch": -0.2,
    "upper_leg": (0.017, 0.011), "shin": (0.008, 0.006), "hind_paw": (0.0055, 0.006),
    "limb_blend": 0.012, "joint_blend": 0.004,
    "tail": (0.011, 0.024, 0.026, 0.018), "tail_blend": 0.014,
}

COLORS = {
    "gray": "#7a7672",
    "brown": "#7f6450",
    "white": "#e9e5dc",
    "dark": "#2a2420",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("gray")
    # Brownish wash along the back, flanks and face.
    p.where("brown", lambda v, n: p.smooth(n[:, 2], 0.1, 0.5), 0.3)
    p.region("head", "brown", 0.35)
    p.region("snout", "brown", 0.3)
    p.region_underside("torso", "white", below=-0.3, soft=0.3)
    p.region("jaw", "white")
    p.region_where("neck", "white", lambda v, n: p.smooth(-n[:, 2] + n[:, 1] * 0.5, 0.2, 0.3))
    # White eye ring.
    for center, radius in creature.eyes:
        d = np.linalg.norm(p.v - center, axis=1)
        p.blend("white", np.clip((radius * 1.55 - d) / (radius * 0.3), 0, 1) * 0.6)
    # Tail: gray core; the fur on it gets lighter toward the outside.
    p.region("tail", "gray", 0.6)
    p.speckle(0.2)
    return p.colors


def make():
    c = quadruped("gray_squirrel", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.0018
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.014, 0.103, 0.092), (0.012, 0.014, 0.012), "cheek", "head", blend=0.008))
    # The plume: big soft volumes along the curled tail.
    tb, tm, te = (np.asarray(J[k]) for k in ("tail_base", "tail_mid", "tail_end"))
    c.shapes.append(ellipsoid((tb + tm) / 2 + (0, -0.006, 0), (0.024, 0.035, 0.024), "tail", "tail1", blend=0.018,
                              pitch=np.arctan2(tm[2] - tb[2], tb[1] - tm[1])))
    c.shapes.append(ellipsoid((tm + te) / 2 + (0, -0.008, 0), (0.026, 0.038, 0.025), "tail", "tail2", blend=0.018,
                              pitch=np.arctan2(te[2] - tm[2], te[1] - tm[1]) + np.pi))
    add_face(c, eye_dir=(-0.75, 0.55, 0.38), eye_radius=0.0052, eye_sink=0.0022, nose_radius=0.003, nose_sink=0.0012,
             iris="#140c08", pupil="round")
    c.fur = {"variation": 0.2, "sheen": 0.3, "bump": 0.3, "length": 0.01, "density": 700000, "hair_gamma": 1.8,
             "strand": 0.0004, "lengths": {"tail": 2.2, "tail_tip": 2.0, "torso": 0.7, "snout": 0.12},
             "comb": (0.0, -0.6, 0.2)}
    c.motion = {"gait": "gallop", "attack": "throw", "rear": 0.85, "stride": 1.2}
    return c
