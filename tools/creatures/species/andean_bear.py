"""Andean bear (spectacled bear): South America's only bear, smaller than a
brown bear, with a shaggy black coat and cream "spectacle" markings round
its eyes running down the muzzle onto the throat and chest.

Real size: about 75 cm at the shoulder.
Built from the brown bear's skeleton, without the hump.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import brown_bear as B

J = dict(B.J)
J.update({"withers": (0, 0.4, 1.0), "snout_tip": (0, 1.1, 0.8)})
R = dict(B.R)
R.update({"skull": (0.15, 0.15, 0.135), "snout_base": 0.085, "snout_end": 0.055})

COLORS = {"black": "#1e1a18", "cream": "#e9d6a8", "muzzle": "#cdb487", "nose": "#151110"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    Wt = p.mesh.region_weight
    p.fill("black")
    # Cream rings round the eyes, running down the muzzle and onto the chest.
    for center, radius in creature.eyes:
        d = np.linalg.norm(v - center, axis=1)
        p.blend("cream", (Wt("head") + Wt("cheek")) * p.smooth(radius * 3.2 - d, 0.0, radius * 0.6)
                * p.smooth(d - radius * 1.8, 0.0, radius * 0.5))
    p.region("snout", "muzzle", 0.9)
    p.region("jaw", "cream", 0.8)
    p.blend("cream", Wt("neck") * p.smooth(-n[:, 2] + n[:, 1] * 0.6, 0.3, 0.3) * 0.9)
    p.blend("cream", Wt("torso") * p.smooth(v[:, 1] - 0.45, 0.0, 0.08) * p.smooth(0.12 - np.abs(v[:, 0]), 0.0, 0.05)
            * p.smooth(0.85 - v[:, 2], 0.0, 0.08) * 0.8)
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("andean_bear", J, R, paint=paint, tiles_long=2.0)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.11, 0.86, 0.84), (0.085, 0.1, 0.09), "cheek", "head", blend=0.06))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.017, eye_sink=0.012, nose_radius=0.036, nose_sink=0.016,
             iris="#4a2a14", pupil="round")
    c.fur = dict(B.make().fur)
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.35, "stride": 0.9}
    return c
