"""Greater bilby: a small Australian desert marsupial with huge long
rabbit-like ears, a long pointed pink-tipped snout, soft blue-gray fur, a
white belly, long hind feet and a black tail with a white crest at the end.
It bounds along.

Real size: about 50 cm long with the tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.1, 0.13), "spine_mid": (0, 0.0, 0.14), "withers": (0, 0.08, 0.12),
    "neck_base": (0, 0.1, 0.12), "head_base": (0, 0.14, 0.13), "skull": (0, 0.16, 0.135),
    "snout_tip": (0, 0.24, 0.11), "jaw_hinge": (0, 0.16, 0.12), "chin": (0, 0.22, 0.105),
    "ear_base": (-0.02, 0.15, 0.16), "ear_tip": (-0.035, 0.13, 0.26),
    "shoulder": (-0.03, 0.08, 0.09), "elbow": (-0.035, 0.09, 0.05), "wrist": (-0.03, 0.1, 0.015), "front_toe": (-0.03, 0.115, 0.005),
    "hip": (-0.04, -0.1, 0.1), "knee": (-0.05, -0.05, 0.07), "hock": (-0.045, -0.14, 0.02), "hind_toe": (-0.045, -0.08, 0.005),
    "tail_base": (0, -0.15, 0.12), "tail_mid": (0, -0.22, 0.1), "tail_end": (0, -0.3, 0.09),
}
R = {
    "rump": (0.055, 0.06, 0.055), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.055, 0.09, 0.05), "belly_drop": 0.0,
    "chest": (0.045, 0.05, 0.045), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.03,
    "neck_base": 0.035, "neck_top": 0.03, "neck_blend": 0.02,
    "skull": (0.032, 0.035, 0.028), "head_blend": 0.015,
    "snout_root": (0, 0.02, -0.006), "snout_base": 0.016, "snout_end": 0.006, "snout_blend": 0.01,
    "jaw_base": 0.009, "jaw_end": 0.004, "jaw_blend": 0.004,
    "ear_width": 0.03, "ear_thick": 0.003, "ear_round": 0.01, "ear_yaw": 0.2, "ear_sink": 0.004, "ear_voxel": 0.001,
    "scapula": (0.015, 0.02, 0.02), "scapula_up": 0.0,
    "upper_arm": (0.014, 0.01), "forearm": (0.009, 0.008), "front_paw": (0.008, 0.007),
    "thigh": (0.03, 0.04, 0.035), "thigh_drop": 0.0,
    "upper_leg": (0.025, 0.016), "shin": (0.012, 0.01), "hind_paw": (0.01, 0.008),
    "limb_blend": 0.012, "joint_blend": 0.006,
    "tail": (0.012, 0.01, 0.008, 0.006), "tail_blend": 0.008,
}
COLORS = {"gray": "#a7a3a8", "white": "#f2efea", "pink": "#efb0b6", "black": "#1f1c1f"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("gray")
    p.blend("white", p.smooth(-n[:, 2], 0.0, 0.4) * 0.9)
    p.region_where("ear", "pink", lambda v, n: p.smooth(n[:, 1], 0.2, 0.4), 0.7)
    p.region_where("snout", "pink", lambda v, n: p.smooth(v[:, 1] - 0.23, 0.0, 0.008))
    p.region("tail", "black")
    p.region("tail_tip", "white")
    p.region("crest", "white")
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("greater_bilby", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.0016
    te = np.asarray(J["tail_end"], float)
    c.shapes.append(ellipsoid(tuple(te + (0, -0.01, 0.008)), (0.01, 0.03, 0.016), "crest", "tail3", blend=0.006))
    add_face(c, eye_dir=(-0.6, 0.7, 0.35), eye_radius=0.006, eye_sink=0.003, nose_radius=0.004, nose_sink=0.002,
             iris="#140f0c", pupil="round")
    c.extras[-1].color = "#e39aa4"
    c.fur = {"strands": False, "variation": 0.06, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "gallop", "attack": "bite", "stride": 1.2, "gape": 0.6}
    return c
