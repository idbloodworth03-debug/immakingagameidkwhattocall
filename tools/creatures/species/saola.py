"""Saola: a rare, shy forest antelope with two long, straight, nearly
parallel horns sweeping back, a glossy chestnut-brown coat with a thin
black stripe along the back, bold white marks on the face and white
socks. Discovered only in 1992.

Real size: about 85 cm at the shoulder.
Built from the horse's skeleton (the Pegasus card's), scaled down.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from pegasus import J as HJ, R as HR

K = 0.72
J = {key: tuple(np.asarray(v, float) * K) for key, v in HJ.items()}
R = {key: (tuple(np.asarray(v) * K) if isinstance(v, tuple) else (v if key in ("skull_pitch", "scapula_pitch", "thigh_pitch", "ear_yaw") else v * K))
     for key, v in HR.items()}
R.update({"ear_width": 0.05, "ear_round": 0.02, "tail": (0.03, 0.03, 0.025, 0.015)})

COLORS = {"chestnut": "#6e3b22", "dark": "#2a1912", "white": "#f3eee4"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("chestnut")
    p.blend("dark", p.smooth(np.abs(v[:, 0]) * -1 + 0.012, 0.0, 0.006) * p.smooth(n[:, 2], 0.6, 0.2) * p.mesh.region_weight("torso"))
    # White face marks: a patch above each eye and a band across the muzzle.
    head = p.mesh.region_weight("head")
    p.blend("white", head * p.smooth(0.025 - np.abs(np.abs(v[:, 0]) - 0.045), 0.0, 0.01) * p.smooth(v[:, 2] - 0.82, 0.0, 0.02))
    p.region_where("snout", "white", lambda v, n: p.smooth(0.012 - np.abs(v[:, 1] - 0.5), 0.0, 0.01))
    p.region_where("jaw", "white", lambda v, n: p.smooth(v[:, 1] - 0.48, 0.0, 0.02), 0.8)
    for leg in ("front_paw", "hind_paw"):
        p.region(leg, "white", 0.85)
    p.region("ear", "dark", 0.4)
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("saola", J, R, paint=paint, tiles_long=1.9)
    c.voxel = 0.007
    sk = np.asarray(J["skull"], float)
    for side in (1, -1):
        base = sk + (side * 0.03, -0.01, 0.06)
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(base + (side * 0.02, -0.2, 0.17)),
                              radius=0.014, tip_radius=0.003, color="#2b221d"))
    add_face(c, eye_dir=(-0.75, 0.5, 0.35), eye_radius=0.014, eye_sink=0.007, nose_radius=0.014, nose_sink=0.005,
             iris="#2b1a10", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.4, "bump": 0.15, "roughness": 0.5}
    c.motion = {"gait": "trot", "attack": "charge", "stride": 1.05, "charge_reach": 0.3}
    return c
