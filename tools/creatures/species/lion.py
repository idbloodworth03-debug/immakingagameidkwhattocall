"""Lion (male): big tawny cat, longer-legged than a tiger, broad muzzle,
small round ears half hidden in a great mane that runs from golden around
the face to dark brown at the chest and shoulders. Paler belly and muzzle,
black tuft at the end of the tail.

Real size: about 1.2 m at the shoulder, 2 m head and body, 90 cm tail.
"""
import numpy as np

from anatomy import Extra, add_face, add_mouth, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.58, 1.02),
    "spine_mid": (0, -0.05, 1.0),
    "withers": (0, 0.47, 1.07),
    "neck_base": (0, 0.55, 0.98),
    "head_base": (0, 0.76, 1.04),
    "skull": (0, 0.84, 1.05),
    "snout_tip": (0, 1.04, 0.96),
    "jaw_hinge": (0, 0.84, 0.96),
    "chin": (0, 0.98, 0.89),
    "ear_base": (-0.1, 0.8, 1.17),
    "ear_tip": (-0.125, 0.785, 1.27),
    "shoulder": (-0.14, 0.52, 0.82),
    "elbow": (-0.15, 0.4, 0.56),
    "wrist": (-0.14, 0.45, 0.13),
    "front_toe": (-0.14, 0.56, 0.035),
    "hip": (-0.15, -0.59, 0.92),
    "knee": (-0.16, -0.4, 0.62),
    "hock": (-0.15, -0.76, 0.22),
    "hind_toe": (-0.14, -0.65, 0.035),
    "tail_base": (0, -0.76, 0.96),
    "tail_mid": (0, -1.06, 0.62),
    "tail_end": (0, -1.28, 0.42),
}

R = {
    "rump": (0.19, 0.28, 0.21), "rump_back": 0.02, "rump_drop": 0.16,
    "belly": (0.205, 0.55, 0.2), "belly_drop": 0.2,
    "chest": (0.22, 0.33, 0.28), "chest_back": 0.08, "chest_drop": 0.25,
    "torso_blend": 0.16,
    "neck_base": 0.21, "neck_top": 0.16, "neck_blend": 0.13,
    "skull": (0.15, 0.155, 0.14), "skull_pitch": -0.05, "head_blend": 0.07,
    "snout_root": (0, 0.1, -0.045), "snout_base": 0.1, "snout_end": 0.076, "snout_blend": 0.05,
    "jaw_base": 0.07, "jaw_end": 0.046, "jaw_blend": 0.025,
    "ear_width": 0.09, "ear_thick": 0.008, "ear_round": 0.032, "ear_yaw": 0.45, "ear_sink": 0.03,
    "ear_voxel": 0.003, "ear_fur": 0.012,
    "scapula": (0.1, 0.15, 0.21), "scapula_up": 0.13, "scapula_pitch": 0.3,
    "upper_arm": (0.15, 0.105), "forearm": (0.095, 0.074), "front_paw": (0.076, 0.07),
    "thigh": (0.17, 0.26, 0.27), "thigh_drop": 0.12, "thigh_pitch": -0.25,
    "upper_leg": (0.15, 0.09), "shin": (0.075, 0.058), "hind_paw": (0.064, 0.062),
    "limb_blend": 0.12, "joint_blend": 0.04,
    "tail": (0.055, 0.045, 0.04, 0.06), "tail_blend": 0.05,
}

COLORS = {
    "tawny": "#ad7a3c",
    "back": "#8f6230",
    "pale": "#dcc59c",
    "mane": "#8a5e2c",
    "mane_dark": "#3f2814",
    "black": "#1a1310",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("tawny")
    p.top_darken("back", start=0.35, strength=0.4)
    p.region_underside("torso", "pale", below=-0.4, soft=0.3, strength=0.8)
    p.region("jaw", "pale")
    p.region_where("snout", "pale", lambda v, n: p.smooth(-n[:, 2], -0.25, 0.35))
    # Mane: golden near the face, darker toward the chest and shoulders.
    mane = p.mesh.region_weight("mane")
    p.blend("mane", mane)
    p.blend("mane_dark", mane * p.smooth(0.84 - v[:, 1], 0.0, 0.2) * 0.8)
    p.blend("mane_dark", mane * p.smooth(-n[:, 2], 0.2, 0.4) * 0.6)
    # Keep the face itself tawny.
    face = p.mesh.region_weight("head") + p.mesh.region_weight("snout") + p.mesh.region_weight("cheek")
    p.blend("tawny", face * p.smooth(v[:, 1] - 0.79, 0.0, 0.03))
    p.region_where("snout", "pale", lambda v, n: p.smooth(-n[:, 2], -0.25, 0.35))
    p.region("tail_tip", "black")
    p.region("ear", "back")
    p.region_where("ear", "black", lambda v, n: p.smooth(-n[:, 1], 0.3, 0.3), 0.6)
    p.speckle(0.07)
    return p.colors


def make():
    c = quadruped("lion", J, R, paint=paint, tiles_long=2.4)
    c.voxel = 0.007
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.09, 0.86, 0.96), (0.07, 0.08, 0.075), "cheek", "head", blend=0.05))
    # The mane: a big ruff framing the face, a beard under the chin, and a
    # shaggy mass down the neck to the chest.
    c.shapes.append(ellipsoid((0, 0.72, 1.02), (0.28, 0.11, 0.25), "mane", "neck", blend=0.08, pitch=0.25))
    c.shapes.append(ellipsoid((0, 0.6, 0.98), (0.24, 0.2, 0.28), "mane", "neck", blend=0.09, pitch=0.5))
    c.shapes.append(ellipsoid((0, 0.63, 0.75), (0.18, 0.14, 0.18), "mane", "chest", blend=0.08))
    c.shapes.append(ellipsoid((0, 0.85, 0.85), (0.11, 0.09, 0.09), "mane", "head", blend=0.05))
    # A mouth to roar and bite with, and the fangs.
    add_mouth(c, center=(0, 1.01, 0.915), radii=(0.15, 0.11, 0.012), blend=0.006)
    for side in (1, -1):
        c.extras.append(Extra("cone", "tusk", "head", center=(side * 0.04, 1.04, 0.922), tip=(side * 0.042, 1.045, 0.875),
                              radius=0.011, tip_radius=0.002))
        c.extras.append(Extra("cone", "tusk", "jaw", center=(side * 0.035, 1.0, 0.908), tip=(side * 0.036, 1.005, 0.945),
                              radius=0.008, tip_radius=0.002))
    add_face(c, eye_dir=(-0.45, 0.84, 0.3), eye_radius=0.017, eye_sink=0.01, nose_radius=0.025, nose_sink=0.01,
             iris="#b8822e", pupil="round")
    c.extras[-1].color = "#7a4a3a"
    c.fur = {"variation": 0.1, "sheen": 0.3, "bump": 0.25, "length": 0.03, "density": 13000, "hair_gamma": 2.1,
             "lengths": {"mane": 5.5, "cheek": 1.4, "tail_tip": 3.0, "neck": 1.3}, "clump": 0.55, "frizz": 0.006}
    c.motion = {"gait": "walk", "attack": "pounce_bite", "stride": 1.0, "gape": 0.8}
    return c
