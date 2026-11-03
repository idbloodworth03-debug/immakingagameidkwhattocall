"""Pegasus: a white winged horse from Greek myth, made cute: a pony body,
a rose-and-lilac mane and tail, golden hooves and big feathered wings with
golden tips. It flies, so only Ranged and Air animals can reach it.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from bodies import add_wings
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.32, 0.82),
    "spine_mid": (0, -0.05, 0.8),
    "withers": (0, 0.25, 0.86),
    "neck_base": (0, 0.33, 0.9),
    "head_base": (0, 0.5, 1.12),
    "skull": (0, 0.55, 1.16),
    "snout_tip": (0, 0.78, 1.02),
    "jaw_hinge": (0, 0.56, 1.08),
    "chin": (0, 0.74, 0.98),
    "ear_base": (-0.05, 0.52, 1.24),
    "ear_tip": (-0.058, 0.51, 1.3),
    "shoulder": (-0.1, 0.28, 0.72),
    "elbow": (-0.11, 0.25, 0.5),
    "wrist": (-0.1, 0.27, 0.22),
    "front_toe": (-0.1, 0.3, 0.02),
    "hip": (-0.11, -0.3, 0.72),
    "knee": (-0.12, -0.2, 0.5),
    "hock": (-0.11, -0.38, 0.28),
    "hind_toe": (-0.11, -0.33, 0.02),
    "tail_base": (0, -0.48, 0.86),
    "tail_mid": (0, -0.6, 0.7),
    "tail_end": (0, -0.68, 0.5),
}

R = {
    "rump": (0.19, 0.22, 0.19), "rump_back": 0.02, "rump_drop": 0.03,
    "belly": (0.19, 0.3, 0.18), "belly_drop": 0.04,
    "chest": (0.18, 0.2, 0.2), "chest_back": 0.03, "chest_drop": 0.05, "torso_blend": 0.12,
    "neck_base": 0.13, "neck_top": 0.08, "neck_blend": 0.08,
    "skull": (0.085, 0.11, 0.09), "skull_pitch": -0.3, "head_blend": 0.05,
    "snout_root": (0, 0.08, -0.05), "snout_base": 0.075, "snout_end": 0.06, "snout_blend": 0.05,
    "jaw_base": 0.05, "jaw_end": 0.04, "jaw_blend": 0.02,
    "ear_width": 0.06, "ear_thick": 0.012, "ear_round": 0.02, "ear_yaw": 0.2, "ear_sink": 0.02, "ear_voxel": 0.004,
    "scapula": (0.07, 0.1, 0.13), "scapula_up": 0.05, "scapula_pitch": 0.3,
    "upper_arm": (0.08, 0.055), "forearm": (0.05, 0.04), "front_paw": (0.04, 0.045),
    "thigh": (0.11, 0.13, 0.15), "thigh_drop": 0.05, "thigh_pitch": -0.2,
    "upper_leg": (0.1, 0.06), "shin": (0.045, 0.04), "hind_paw": (0.04, 0.045),
    "limb_blend": 0.06, "joint_blend": 0.025,
    "tail": (0.065, 0.09, 0.08, 0.045), "tail_blend": 0.05,
}

WING_J = {"shoulder": (-0.12, 0.22, 0.95), "elbow": (-0.42, 0.18, 1.06), "wrist": (-0.76, 0.24, 1.1), "wing_tip": (-1.22, 0.04, 1.08)}
WING_R = {"chord": (0.36, 0.44, 0.46, 0.24), "wing_thick": 0.01, "wing_blend": 0.02, "feathers": 18, "fan": 1.0,
          "feather_overlap": 2.0, "arm": (0.04, 0.03, 0.02)}

COLORS = {
    "white": "#f6f3ee",
    "shade": "#e3dde8",
    "mane": "#f07cb8",
    "mane2": "#8f9ff2",
    "gold": "#e8bf52",
    "muzzle": "#f2d6d8",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("white")
    p.blend("shade", p.smooth(-n[:, 2], 0.3, 0.4) * 0.5)
    mane = p.mesh.region_weight("mane") + p.mesh.region_weight("tail") + p.mesh.region_weight("tail_tip")
    p.blend("mane", mane)
    p.blend("mane2", mane * p.smooth(np.sin(v[:, 2] * 18.0 + v[:, 1] * 6.0), 0.2, 0.5))
    p.region("front_paw", "gold")
    p.region("hind_paw", "gold")
    p.region("snout", "muzzle", 0.5)
    wing = p.mesh.region_weight("wing")
    p.blend("gold", wing * p.smooth(np.abs(v[:, 0]) - 0.85, 0.0, 0.08) * 0.9)
    return p.colors


def make():
    c = quadruped("pegasus", J, R, paint=paint, tiles_long=2.8)
    c.voxel = 0.01
    # A flowing mane down the back of the neck, and a forelock.
    neck = np.asarray(J["neck_base"], float), np.asarray(J["head_base"], float)
    for u in np.linspace(0.0, 1.0, 7):
        at = neck[0] + (neck[1] - neck[0]) * u + np.array([0, -0.1, 0.09])
        c.shapes.append(ellipsoid(tuple(at), (0.06, 0.1, 0.09), "mane", "neck", blend=0.05, pitch=0.6))
    c.shapes.append(ellipsoid((0, 0.6, 1.26), (0.065, 0.07, 0.06), "mane", "head", blend=0.04))
    add_wings(c, WING_J, WING_R)
    add_face(c, eye_dir=(-0.75, 0.5, 0.35), eye_radius=0.02, eye_sink=0.008, nose_radius=0, iris="#3b6fd4", pupil="round")
    c.cartoon = {"head": 1.6}
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.1, "roughness": 0.55}
    c.motion.update({"attack": "winged_dive", "altitude": 0.6, "flap": 0.7, "hover_power": 0.5, "cycle_tiles": 2.0})
    c.palette = {"eye_line": "#4a3a55"}
    return c
