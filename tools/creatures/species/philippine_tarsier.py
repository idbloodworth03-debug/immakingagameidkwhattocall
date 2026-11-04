"""Philippine tarsier: one of the smallest primates, a fluffy gray-brown
ball with gigantic round golden eyes, a tiny nose, big thin ears that swivel,
long skinny fingers, long hind legs for leaping and a long thin bare tail
with a tuft. It sits upright and hops.

Real size: about 12 cm tall, plus a 23 cm tail.
Built standing up like the primates.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, 0.0, 0.07), "spine_mid": (0, 0.0, 0.1), "withers": (0, 0.0, 0.13),
    "neck_base": (0, 0.0, 0.14), "head_base": (0, 0.005, 0.15), "skull": (0, 0.01, 0.175),
    "snout_tip": (0, 0.045, 0.165), "jaw_hinge": (0, 0.02, 0.16), "chin": (0, 0.04, 0.155),
    "ear_base": (-0.022, 0.0, 0.19), "ear_tip": (-0.034, -0.005, 0.215),
    "shoulder": (-0.028, 0.005, 0.125), "elbow": (-0.036, 0.015, 0.1), "wrist": (-0.036, 0.03, 0.08), "front_toe": (-0.036, 0.045, 0.07),
    "hip": (-0.02, 0.0, 0.065), "knee": (-0.03, 0.03, 0.045), "hock": (-0.03, 0.0, 0.012), "hind_toe": (-0.03, 0.03, 0.003),
    "tail_base": (0, -0.025, 0.06), "tail_mid": (0, -0.08, 0.03), "tail_end": (0, -0.14, 0.02),
}
R = {
    "rump": (0.028, 0.026, 0.028), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.03, 0.028, 0.032), "belly_drop": 0.0,
    "chest": (0.027, 0.025, 0.027), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.015,
    "neck_base": 0.018, "neck_top": 0.018, "neck_blend": 0.01,
    "skull": (0.026, 0.024, 0.024), "head_blend": 0.008,
    "snout_root": (0, 0.012, -0.006), "snout_base": 0.008, "snout_end": 0.005, "snout_blend": 0.005,
    "jaw_base": 0.005, "jaw_end": 0.003, "jaw_blend": 0.002,
    "ear_width": 0.016, "ear_thick": 0.0015, "ear_round": 0.007, "ear_yaw": 0.2, "ear_sink": 0.002, "ear_voxel": 0.0006,
    "scapula": (0.008, 0.008, 0.008), "scapula_up": 0.0,
    "upper_arm": (0.006, 0.005), "forearm": (0.005, 0.004), "front_paw": (0.005, 0.004),
    "thigh": (0.012, 0.012, 0.014), "thigh_drop": 0.0,
    "upper_leg": (0.009, 0.007), "shin": (0.006, 0.005), "hind_paw": (0.005, 0.004),
    "limb_blend": 0.004, "joint_blend": 0.002,
    "tail": (0.003, 0.0025, 0.002, 0.004), "tail_blend": 0.002,
}
COLORS = {"fur": "#9a8a78", "light": "#c9bba8", "ear": "#d9b4a4", "tail": "#7a6a5c"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("fur")
    p.blend("light", p.smooth(p.n[:, 1], 0.3, 0.4) * p.mesh.region_weight("torso") * 0.6)
    p.region("ear", "ear", 0.7)
    p.region("tail", "tail")
    p.speckle(0.08)
    return p.colors


def make():
    c = quadruped("philippine_tarsier", J, R, paint=paint, tiles_long=0.8)
    c.voxel = 0.0009
    te = np.asarray(J["tail_end"], float)
    c.shapes.append(ellipsoid(tuple(te), (0.006, 0.014, 0.006), "tail_tip", "tail3", blend=0.003))
    # The famous enormous eyes.
    add_face(c, eye_dir=(-0.4, 0.88, 0.2), eye_radius=0.0085, eye_sink=0.003, nose_radius=0.003, nose_sink=0.001,
             iris="#c9902a", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.2, "roughness": 0.65}
    c.motion = {"gait": "biped", "attack": "swipe", "rear": 0.0, "stride": 1.2, "cycle_tiles": 0.6}
    # A Stun animal: a big wind-up before the blow that stuns.
    c.motion["special"] = True
    return c
