"""Gaur: the biggest wild cattle, a towering dark bull with a high ridge
over the shoulders, a pale gray-gold forehead, curved horns that sweep up
and in, and white "socks" on all four legs. Short glossy coat.

Real size: about 1.9 m at the shoulder.
Built from the bison's skeleton, with short hair and a ridge, not a hump.
"""
import numpy as np

from anatomy import Extra, add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import american_bison as B

J = dict(B.J)
R = dict(B.R)

COLORS = {"body": "#2e1f17", "dark": "#1a110c", "brow": "#b5a37a", "sock": "#efe7d4", "horn": "#cdbb94"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("body")
    p.top_darken("dark", start=0.3, strength=0.4)
    p.blend("brow", p.mesh.region_weight("head") * p.smooth(n[:, 2] + n[:, 1] * 0.4, 0.5, 0.3) * 0.8)
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw"):
        p.region_where(leg, "sock", lambda v, n: p.smooth(0.4 - v[:, 2], 0.0, 0.08))
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("gaur", J, R, paint=paint, tiles_long=2.6)
    c.voxel = 0.01
    # The ridge over the shoulders, sloping down to the back.
    c.shapes.append(ellipsoid((0, 0.25, 1.62), (0.18, 0.55, 0.22), "torso", "chest", blend=0.14, pitch=0.2))
    c.shapes.append(ellipsoid((0, 1.0, 1.0), (0.22, 0.12, 0.12), "head", "head", blend=0.08))
    for side in (1, -1):
        base = np.array([side * 0.18, 0.99, 1.04])
        mid = np.array([side * 0.32, 0.98, 1.16])
        tip = np.array([side * 0.24, 1.04, 1.3])
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(mid), radius=0.055, tip_radius=0.04, color="#cdbb94"))
        c.extras.append(Extra("cone", "horn", "head", center=tuple(mid), tip=tuple(tip), radius=0.04, tip_radius=0.008, color="#2a221c"))
    add_face(c, eye_dir=(-0.75, 0.6, 0.25), eye_radius=0.022, eye_sink=0.014, nose_radius=0.055, nose_sink=0.03,
             iris="#1a0f08", pupil="round")
    c.fur = {"strands": False, "variation": 0.08, "sheen": 0.4, "bump": 0.2, "roughness": 0.5}
    c.motion = {"gait": "walk", "attack": "charge", "stride": 0.9, "charge_reach": 0.3}
    c.cartoon = {"head": 1.4}
    return c
