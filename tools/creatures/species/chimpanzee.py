"""Chimpanzee, walking upright: black fur, a light peach face with big ears
sticking out, and long arms. It throws stones.

Real size: about 1.2 m standing.
"""
from anatomy import add_face, quadruped
from bonobo import J as BJ, R as BR, make as _bonobo
from paint import Painter

J = dict(BJ, ear_base=(-0.066, 0.02, 0.83), ear_tip=(-0.1, 0.012, 0.86))
R = dict(BR, ear_width=0.05, ear_round=0.02)
COLORS = {"fur": "#2a2524", "face": "#d9b39a", "lips": "#c98a80", "palm": "#b89480"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("fur")
    for region in ("face", "snout", "jaw"):
        p.region(region, "face")
    p.region("ear", "face", 0.8)
    p.region_where("jaw", "lips", lambda v, n: p.smooth(v[:, 1] - 0.09, 0.0, 0.006), 0.6)
    p.region("front_paw", "palm", 0.6)
    p.region("hind_paw", "palm", 0.6)
    return p.colors


def make():
    c = _bonobo()
    b = quadruped("chimpanzee", J, R, paint=paint, tiles_long=1.3)
    b.shapes += [s for s in c.shapes if s.region == "face"]
    b.voxel = c.voxel
    add_face(b, eye_dir=(-0.33, 0.92, 0.06), eye_radius=0.013, eye_sink=0.006, nose_radius=0.01, nose_sink=0.004,
             iris="#3b2412", pupil="round")
    b.fur, b.motion, b.palette = c.fur, dict(c.motion), dict(c.palette)
    return b
