"""Pygmy hippo: a small, shy forest hippo, with a rounder back, a smaller
head and narrower muzzle than its big cousin, longer legs and glossy,
greenish-black skin that's pink around the face and belly.

Real size: about 80 cm at the shoulder, 1.6 m long.
Built from the hippo's body.
"""
import hippopotamus as H
from derive import recolor

COLORS = {"skin": "#3f3d36", "top": "#2c2b27", "pink": "#c8968a", "dark": "#1e1c1a"}


def make():
    c = H.make()
    c.name = "pygmy_hippo"
    c.paint = recolor(H, COLORS)
    c.tiles_long = 1.6
    c.cartoon = {"head": 1.3}
    c.fur = dict(c.fur, sheen=0.25, specular=0.6)
    c.motion = dict(c.motion, stride=0.9, gape=1.0)
    return c
