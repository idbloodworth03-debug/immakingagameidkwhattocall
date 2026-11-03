"""Baku, the dream-eater of Japanese folklore, made sweet: a plump tapir-like
creature in dreamy pastel lavender with a cream "blanket" over its back
sprinkled with little gold stars, a curling trunk and two tiny tusks.

Mythical. Built from the Malayan tapir.
"""
import numpy as np

from anatomy import Extra
from paint import Painter
import malayan_tapir as T

COLORS = {"lavender": "#b6a2e6", "cream": "#fbf3ff", "rim": "#fff6d8", "trunk": "#9f86d8", "star": "#ffd75a", "pink": "#f5b6d6"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    Wt = p.mesh.region_weight
    p.fill("lavender")
    saddle = Wt("torso") * p.smooth(0.12 - v[:, 1], 0.0, 0.04) * p.smooth(v[:, 1] + 0.58, 0.0, 0.04) * p.smooth(v[:, 2] - 0.42, 0.0, 0.04)
    p.blend("cream", saddle)
    p.spots("star", cell=0.07, radius=0.012, mask=saddle, seed=5)
    p.region_where("ear", "pink", lambda v, n: p.smooth(n[:, 1], 0.2, 0.4), 0.8)
    p.region("trunk", "trunk")
    return p.colors


def make():
    c = T.make()
    c.name = "baku"
    c.paint = paint
    tip = np.asarray(T.J["snout_tip"], float)
    for side in (1, -1):
        base = tip + (side * 0.04, -0.06, -0.06)
        c.extras.append(Extra("cone", "tusk", "head", center=tuple(base), tip=tuple(base + (side * 0.01, 0.03, -0.05)),
                              radius=0.014, tip_radius=0.004, color="#fff8e8"))
    c.tiles_long = 2.0
    c.motion = dict(c.motion, attack="charge")
    return c
