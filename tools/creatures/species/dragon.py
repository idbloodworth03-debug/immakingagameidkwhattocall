"""Dragon: a friendly little dragon: emerald green with a golden belly, a big
round head with two curved horns, orange spikes down its back, a long tail
with a spade tip and bat-like wings of pale green skin. It flies, so only
Ranged and Air animals can reach it.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from bodies import add_wings
from paint import Painter
from sdf import plate

J = {
    "pelvis": (0, -0.3, 0.55), "spine_mid": (0, -0.05, 0.58), "withers": (0, 0.2, 0.62),
    "neck_base": (0, 0.28, 0.68), "head_base": (0, 0.42, 0.86), "skull": (0, 0.47, 0.9),
    "snout_tip": (0, 0.66, 0.84), "jaw_hinge": (0, 0.48, 0.82), "chin": (0, 0.63, 0.78),
    "ear_base": (-0.06, 0.46, 0.96), "ear_tip": (-0.08, 0.42, 1.0),
    "shoulder": (-0.12, 0.22, 0.48), "elbow": (-0.15, 0.25, 0.3), "wrist": (-0.14, 0.27, 0.1), "front_toe": (-0.14, 0.31, 0.02),
    "hip": (-0.13, -0.28, 0.48), "knee": (-0.15, -0.2, 0.3), "hock": (-0.14, -0.34, 0.12), "hind_toe": (-0.14, -0.28, 0.02),
    "tail_base": (0, -0.48, 0.55), "tail_mid": (0, -0.8, 0.4), "tail_end": (0, -1.1, 0.25),
}
R = {
    "rump": (0.17, 0.2, 0.16), "rump_back": 0.02, "rump_drop": 0.02,
    "belly": (0.18, 0.28, 0.17), "belly_drop": 0.03,
    "chest": (0.17, 0.18, 0.18), "chest_back": 0.02, "chest_drop": 0.04, "torso_blend": 0.1,
    "neck_base": 0.11, "neck_top": 0.08, "neck_blend": 0.07,
    "skull": (0.1, 0.1, 0.09), "head_blend": 0.05,
    "snout_root": (0, 0.07, -0.04), "snout_base": 0.08, "snout_end": 0.055, "snout_blend": 0.05,
    "jaw_base": 0.055, "jaw_end": 0.04, "jaw_blend": 0.02,
    "ear_width": 0.04, "ear_thick": 0.01, "ear_round": 0.012, "ear_yaw": 0.4, "ear_sink": 0.015, "ear_voxel": 0.004,
    "scapula": (0.06, 0.08, 0.1), "scapula_up": 0.04, "scapula_pitch": 0.3,
    "upper_arm": (0.07, 0.05), "forearm": (0.05, 0.045), "front_paw": (0.05, 0.04),
    "thigh": (0.1, 0.12, 0.13), "thigh_drop": 0.04, "thigh_pitch": -0.2,
    "upper_leg": (0.09, 0.06), "shin": (0.055, 0.045), "hind_paw": (0.05, 0.045),
    "limb_blend": 0.05, "joint_blend": 0.02,
    "tail": (0.1, 0.06, 0.03, 0.015), "tail_blend": 0.05,
}
WING_J = {"shoulder": (-0.13, 0.18, 0.75), "elbow": (-0.45, 0.12, 0.88), "wrist": (-0.78, 0.2, 0.95), "wing_tip": (-1.2, 0.0, 0.9),
          "finger2": (-1.08, -0.3, 0.85), "finger3": (-0.8, -0.42, 0.8), "anchor": (-0.1, -0.25, 0.68)}
WING_R = {"wing_thick": 0.01, "wing_round": 0.02, "wing_blend": 0.03, "arm": (0.04, 0.03, 0.02)}
COLORS = {"green": "#2fa868", "dark": "#1f7a4a", "gold": "#f2d27a", "spike": "#f08a3a", "wing": "#8fdcae"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("green")
    p.blend("dark", p.smooth(n[:, 2], 0.5, 0.3) * 0.4)
    belly = p.mesh.region_weight("torso") + p.mesh.region_weight("neck") * 0.8
    p.blend("gold", belly * p.smooth(-n[:, 2], 0.55, 0.3))
    p.region("spike", "spike")
    p.region("wing", "wing")
    p.region("wing_bone", "dark")
    return p.colors


def make():
    c = quadruped("dragon", J, R, paint=paint, tiles_long=2.8)
    c.voxel = 0.009
    sk = np.asarray(J["skull"], float)
    # Two curved horns (a design may make them bigger: R horn_k).
    hk = R.get("horn_k", 1.0)
    for side in (1, -1):
        base = sk + np.array([side * 0.06, -0.03, 0.08])
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(base + np.array([side * 0.03, -0.12, 0.1]) * hk),
                              radius=0.025 * hk ** 0.5, tip_radius=0.004, color="#f2e2b8"))
    # Spikes down the back and a spade at the tail tip.
    path = [np.asarray(J[k], float) for k in ("neck_base", "withers", "spine_mid", "pelvis", "tail_base", "tail_mid")]
    bones = ["neck", "chest", "hips", "hips", "tail1", "tail2"]
    for at, bone in zip(path, bones):
        top = at + np.array([0, 0, 0.2 if bone != "tail2" else 0.11])
        c.shapes.append(plate(at + (0, 0.06, 0.08), at + (0, -0.06, 0.08), top + (0, -0.04, 0.04), 0.016, 0.012, "spike", bone, blend=0.02))
    end = np.asarray(J["tail_end"], float)
    c.shapes.append(plate(end + (-0.07, 0, 0), end + (0.07, 0, 0), end + (0, -0.12, -0.03), 0.012, 0.02, "spike", "tail3", blend=0.02))
    # (A design may make the wings bigger: R wing_k, from the shoulder.)
    wk = R.get("wing_k", 1.0)
    sh = np.asarray(WING_J["shoulder"], float)
    add_wings(c, {k: tuple(sh + (np.asarray(v, float) - sh) * wk) for k, v in WING_J.items()}, WING_R, feathers=False)
    add_face(c, eye_dir=(-0.7, 0.6, 0.3), eye_radius=0.022, eye_sink=0.008, nose_radius=0.012, iris="#e8a020", pupil="round")
    c.cartoon = {"head": 1.5}
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.35, "bump": 0.1, "roughness": 0.45, "specular": 0.4}
    c.motion.update({"attack": "winged_dive", "altitude": 0.55, "flap": 0.65, "hover_power": 0.5, "cycle_tiles": 2.0})
    return c
