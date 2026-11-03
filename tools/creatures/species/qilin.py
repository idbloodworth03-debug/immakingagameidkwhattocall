"""Qilin: the gentle chimera of Chinese legend, made cute: a deer-like body
covered in jade green scales, a cream belly, a flowing golden mane and tail
tuft, small golden antlers and golden hooves. It calls down lightning.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from pegasus import J as HJ, R as HR
from sdf import ellipsoid

J = dict(HJ)
R = dict(HR, tail=(0.04, 0.04, 0.05, 0.06))
COLORS = {"jade": "#4fbf8a", "scale": "#2f8f66", "cream": "#f3e9c8", "gold": "#f2c84a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("jade")
    body = p.mesh.region_weight("torso") + p.mesh.region_weight("neck")
    p.spots("scale", cell=0.06, radius=0.022, ring=0.4, mask=body * p.smooth(n[:, 2], -0.2, 0.4))
    p.blend("cream", p.smooth(-n[:, 2], 0.3, 0.4) * 0.9)
    mane = p.mesh.region_weight("mane") + p.mesh.region_weight("tail_tip")
    p.blend("gold", mane)
    p.region("front_paw", "gold")
    p.region("hind_paw", "gold")
    return p.colors


def make():
    c = quadruped("qilin", J, R, paint=paint, tiles_long=2.2)
    c.voxel = 0.01
    neck = np.asarray(J["neck_base"], float), np.asarray(J["head_base"], float)
    for u in np.linspace(0.0, 1.0, 6):
        at = neck[0] + (neck[1] - neck[0]) * u + np.array([0, -0.1, 0.08])
        c.shapes.append(ellipsoid(tuple(at), (0.05, 0.09, 0.08), "mane", "neck", blend=0.05, pitch=0.6))
    sk = np.asarray(J["skull"], float)
    for side in (1, -1):
        base = sk + np.array([side * 0.045, -0.01, 0.08])
        top = base + np.array([side * 0.03, -0.05, 0.13])
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(top), radius=0.014, tip_radius=0.004, color="#f2c84a"))
        fork = base + (top - base) * 0.55
        c.extras.append(Extra("cone", "horn", "head", center=tuple(fork), tip=tuple(fork + np.array([side * 0.04, 0.03, 0.04])),
                              radius=0.009, tip_radius=0.003, color="#f2c84a"))
    add_face(c, eye_dir=(-0.75, 0.5, 0.35), eye_radius=0.02, eye_sink=0.008, nose_radius=0, iris="#3a6a2a", pupil="round")
    c.cartoon = {"head": 1.6}
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.35, "bump": 0.15, "roughness": 0.5}
    c.motion = {"gait": "trot", "attack": "stomp", "rear": 0.3, "stride": 1.0}
    return c
