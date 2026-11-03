"""Virginia opossum: a cat-sized marsupial with a grizzled gray coat, a
white face with a long pink pointed nose, round black hairless ears, black
legs with pink toes and a long, bare, pink-gray tail.

Real size: about 75 cm long including the tail.
Built from the raccoon's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import raccoon as RC

J = dict(RC.J)
J.update({"snout_tip": (0, 0.395, 0.24), "chin": (0, 0.35, 0.232), "ear_base": (-0.036, 0.26, 0.32),
          "ear_tip": (-0.05, 0.255, 0.355), "tail_mid": (0, -0.42, 0.2), "tail_end": (0, -0.56, 0.12)})
R = dict(RC.R)
R.update({"snout_base": 0.026, "snout_end": 0.009, "ear_width": 0.04, "ear_round": 0.018, "ear_thick": 0.003,
          "tail": (0.02, 0.013, 0.009, 0.005), "tail_blend": 0.012})

COLORS = {"gray": "#8e8b88", "frost": "#d9d6d0", "white": "#f2efe9", "black": "#211e1e", "pink": "#e9a9ae", "tail": "#d8b9b4"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("gray")
    p.where("frost", lambda v, n: p.smooth(n[:, 2], 0.3, 0.4), 0.45)
    for region in ("head", "snout", "jaw", "cheek"):
        p.region(region, "white", 0.95)
    p.region_where("snout", "pink", lambda v, n: p.smooth(v[:, 1] - 0.38, 0.0, 0.01))
    p.region("ear", "black")
    for leg in ("front_lower", "hind_lower", "front_paw", "hind_paw"):
        p.region(leg, "black", 0.9)
    p.region_where("front_paw", "pink", lambda v, n: p.smooth(v[:, 1] - 0.17, 0.0, 0.015), 0.8)
    p.region_where("hind_paw", "pink", lambda v, n: p.smooth(v[:, 1] + 0.14, 0.0, 0.015), 0.8)
    p.region("tail", "tail")
    p.region("tail_tip", "tail")
    p.region_where("tail", "black", lambda v, n: p.smooth(v[:, 1] + 0.33, 0.0, 0.03) * p.smooth(-0.27 - v[:, 1], -0.1, 0.1), 0.6)
    p.speckle(0.2)
    return p.colors


def make():
    c = quadruped("opossum", J, R, paint=paint, tiles_long=1.2)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.04, 0.27, 0.262), (0.03, 0.036, 0.03), "cheek", "head", blend=0.03, yaw=side * 0.4))
    add_face(c, eye_dir=(-0.55, 0.78, 0.25), eye_radius=0.0085, eye_sink=0.005, nose_radius=0.0065, nose_sink=0.003,
             iris="#141010", pupil="round")
    c.extras[-1].color = "#e08f98"
    c.fur = {"variation": 0.25, "sheen": 0.25, "bump": 0.3, "length": 0.028, "density": 60000, "hair_gamma": 1.9,
             "frizz": 0.004, "lengths": {"tail": 0.0, "tail_tip": 0.0, "ear": 0.0, "snout": 0.4}}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 1.1, "gape": 0.9}
    c.palette = {"eye_line": "#151210"}
    return c
