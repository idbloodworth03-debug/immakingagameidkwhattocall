"""Wild Bactrian camel: a tall, long-legged desert camel with two humps, a
long curved neck, shaggy darker hair on the humps, neck and legs, and a
droopy-lipped face. It spits.

Real size: about 2 m at the humps.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from pegasus import J as HJ, R as HR
from sdf import ellipsoid

J = dict(HJ, neck_base=(0, 0.33, 0.95), head_base=(0, 0.62, 1.2), skull=(0, 0.66, 1.22),
         snout_tip=(0, 0.86, 1.16), jaw_hinge=(0, 0.67, 1.14), chin=(0, 0.84, 1.1),
         ear_base=(-0.05, 0.64, 1.28), ear_tip=(-0.07, 0.62, 1.31))
R = dict(HR, neck_base=0.1, neck_top=0.07, skull=(0.075, 0.1, 0.075), snout_base=0.06, snout_end=0.05,
         ear_width=0.04, ear_round=0.015)
COLORS = {"sand": "#c9a46a", "shag": "#9a7240", "light": "#e2c896"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("sand")
    p.blend("light", p.smooth(-p.n[:, 2], 0.3, 0.4) * 0.5)
    p.region("hump", "shag")
    p.region("neck", "shag", 0.5)
    p.region("snout", "light", 0.6)
    return p.colors


def make():
    c = quadruped("wild_bactrian_camel", J, R, paint=paint, tiles_long=2.4)
    c.voxel = 0.01
    # The two humps (a design may make them bigger: R hump, hump_at, hump_z).
    for y in R.get("hump_at", (0.12, -0.18)):
        c.shapes.append(ellipsoid((0, y, R.get("hump_z", 1.1)), tuple(R.get("hump", (0.13, 0.13, 0.2))), "hump",
                                  "chest" if y > 0 else "hips", blend=0.07))
    add_face(c, eye_dir=(-0.75, 0.5, 0.35), eye_radius=0.017, eye_sink=0.007, nose_radius=0, iris="#2a1a10", pupil="round")
    c.cartoon = {"head": 1.6}
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.2, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "spit", "gape": 0.4, "stride": 1.0}
    return c
