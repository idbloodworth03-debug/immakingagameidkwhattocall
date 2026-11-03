"""Sumatran orangutan, a big male standing up: long shaggy orange hair, very
long arms, a grey face framed by wide cheek pads, and a pale beard. It
throws fruit.

Real size: about 1.4 m standing.
"""
import numpy as np

from anatomy import add_face, quadruped
from bonobo import J as BJ, R as BR
from paint import Painter
from sdf import ellipsoid

J = dict(BJ, elbow=(-0.19, 0.03, 0.46), wrist=(-0.21, 0.07, 0.26), front_toe=(-0.21, 0.1, 0.19),
         ear_base=(-0.06, 0.02, 0.83), ear_tip=(-0.07, 0.016, 0.84))
R = dict(BR, upper_arm=(0.05, 0.04), forearm=(0.04, 0.035), front_paw=(0.04, 0.036),
         belly=(0.13, 0.1, 0.11), chest=(0.14, 0.09, 0.11))
COLORS = {"orange": "#c8642a", "deep": "#9a4a1e", "face": "#6f625a", "pad": "#8a7a70", "beard": "#e0a070"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("orange")
    p.blend("deep", p.smooth(-p.n[:, 2], 0.2, 0.4) * 0.4)
    for region in ("face", "snout", "jaw"):
        p.region(region, "face")
    p.region("pad", "pad")
    p.region("beard", "beard")
    return p.colors


def make():
    c = quadruped("sumatran_orangutan", J, R, paint=paint, tiles_long=1.5)
    c.voxel = 0.004
    c.shapes.append(ellipsoid((0, 0.094, 0.812), (0.056, 0.026, 0.056), "face", "head", blend=0.02))
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.075, 0.07, 0.81), (0.03, 0.02, 0.06), "pad", "head", blend=0.02))
    c.shapes.append(ellipsoid((0, 0.08, 0.735), (0.04, 0.03, 0.035), "beard", "jaw", blend=0.02))
    add_face(c, eye_dir=(-0.3, 0.93, 0.06), eye_radius=0.012, eye_sink=0.006, nose_radius=0.009, nose_sink=0.004,
             iris="#3b2412", pupil="round")
    c.fur = {"strands": False, "variation": 0.2, "sheen": 0.3, "bump": 0.4, "roughness": 0.7}
    c.motion = {"gait": "biped", "attack": "throw", "rear": 0.0, "stride": 0.9, "cycle_tiles": 0.9}
    c.palette = {"eye_line": "#2a201c", "mouth": "#6a3a34"}
    return c
