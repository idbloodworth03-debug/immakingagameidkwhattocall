"""Sea otter: a long, low, furry otter with a pale cream head and face,
dark brown body, small round ears, short front paws, flipper-like back feet
and a flat tail. It throws pebbles.

Real size: about 1.2 m long.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter

J = {
    "pelvis": (0, -0.2, 0.12), "spine_mid": (0, 0.0, 0.13), "withers": (0, 0.17, 0.13),
    "neck_base": (0, 0.22, 0.14), "head_base": (0, 0.28, 0.16), "skull": (0, 0.31, 0.17),
    "snout_tip": (0, 0.38, 0.155), "jaw_hinge": (0, 0.31, 0.14), "chin": (0, 0.37, 0.13),
    "ear_base": (-0.04, 0.3, 0.205), "ear_tip": (-0.045, 0.296, 0.215),
    "shoulder": (-0.05, 0.18, 0.1), "elbow": (-0.06, 0.2, 0.06), "wrist": (-0.055, 0.22, 0.015), "front_toe": (-0.055, 0.25, 0.008),
    "hip": (-0.06, -0.18, 0.1), "knee": (-0.07, -0.14, 0.06), "hock": (-0.07, -0.22, 0.02), "hind_toe": (-0.08, -0.17, 0.008),
    "tail_base": (0, -0.3, 0.11), "tail_mid": (0, -0.4, 0.08), "tail_end": (0, -0.48, 0.05),
}
R = {
    "rump": (0.09, 0.1, 0.08), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.095, 0.16, 0.085), "belly_drop": 0.0,
    "chest": (0.085, 0.1, 0.08), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.06,
    "neck_base": 0.07, "neck_top": 0.06, "neck_blend": 0.04,
    "skull": (0.06, 0.055, 0.05), "head_blend": 0.03,
    "snout_root": (0, 0.035, -0.012), "snout_base": 0.04, "snout_end": 0.025, "snout_blend": 0.02,
    "jaw_base": 0.025, "jaw_end": 0.012, "jaw_blend": 0.01,
    "ear_width": 0.015, "ear_thick": 0.004, "ear_round": 0.006, "ear_yaw": 0.3, "ear_sink": 0.006, "ear_voxel": 0.0015,
    "scapula": (0.03, 0.04, 0.04), "scapula_up": 0.0,
    "upper_arm": (0.03, 0.022), "forearm": (0.02, 0.017), "front_paw": (0.017, 0.015),
    "thigh": (0.04, 0.05, 0.05), "thigh_drop": 0.0,
    "upper_leg": (0.035, 0.025), "shin": (0.022, 0.02), "hind_paw": (0.03, 0.035),
    "limb_blend": 0.03, "joint_blend": 0.012,
    "tail": (0.04, 0.035, 0.025, 0.015), "tail_blend": 0.02,
}
COLORS = {"brown": "#4a3326", "cream": "#ddd0b8", "dark": "#2c1f17"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("brown")
    for region in ("head", "snout", "jaw", "ear"):
        p.region(region, "cream", 0.9)
    p.blend("cream", p.mesh.region_weight("neck") * p.smooth(v[:, 1] - 0.24, 0.0, 0.03))
    p.region("hind_paw", "dark", 0.6)
    return p.colors


def make():
    c = quadruped("sea_otter", J, R, paint=paint, tiles_long=1.3)
    c.voxel = 0.003
    add_face(c, eye_dir=(-0.55, 0.75, 0.3), eye_radius=0.009, eye_sink=0.004, nose_radius=0.009, nose_sink=0.003,
             iris="#1a100a", pupil="round")
    c.fur = {"strands": False, "variation": 0.15, "sheen": 0.35, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "walk", "attack": "throw", "rear": 0.8, "stride": 1.0}
    return c
