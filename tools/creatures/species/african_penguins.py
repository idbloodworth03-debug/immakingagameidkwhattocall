"""African penguin (the card is a little group of them): a small upright
penguin shaped like a bowling pin, black back and head, a white front with
a black horseshoe band across the chest and a few black spots, a white
stripe curving from above the eye down the side of the head, a pink patch
above the eye, a black beak and black-and-pink feet. On land it waddles.

Real size: about 65 cm tall.
Built standing up like the primates: the "front legs" are its flippers.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import plate

J = {
    "pelvis": (0, 0.0, 0.2), "spine_mid": (0, 0.0, 0.3), "withers": (0, 0.0, 0.42),
    "neck_base": (0, 0.0, 0.46), "head_base": (0, 0.01, 0.5), "skull": (0, 0.02, 0.55),
    "snout_tip": (0, 0.12, 0.535), "jaw_hinge": (0, 0.05, 0.525), "chin": (0, 0.11, 0.528),
    "ear_base": (-0.045, 0.015, 0.58), "ear_tip": (-0.046, 0.014, 0.582),
    "shoulder": (-0.1, 0.0, 0.42), "elbow": (-0.125, -0.01, 0.33), "wrist": (-0.135, 0.0, 0.24), "front_toe": (-0.135, 0.01, 0.19),
    "hip": (-0.05, 0.0, 0.11), "knee": (-0.055, 0.02, 0.065), "hock": (-0.055, 0.0, 0.025), "hind_toe": (-0.055, 0.06, 0.006),
    "tail_base": (0, -0.09, 0.13), "tail_mid": (0, -0.11, 0.1), "tail_end": (0, -0.12, 0.08),
}
R = {
    "rump": (0.12, 0.11, 0.12), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.13, 0.12, 0.14), "belly_drop": 0.0,
    "chest": (0.11, 0.1, 0.11), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.06,
    "neck_base": 0.075, "neck_top": 0.065, "neck_blend": 0.04,
    "skull": (0.062, 0.066, 0.062), "head_blend": 0.03,
    "snout_root": (0, 0.04, -0.008), "snout_base": 0.018, "snout_end": 0.007, "snout_blend": 0.01,
    "jaw_base": 0.011, "jaw_end": 0.004, "jaw_blend": 0.004,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.03, 0.03, 0.03), "scapula_up": 0.0,
    "upper_arm": (0.026, 0.022), "forearm": (0.02, 0.014), "front_paw": (0.012, 0.006),
    "thigh": (0.04, 0.04, 0.04), "thigh_drop": 0.0,
    "upper_leg": (0.024, 0.02), "shin": (0.018, 0.015), "hind_paw": (0.016, 0.006),
    "limb_blend": 0.02, "joint_blend": 0.008,
    "tail": (0.03, 0.02, 0.01), "tail_blend": 0.015,
}

COLORS = {"black": "#1d1c20", "white": "#f6f4ef", "pink": "#f08a9a", "foot": "#2c2a2e"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("black")
    # White front, from the chin down.
    front = p.smooth(n[:, 1], 0.05, 0.3) * p.smooth(0.5 - v[:, 2], 0.0, 0.02) * (Wt("torso") + Wt("neck"))
    p.blend("white", np.clip(front, 0, 1))
    # The black horseshoe band across the chest, and a few spots.
    band = p.smooth(0.012 - np.abs(np.sqrt(v[:, 0] ** 2 + (v[:, 2] - 0.42) ** 2 * 1.0) - 0.075), 0.0, 0.006)
    p.blend("black", band * front * p.smooth(0.44 - v[:, 2], 0.0, 0.01))
    p.spots("black", cell=0.05, radius=0.008, mask=front * p.smooth(0.36 - v[:, 2], 0.0, 0.02) * 0.9, seed=4)
    # White stripe from above the eye curving down the side of the head.
    head = Wt("head") + Wt("neck")
    stripe = p.smooth(0.012 - np.abs(np.sqrt((np.abs(v[:, 0]) - 0.0) ** 2 + ((v[:, 1] - 0.02) * 1.2) ** 2 + ((v[:, 2] - 0.5) * 0.9) ** 2) - 0.07), 0.0, 0.008)
    p.blend("white", head * stripe * p.smooth(v[:, 1] + 0.01, 0.0, 0.02) * p.smooth(np.abs(v[:, 0]) - 0.02, 0.0, 0.01))
    p.blend("pink", Wt("head") * p.smooth(0.018 - np.sqrt((np.abs(v[:, 0]) - 0.035) ** 2 + (v[:, 1] - 0.06) ** 2 + (v[:, 2] - 0.575) ** 2), 0.0, 0.008))
    p.region("hind_paw", "foot")
    p.region("web", "foot")
    return p.colors


def make():
    c = quadruped("african_penguins", J, R, paint=paint, tiles_long=0.9)
    c.voxel = 0.0028
    # Flat flippers and webbed feet.
    for side, sx in ((".L", 1), (".R", -1)):
        m = np.array([sx, 1, 1])
        s, e, w = (np.asarray(J[k], float) * m for k in ("shoulder", "elbow", "front_toe"))
        c.shapes.append(plate(s + (0, 0.025, 0), s + (0, -0.025, 0), e + (0, -0.02, 0), 0.008, 0.007, "front_upper", "fl_upper" + side, blend=0.01))
        c.shapes.append(plate(e + (0, 0.025, 0), e + (0, -0.025, 0), w, 0.007, 0.006, "front_lower", "fl_lower" + side, blend=0.01))
        h, t = np.asarray(J["hock"], float) * m, np.asarray(J["hind_toe"], float) * m
        c.shapes.append(plate(h, t + (-sx * 0.025, 0, 0), t + (sx * 0.02, 0, 0), 0.005, 0.004, "web", "hl_foot" + side, blend=0.006))
    add_face(c, eye_dir=(-0.62, 0.68, 0.3), eye_radius=0.01, eye_sink=0.004, nose_radius=0.0, iris="#3a2a20", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.35, "bump": 0.05, "roughness": 0.5}
    c.motion = {"gait": "biped", "attack": "bite", "rear": 0.0, "stride": 0.7, "wiggle": 0.2, "cycle_tiles": 0.5}
    c.palette = {"eye_line": "#1d1c20"}
    return c
