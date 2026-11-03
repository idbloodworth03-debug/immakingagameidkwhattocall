"""Loggerhead sea turtle: a big sea turtle with a huge head, a heart-shaped
reddish-brown shell, long front flippers and small back ones. Yellowish
skin with brown scales on the head and flippers, a cream plastron. On land
it rows along with both front flippers at once.

Real size: about 90 cm shell.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import plate
from shellkit import add_shell, scute_mask

J = {
    "pelvis": (0, -0.12, 0.12),
    "spine_mid": (0, 0.0, 0.13),
    "withers": (0, 0.13, 0.12),
    "neck_base": (0, 0.18, 0.11),
    "head_base": (0, 0.26, 0.12),
    "skull": (0, 0.3, 0.125),
    "snout_tip": (0, 0.39, 0.105),
    "jaw_hinge": (0, 0.29, 0.09),
    "chin": (0, 0.37, 0.08),
    "ear_base": (-0.05, 0.29, 0.15),
    "ear_tip": (-0.051, 0.288, 0.153),
    "shoulder": (-0.12, 0.15, 0.09),
    "elbow": (-0.2, 0.16, 0.06),
    "wrist": (-0.28, 0.14, 0.03),
    "front_toe": (-0.38, 0.08, 0.012),
    "hip": (-0.1, -0.14, 0.09),
    "knee": (-0.15, -0.18, 0.06),
    "hock": (-0.17, -0.21, 0.03),
    "hind_toe": (-0.2, -0.26, 0.012),
    "tail_base": (0, -0.22, 0.1),
    "tail_mid": (0, -0.27, 0.08),
    "tail_end": (0, -0.3, 0.06),
}

R = {
    "rump": (0.1, 0.1, 0.06), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.13, 0.15, 0.065), "belly_drop": 0.0,
    "chest": (0.12, 0.1, 0.06), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.04,
    "neck_base": 0.065, "neck_top": 0.06, "neck_blend": 0.03,
    "skull": (0.08, 0.085, 0.065), "head_blend": 0.03,
    "snout_root": (0, 0.045, -0.01), "snout_base": 0.055, "snout_end": 0.03, "snout_blend": 0.025,
    "jaw_base": 0.042, "jaw_end": 0.022, "jaw_blend": 0.014,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.004, "ear_voxel": 0.001,
    "scapula": (0.035, 0.035, 0.03), "scapula_up": 0.0,
    "upper_arm": (0.04, 0.032), "forearm": (0.03, 0.022), "front_paw": (0.02, 0.012),
    "thigh": (0.045, 0.045, 0.035), "thigh_drop": 0.0,
    "upper_leg": (0.035, 0.028), "shin": (0.026, 0.02), "hind_paw": (0.018, 0.01),
    "limb_blend": 0.025, "joint_blend": 0.012,
    "tail": (0.025, 0.015, 0.008), "tail_blend": 0.012,
}

SHELL = ((0, 0.0, 0.16), (0.23, 0.29, 0.095))

COLORS = {"shell": "#9a4f26", "line": "#5c2c14", "skin": "#d9a84e", "scale": "#8c5a2a", "belly": "#efdcae"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("skin")
    top = p.smooth(p.n[:, 2], 0.0, 0.4)
    p.spots("scale", cell=0.03, radius=0.011, mask=top * (1 - Wt("shell") - Wt("plastron")) * 0.9, seed=7, jitter=0.2)
    p.region("shell", "shell")
    p.blend("line", Wt("shell") * scute_mask(p, *SHELL, width=0.04) * 0.9)
    p.region("plastron", "belly")
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("loggerhead_turtle", J, R, paint=paint, tiles_long=1.6)
    c.voxel = 0.0035
    add_shell(c, *SHELL, plastron=(0.85, 0.85, 0.35), plastron_drop=0.55, taper=0.3)
    # Long, flat front flippers; short back ones.
    for side, sx in ((".L", 1), (".R", -1)):
        m = np.array([sx, 1, 1])
        e, w, t = (np.asarray(J[k], float) * m for k in ("elbow", "wrist", "front_toe"))
        c.shapes.append(plate(e + (0, 0.05, 0), e + (0, -0.05, 0), w + (0, -0.06, 0), 0.014, 0.012, "front_lower", "fl_lower" + side, blend=0.02))
        c.shapes.append(plate(e + (0, 0.05, 0), w + (0, 0.05, 0), w + (0, -0.06, 0), 0.014, 0.012, "front_lower", "fl_lower" + side, blend=0.02))
        c.shapes.append(plate(w + (0, 0.05, 0), w + (0, -0.06, 0), t, 0.012, 0.01, "front_paw", "fl_foot" + side, blend=0.02))
        h, ht = np.asarray(J["hock"], float) * m, np.asarray(J["hind_toe"], float) * m
        c.shapes.append(plate(h + (-sx * 0.035, 0, 0), h + (sx * 0.035, 0, 0), ht + (sx * 0.01, 0, 0), 0.012, 0.01, "hind_paw", "hl_foot" + side, blend=0.012))
    add_face(c, eye_dir=(-0.65, 0.6, 0.45), eye_radius=0.011, eye_sink=0.004, nose_radius=0.0, iris="#3a2410", pupil="round")
    c.fur = {"strands": False, "variation": 0.08, "sheen": 0.4, "bump": 0.2, "roughness": 0.5}
    c.motion = {"gait": "flipper", "attack": "bite", "stride": 0.9, "gape": 0.6, "cycle_tiles": 0.6}
    return c
