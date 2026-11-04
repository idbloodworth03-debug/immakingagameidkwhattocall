"""Fenrir, the giant wolf of Norse myth, made noble rather than scary: a
huge silver-blue wolf with a thick frosty ruff, icy blue eyes and the magic
golden ribbon that bound him tied round his neck in a bow.

Mythical. Built from the gray wolf.
"""
import numpy as np

from anatomy import Extra, add_face
from sdf import cone, ellipsoid
import wolf_pack as W
from derive import recolor

COLORS = {"gray": "#8fa3b8", "saddle": "#4d5f73", "cream": "#e9f0f6", "tan": "#b6c6d6", "dark": "#2c3846",
          "ear_inner": "#e2ebf3"}


def make():
    c = W.make()
    c.name = "fenrir"

    c.paint = recolor(W, COLORS)
    # The golden ribbon: a band round the neck and a bow under the chin
    # (separate shiny pieces, so the ruff can't swallow them).
    nb, hb = np.asarray(W.J["neck_base"], float), np.asarray(W.J["head_base"], float)
    mid = nb + (hb - nb) * 0.15
    gold = "#f2c24a"
    for a in np.linspace(0, 2 * np.pi, 16, endpoint=False):
        at = mid + np.array([np.sin(a) * 0.23, 0.0, np.cos(a) * 0.23])
        c.extras.append(Extra("ellipsoid", "horn", "neck", center=tuple(at), radii=(0.055, 0.035, 0.055), color=gold))
    bow = mid + (0, 0.16, -0.21)
    for side in (1, -1):
        c.extras.append(Extra("ellipsoid", "horn", "neck", center=tuple(bow + (side * 0.07, 0, 0.01)), radii=(0.07, 0.03, 0.045),
                              color=gold, rot=(0.0, side * 0.4, 0.0)))
        c.extras.append(Extra("cone", "horn", "neck", center=tuple(bow), tip=tuple(bow + (side * 0.05, 0.0, -0.11)),
                              radius=0.02, tip_radius=0.014, color=gold))
    for e in c.extras:
        if e.material == "eye":
            e.color = "#7fd0ff"
    c.tiles_long = 1.9
    c.motion = dict(c.motion, attack="pounce_bite", stride=1.1)
    c.motion.pop("attack2", None)  # one attack (only common animals have two)
    return c
