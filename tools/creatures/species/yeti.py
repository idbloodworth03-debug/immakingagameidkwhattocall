"""Yeti, made cuddly: a big, shaggy, snow-white ape standing upright with a
round pale-blue face, a friendly grin, little rounded horns peeking out of
its fur, huge pale-blue hands and feet, and a frosty sheen.

Mythical. Built from the gorilla's upright body.
"""
import numpy as np

from anatomy import Extra
from paint import Painter
import mountain_gorilla as G

COLORS = {"fur": "#f1f4f7", "shade": "#c9d6e2", "face": "#9fc3e0", "palm": "#8fb4d6"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("fur")
    p.blend("shade", p.smooth(-n[:, 2], 0.0, 0.5) * 0.5)
    for region in ("face", "snout", "jaw"):
        p.region(region, "face")
    p.region("front_paw", "palm", 0.9)
    p.region("hind_paw", "palm", 0.9)
    p.speckle(0.05)
    return p.colors


def make():
    c = G.make()
    c.name = "yeti"
    c.paint = paint
    c.tiles_long = 1.9
    sk = np.asarray(G.J["skull"], float)
    for side in (1, -1):
        base = sk + (side * 0.07, -0.01, 0.08)
        c.extras.append(Extra("cone", "horn", "head", center=tuple(base), tip=tuple(base + (side * 0.04, -0.02, 0.06)),
                              radius=0.022, tip_radius=0.008, color="#d9e6f2"))
    c.fur = dict(c.fur, sheen=0.35)
    c.motion = dict(c.motion, attack="stomp", stride=0.85)
    c.motion.pop("special", None)  # not a Stun animal like the gorilla it's built from
    c.palette = {"eye_line": "#5a7a96", "mouth": "#5a6a8a"}
    return c
