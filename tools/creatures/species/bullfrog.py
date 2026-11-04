"""American bullfrog: a big green frog sitting up, with a wide head, bulging
eyes on top, a round eardrum behind each eye, a pale yellow throat, dark
spots on its back and long folded back legs. It lashes out its tongue.

Real size: about 15 cm long, sitting.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter

J = {
    "pelvis": (0, -0.08, 0.085), "spine_mid": (0, 0.0, 0.1), "withers": (0, 0.07, 0.12),
    "neck_base": (0, 0.1, 0.13), "head_base": (0, 0.12, 0.14), "skull": (0, 0.15, 0.15),
    "snout_tip": (0, 0.22, 0.12), "jaw_hinge": (0, 0.13, 0.1), "chin": (0, 0.21, 0.095),
    "ear_base": (-0.05, 0.14, 0.17), "ear_tip": (-0.052, 0.14, 0.174),
    "shoulder": (-0.06, 0.08, 0.09), "elbow": (-0.08, 0.11, 0.05), "wrist": (-0.075, 0.12, 0.012), "front_toe": (-0.08, 0.15, 0.005),
    "hip": (-0.07, -0.07, 0.08), "knee": (-0.13, 0.0, 0.05), "hock": (-0.12, -0.1, 0.02), "hind_toe": (-0.13, 0.02, 0.005),
    "tail_base": (0, -0.1, 0.08), "tail_mid": (0, -0.104, 0.08), "tail_end": (0, -0.108, 0.08),
}
R = {
    "rump": (0.08, 0.07, 0.06), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.095, 0.09, 0.065), "belly_drop": 0.0,
    "chest": (0.085, 0.06, 0.06), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.05,
    "neck_base": 0.07, "neck_top": 0.065, "neck_blend": 0.04,
    "skull": (0.085, 0.07, 0.05), "head_blend": 0.035,
    "snout_root": (0, 0.04, -0.01), "snout_base": 0.065, "snout_end": 0.035, "snout_blend": 0.03,
    "jaw_base": 0.06, "jaw_end": 0.035, "jaw_blend": 0.02,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.3, "ear_sink": 0.006, "ear_voxel": 0.0015,
    "scapula": (0.02, 0.02, 0.02), "scapula_up": 0.0,
    "upper_arm": (0.018, 0.014), "forearm": (0.014, 0.012), "front_paw": (0.012, 0.014),
    "thigh": (0.04, 0.05, 0.035), "thigh_drop": 0.0,
    "upper_leg": (0.035, 0.025), "shin": (0.025, 0.018), "hind_paw": (0.016, 0.02),
    "limb_blend": 0.02, "joint_blend": 0.01,
    "tail": (0.004, 0.003, 0.002), "tail_blend": 0.004,
}
COLORS = {"green": "#6d9a3a", "spot": "#3f5f24", "throat": "#efe6a8", "drum": "#8a6a3a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("green")
    p.spots("spot", cell=0.03, radius=0.007, mask=p.smooth(n[:, 2], 0.2, 0.4) * 0.8)
    p.blend("throat", p.smooth(-n[:, 2], 0.0, 0.4))
    p.region("jaw", "throat", 0.7)
    # The round eardrum behind each eye.
    drum = p.mesh.region_weight("head") * p.smooth(0.016 - np.hypot(np.abs(v[:, 0]) - 0.075, v[:, 2] - 0.15), 0.0, 0.004)
    p.blend("drum", drum)
    return p.colors


def make():
    c = quadruped("bullfrog", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.0025
    add_face(c, eye_dir=(-0.6, 0.4, 0.7), eye_radius=0.018, eye_sink=0.006, nose_radius=0, iris="#c9a030", pupil="round")
    c.cartoon = {"head": 1.3, "legs": 0.9}
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.45, "bump": 0.15, "roughness": 0.35, "specular": 0.5}
    c.motion = {"body": "frog", "attack": "spit", "gape": 0.6, "hop": 0.6, "cycle_tiles": 0.9}
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "leap"
    return c
