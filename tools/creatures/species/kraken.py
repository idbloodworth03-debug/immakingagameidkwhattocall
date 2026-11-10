"""Kraken, made a cheeky little sea monster: a round coral-red octopus with
a big bulb of a head, huge friendly eyes, a happy grin and eight curling
tentacles dotted with pale suckers. It crawls along on its tentacles.

Mythical. Built on a four-legged skeleton: four tentacles walk, the others
curl at its sides.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid

J = {
    "pelvis": (0, -0.05, 0.14), "spine_mid": (0, 0.0, 0.15), "withers": (0, 0.05, 0.15),
    "neck_base": (0, 0.03, 0.18), "head_base": (0, 0.0, 0.22), "skull": (0, 0.0, 0.36),
    "snout_tip": (0, 0.16, 0.26), "jaw_hinge": (0, 0.1, 0.22), "chin": (0, 0.15, 0.21),
    "ear_base": (-0.1, 0.0, 0.42), "ear_tip": (-0.101, -0.001, 0.423),
    "shoulder": (-0.08, 0.06, 0.1), "elbow": (-0.2, 0.17, 0.06), "wrist": (-0.3, 0.27, 0.025), "front_toe": (-0.36, 0.36, 0.04),
    "hip": (-0.08, -0.06, 0.1), "knee": (-0.2, -0.17, 0.06), "hock": (-0.3, -0.27, 0.025), "hind_toe": (-0.36, -0.36, 0.04),
    "tail_base": (0, -0.08, 0.1), "tail_mid": (0, -0.22, 0.05), "tail_end": (0, -0.34, 0.06),
}
R = {
    "rump": (0.13, 0.12, 0.08), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.15, 0.15, 0.09), "belly_drop": 0.0,
    "chest": (0.13, 0.12, 0.08), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.05,
    "neck_base": 0.12, "neck_top": 0.14, "neck_blend": 0.06,
    "skull": (0.19, 0.19, 0.2), "head_blend": 0.06,
    "snout_root": (0, 0.06, -0.08), "snout_base": 0.06, "snout_end": 0.04, "snout_blend": 0.04,
    "jaw_base": 0.04, "jaw_end": 0.03, "jaw_blend": 0.02,
    "ear_width": 0.004, "ear_thick": 0.002, "ear_round": 0.002, "ear_yaw": 0.0, "ear_sink": 0.003, "ear_voxel": 0.001,
    "scapula": (0.04, 0.04, 0.04), "scapula_up": 0.0,
    "upper_arm": (0.05, 0.04), "forearm": (0.04, 0.028), "front_paw": (0.028, 0.012),
    "thigh": (0.05, 0.05, 0.05), "thigh_drop": 0.0,
    "upper_leg": (0.05, 0.04), "shin": (0.04, 0.028), "hind_paw": (0.028, 0.012),
    "limb_blend": 0.03, "joint_blend": 0.015,
    "tail": (0.05, 0.035, 0.015), "tail_blend": 0.02,
}
COLORS = {"red": "#e8604a", "dark": "#c2402e", "sucker": "#ffd2b8", "belly": "#ff9a80"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    Wt = p.mesh.region_weight
    p.fill("red")
    p.blend("dark", Wt("head") * p.smooth(n[:, 2], 0.5, 0.3) * 0.5)
    p.spots("dark", cell=0.06, radius=0.012, mask=Wt("head") * 0.6, seed=2)
    arms = sum(Wt(r) for r in ("front_upper", "front_lower", "front_paw", "thigh", "hind_lower", "hind_paw", "tail", "arm"))
    p.spots("sucker", cell=0.03, radius=0.007, mask=np.clip(arms, 0, 1) * p.smooth(-n[:, 2], -0.2, 0.4), seed=3)
    return p.colors


def make():
    c = quadruped("kraken", J, R, paint=paint, tiles_long=1.6)
    c.voxel = 0.004
    # Three more tentacles curling out at the sides and back. (A design may
    # raise them, R arm_lift 0-1: up beside the head and curling over at the
    # tips, the kraken's tentacles reaching up, longer and thicker.)
    lift = R.get("arm_lift", 0.0)
    for side, bone in ((1, "chest"), (-1, "chest"), (1, "hips")):
        y = 0.0 if bone == "chest" else -0.08
        if bone == "hips" and lift > 0:
            side = 0.0
        base = np.array([side * 0.1, y, 0.1])
        mid = base + (side * (0.15 + 0.15 * lift), (-0.05 if bone == "hips" else 0.0) - 0.15 * lift * (side == 0), -0.06 + 0.22 * lift)
        tip = mid + (side * (0.12 - 0.02 * lift), 0.08 - 0.06 * lift, 0.04 + 0.3 * lift)
        r = 1.0 + 0.4 * lift
        c.shapes.append(cone(base, mid, 0.05 * r, 0.035 * r, "arm", bone, blend=0.03))
        c.shapes.append(cone(mid, tip, 0.035 * r, 0.015 * r + 0.01 * lift, "arm", bone, blend=0.02))
        if lift > 0:
            curl = tip + np.array([-side * 0.07, 0.03, 0.07]) * lift
            c.shapes.append(cone(tip, curl, 0.015 * r + 0.01 * lift, 0.012, "arm", bone, blend=0.015))
    add_face(c, eye_dir=(-0.45, 0.85, 0.0), eye_radius=0.03, eye_sink=0.01, nose_radius=0.0, iris="#2a1a12", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.45, "bump": 0.05, "roughness": 0.4, "subsurface": 0.15}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.3, "stride": 1.0, "wiggle": 0.1, "cycle_tiles": 0.7}
    c.cartoon = {"head": 1.0}
    return c
