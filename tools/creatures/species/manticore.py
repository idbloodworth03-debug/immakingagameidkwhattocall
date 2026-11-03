"""Manticore, made a cute storybook beast: a red-orange lion with a shaggy
crimson mane, little purple bat wings folded on its back and a curly,
segmented scorpion tail with a round golden tip, held up over its back.

Mythical. Built from the lion's skeleton, with the tail curled up.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid, plate
import lion as L

J = dict(L.J)
J.update({"tail_base": (0, -0.72, 1.08), "tail_mid": (0, -0.9, 1.45), "tail_end": (0, -0.72, 1.72)})
R = dict(L.R)
R.update({"tail": (0.07, 0.08, 0.075, 0.06)})

COLORS = {"red": "#cf6a32", "back": "#b2522a", "pale": "#efc69a", "mane": "#9a2a22", "wing": "#7a4fa8", "tail": "#a8402a",
          "gold": "#f2c13a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("red")
    p.top_darken("back", start=0.3, strength=0.4)
    p.region_underside("torso", "pale", below=-0.35, soft=0.3)
    p.region("jaw", "pale", 0.8)
    p.region("mane", "mane")
    p.region("wing", "wing")
    p.region("tail", "tail")
    p.region("tail_tip", "tail")
    p.stripes("pale", lambda q: q[:, 1] + q[:, 2], frequency=14.0, width=0.15, mask=Wt("tail") * 0.5)
    p.region("sting", "gold")
    return p.colors


def make():
    c = quadruped("manticore", J, R, paint=paint, tiles_long=2.3)
    c.voxel = 0.007
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.09, 0.86, 0.96), (0.07, 0.08, 0.075), "cheek", "head", blend=0.05))
    c.shapes.append(ellipsoid((0, 0.72, 1.02), (0.28, 0.11, 0.25), "mane", "neck", blend=0.08, pitch=0.25))
    c.shapes.append(ellipsoid((0, 0.6, 0.98), (0.24, 0.2, 0.28), "mane", "neck", blend=0.09, pitch=0.5))
    # Folded bat wings on the shoulders.
    w = np.asarray(J["withers"], float)
    for side in (1, -1):
        base_a, base_b = w + (side * 0.14, 0.08, 0.05), w + (side * 0.14, -0.2, 0.05)
        c.shapes.append(plate(base_a, base_b, w + (side * 0.32, -0.25, 0.42), 0.02, 0.02, "wing", "chest", blend=0.03))
        c.shapes.append(plate(base_a, w + (side * 0.32, -0.25, 0.42), w + (side * 0.22, 0.05, 0.5), 0.02, 0.02, "wing", "chest", blend=0.03))
    # The scorpion tail: plump segments curling up, and a round stinger.
    te, tm = np.asarray(J["tail_end"], float), np.asarray(J["tail_mid"], float)
    for u, bone in ((0.2, "tail1"), (0.5, "tail1"), (0.8, "tail2")):
        at = np.asarray(J["tail_base"], float) + (tm - np.asarray(J["tail_base"], float)) * u
        c.shapes.append(ellipsoid(tuple(at), (0.09, 0.09, 0.09), "tail", bone, blend=0.03))
    for u in (0.3, 0.7):
        at = tm + (te - tm) * u
        c.shapes.append(ellipsoid(tuple(at), (0.085, 0.085, 0.085), "tail", "tail2", blend=0.03))
    c.shapes.append(ellipsoid(tuple(te + (0, 0.06, 0.0)), (0.07, 0.07, 0.07), "sting", "tail3", blend=0.02))
    c.shapes.append(cone(te + (0, 0.1, 0.0), te + (0, 0.2, -0.06), 0.035, 0.012, "sting", "tail3", blend=0.01))
    add_face(c, eye_dir=(-0.45, 0.84, 0.3), eye_radius=0.017, eye_sink=0.01, nose_radius=0.025, nose_sink=0.01,
             iris="#7a3a8a", pupil="round")
    c.fur = {"strands": False, "variation": 0.05, "sheen": 0.3, "bump": 0.2, "roughness": 0.6}
    c.motion = {"gait": "walk", "attack": "pounce_bite", "stride": 1.0, "gape": 0.7}
    c.cartoon = {"face_mane": True}
    return c
