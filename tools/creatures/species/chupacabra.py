"""Chupacabra, made goofy rather than spooky: a small, skinny, gray-green
dog-like critter with big round amber eyes, big ears and a row of purple
spines down its back to the tip of its tail.

Mythical. Built from the coyote (many "chupacabras" turned out to be
coyotes with mange).
"""
import numpy as np

from anatomy import Extra
import coyote_pack as CP
import wolf_pack as W
from derive import recolor

COLORS = {"gray": "#8aa08b", "saddle": "#607862", "cream": "#d6e4cf", "tan": "#9cb296", "dark": "#33403a", "ear_inner": "#e9b9c6"}


def make():
    c = CP.make()
    c.name = "chupacabra"
    c.paint = recolor(W, COLORS)
    # A row of spines from the neck down the back and tail.
    pts = [np.asarray(CP.J[k], float) for k in ("neck_base", "withers", "spine_mid", "pelvis", "tail_base", "tail_mid")]
    bones = ["neck", "chest", "chest", "hips", "tail1", "tail2"]
    radius = [0.13, 0.17, 0.13, 0.12, 0.05, 0.05]
    for i in range(len(pts) - 1):
        for u in (0.0, 0.5):
            at = pts[i] + (pts[i + 1] - pts[i]) * u
            r = radius[i] + (radius[i + 1] - radius[i]) * u
            base = at + (0, 0, r * 0.9)
            c.extras.append(Extra("cone", "horn", bones[i], center=tuple(base), tip=tuple(base + (0, -0.04, 0.09 * (1.2 - i * 0.12))),
                                  radius=0.025, tip_radius=0.004, color="#9a5fd0"))
    for e in c.extras:
        if e.material == "eye":
            e.color = "#f0a830"
    c.tiles_long = 1.2
    c.motion = dict(c.motion, attack="pounce_bite", stride=1.2)
    return c
