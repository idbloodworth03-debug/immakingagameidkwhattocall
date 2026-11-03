"""Common snapping turtle: a big, rugged pond turtle with a rough dark olive
shell with three ridges of bumps, a large head with a hooked beak, thick
scaly legs with claws and a long tail with a saw-toothed crest. Made
friendly: a big grin and round eyes.

Real size: about 35 cm shell, 45 cm with head and tail.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import cone
from shellkit import add_shell, scute_mask

J = {
    "pelvis": (0, -0.12, 0.13),
    "spine_mid": (0, 0.0, 0.14),
    "withers": (0, 0.12, 0.13),
    "neck_base": (0, 0.17, 0.12),
    "head_base": (0, 0.25, 0.125),
    "skull": (0, 0.285, 0.13),
    "snout_tip": (0, 0.36, 0.115),
    "jaw_hinge": (0, 0.28, 0.1),
    "chin": (0, 0.345, 0.092),
    "ear_base": (-0.045, 0.275, 0.15),
    "ear_tip": (-0.046, 0.273, 0.153),
    "shoulder": (-0.12, 0.12, 0.1),
    "elbow": (-0.18, 0.15, 0.075),
    "wrist": (-0.19, 0.17, 0.025),
    "front_toe": (-0.2, 0.21, 0.008),
    "hip": (-0.12, -0.12, 0.1),
    "knee": (-0.18, -0.15, 0.075),
    "hock": (-0.19, -0.17, 0.025),
    "hind_toe": (-0.2, -0.205, 0.008),
    "tail_base": (0, -0.2, 0.11),
    "tail_mid": (0, -0.32, 0.075),
    "tail_end": (0, -0.42, 0.035),
}

R = {
    "rump": (0.1, 0.1, 0.06), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.13, 0.15, 0.07), "belly_drop": 0.0,
    "chest": (0.12, 0.1, 0.06), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.04,
    "neck_base": 0.06, "neck_top": 0.055, "neck_blend": 0.03,
    "skull": (0.068, 0.072, 0.055), "head_blend": 0.025,
    "snout_root": (0, 0.04, -0.01), "snout_base": 0.045, "snout_end": 0.022, "snout_blend": 0.02,
    "jaw_base": 0.036, "jaw_end": 0.018, "jaw_blend": 0.012,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.004, "ear_voxel": 0.001,
    "scapula": (0.03, 0.03, 0.03), "scapula_up": 0.0,
    "upper_arm": (0.04, 0.035), "forearm": (0.034, 0.03), "front_paw": (0.03, 0.022),
    "thigh": (0.05, 0.05, 0.04), "thigh_drop": 0.0,
    "upper_leg": (0.045, 0.04), "shin": (0.038, 0.032), "hind_paw": (0.032, 0.024),
    "limb_blend": 0.025, "joint_blend": 0.012,
    "tail": (0.042, 0.026, 0.012, 0.004), "tail_blend": 0.015,
}

SHELL = ((0, 0.0, 0.17), (0.2, 0.24, 0.09))

COLORS = {"shell": "#4e4a32", "ridge": "#3a3724", "line": "#2b2919", "skin": "#7c7350", "belly": "#c8b67e", "beak": "#4a4535"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("skin")
    p.blend("skin", p.smooth(-p.n[:, 2], 0.2, 0.4) * 0.4)
    p.region("shell", "shell")
    p.region("ridge", "ridge")
    p.blend("line", Wt("shell") * scute_mask(p, *SHELL) * 0.85)
    p.region("plastron", "belly")
    p.region_where("snout", "beak", lambda v, n: p.smooth(v[:, 1] - 0.34, 0.0, 0.01), 0.8)
    p.region("crest", "ridge")
    p.speckle(0.18)
    return p.colors


def make():
    c = quadruped("snapping_turtle", J, R, paint=paint, tiles_long=1.3)
    c.voxel = 0.0035
    add_shell(c, *SHELL)
    # Three ridges of bumps along the shell.
    for x in (-0.09, 0.0, 0.09):
        for y in np.linspace(-0.14, 0.14, 4):
            z = 0.17 + 0.09 * np.sqrt(max(0.0, 1 - (x / 0.2) ** 2 - (y / 0.24) ** 2)) - 0.005
            c.shapes.append(cone((x, float(y) + 0.02, z - 0.01), (x, float(y) - 0.02, z + 0.012), 0.022, 0.008, "ridge", "root", blend=0.012))
    # The saw-toothed crest down the tail.
    base, end = np.asarray(J["tail_base"], float), np.asarray(J["tail_end"], float)
    for u in np.linspace(0.15, 0.8, 5):
        at = base + (end - base) * u
        c.shapes.append(cone(at + (0, 0.012, 0.01), at + (0, -0.01, 0.035 * (1 - u) + 0.012), 0.008, 0.002, "crest",
                             "tail1" if u < 0.5 else "tail2", blend=0.006))
    for side, bone in ((1, "fl_foot.R"), (-1, "fl_foot.L")):
        for k in (-1, 0, 1):
            b = (side * (0.2 + k * 0.012), 0.21, 0.01)
            c.extras.append(Extra("cone", "claw", bone, center=b, tip=(b[0], 0.232, 0.003), radius=0.004, tip_radius=0.0008, color="#d9ccb0"))
    add_face(c, eye_dir=(-0.62, 0.62, 0.45), eye_radius=0.009, eye_sink=0.004, nose_radius=0.0, iris="#5a4a1e", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.25, "bump": 0.4, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.8, "gape": 1.0, "cycle_tiles": 0.55}
    return c
