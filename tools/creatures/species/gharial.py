"""Gharial: a long, slim crocodilian with a very long, thin snout full of
little teeth and a round knob (the "ghara") on the tip of the male's nose,
a ridged back and a long ridged tail, short sprawling legs and olive-gray
skin with dark bands. It crawls low along the ground.

Real size: about 5 m long.
Built from the Komodo dragon's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid
import komodo_dragon as K

J = dict(K.J)
J.update({"snout_tip": (0, 1.3, 0.27), "chin": (0, 1.26, 0.24), "jaw_hinge": (0, 0.68, 0.27), "skull": (0, 0.7, 0.33),
          "tail_mid": (0, -1.05, 0.15), "tail_end": (0, -1.5, 0.05)})
R = dict(K.R)
R.update({"skull": (0.1, 0.1, 0.07), "snout_root": (0, 0.08, -0.03), "snout_base": 0.05, "snout_end": 0.035, "snout_blend": 0.03,
          "jaw_base": 0.04, "jaw_end": 0.028, "tail": (0.11, 0.07, 0.035, 0.012)})

COLORS = {"olive": "#6f7552", "dark": "#43482f", "belly": "#d4cfa8", "knob": "#5e5a44"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    p.fill("olive")
    p.stripes("dark", lambda q: q[:, 1], frequency=6.0, width=0.3, wobble=0.4, mask=p.smooth(n[:, 2], -0.2, 0.4) * 0.7)
    p.blend("belly", p.smooth(-n[:, 2], 0.2, 0.4) * 0.8)
    p.region("ridge", "dark", 0.7)
    p.region("knob", "knob")
    p.speckle(0.2)
    return p.colors


def make():
    c = quadruped("gharial", J, R, paint=paint, tiles_long=2.6)
    c.voxel = 0.008
    tip = np.asarray(J["snout_tip"], float)
    c.shapes.append(ellipsoid(tuple(tip + (0, -0.03, 0.03)), (0.055, 0.05, 0.045), "knob", "head", blend=0.02))
    c.shapes.append(ellipsoid(tuple(tip + (0, 0.0, -0.01)), (0.05, 0.04, 0.03), "snout", "head", blend=0.02))
    # Ridges of scutes down the back and tail.
    spine = [np.asarray(J[k], float) for k in ("withers", "spine_mid", "pelvis", "tail_base", "tail_mid", "tail_end")]
    bones = ["chest", "chest", "hips", "tail1", "tail2", "tail3"]
    for i in range(len(spine) - 1):
        for u in np.linspace(0.0, 1.0, 4, endpoint=False):
            at = spine[i] + (spine[i + 1] - spine[i]) * u
            r = 0.12 * (1 - (i + u) / len(spine)) + 0.02
            for x in ((-0.05, 0.05) if i < 3 else (0.0,)):
                base = at + (x, 0.0, r * 0.95)
                c.shapes.append(cone(base, base + (0, -0.02, 0.035), 0.022, 0.006, "ridge", bones[i] if u < 0.5 else bones[i + 1], blend=0.012))
    add_face(c, eye_dir=(-0.55, 0.45, 0.7), eye_radius=0.015, eye_sink=0.006, nose_radius=0.0, iris="#8a7a2a", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.25, "bump": 0.35, "roughness": 0.65}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.9, "wiggle": 0.2, "gape": 0.7, "cycle_tiles": 0.8}
    return c
