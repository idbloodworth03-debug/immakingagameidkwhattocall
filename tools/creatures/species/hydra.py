"""Hydra, made a goofy three-headed swamp dragon: a round green lizard-like
body on stubby legs with three long necks, each with a happy little dragon
head, a row of soft yellow spines down the back and a pale yellow belly.
Its heads bob as it waddles.

Mythical. Built on the Komodo dragon's skeleton, with two extra necks.
"""
import numpy as np

from anatomy import add_face, quadruped
from cartoon import add_cartoon_eyes
from paint import Painter
from sdf import cone, ellipsoid
import komodo_dragon as K

J = dict(K.J)
J.update({"neck_base": (0, 0.45, 0.36), "head_base": (0, 0.62, 0.72), "skull": (0, 0.67, 0.76),
          "snout_tip": (0, 0.84, 0.72), "jaw_hinge": (0, 0.67, 0.71), "chin": (0, 0.81, 0.69),
          "ear_base": (-0.07, 0.65, 0.81), "ear_tip": (-0.072, 0.648, 0.814),
          "tail_mid": (0, -0.9, 0.18), "tail_end": (0, -1.2, 0.06)})
R = dict(K.R)
R.update({"rump": (0.22, 0.27, 0.17), "belly": (0.25, 0.42, 0.18), "chest": (0.23, 0.27, 0.17),
          "neck_base": 0.11, "neck_top": 0.08, "skull": (0.09, 0.1, 0.08), "snout_base": 0.065, "snout_end": 0.045})

COLORS = {"green": "#4fa05c", "dark": "#367a44", "belly": "#efe08a", "spine": "#f2c94a"}

SIDE = [(-0.3, -0.06, -0.08), (0.3, -0.06, -0.08)]


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    n = p.n
    Wt = p.mesh.region_weight
    p.fill("green")
    p.blend("dark", p.smooth(n[:, 2], 0.5, 0.3) * 0.4)
    p.blend("belly", p.smooth(-n[:, 2], 0.2, 0.4) * 0.9)
    p.region("spine", "spine")
    return p.colors


def _after(c):
    for s in c.shapes:
        if s.region == "side_skull":
            add_cartoon_eyes(c, s.a, (-0.6, 0.7, 0.4), bone="neck", size=0.9)


def make():
    c = quadruped("hydra", J, R, paint=paint, tiles_long=2.3)
    c.voxel = 0.008
    nb, sk, tip = (np.asarray(J[k], float) for k in ("neck_base", "skull", "snout_tip"))
    for off in SIDE:
        o = np.asarray(off)
        hs = sk + o
        c.shapes.append(cone(nb + o * 0.25, hs + (0, -0.04, -0.04), 0.1, 0.07, "neck", "neck", blend=0.05))
        c.shapes.append(ellipsoid(tuple(hs), R["skull"], "side_skull", "neck", blend=0.04))
        c.shapes.append(cone(hs + (0, 0.07, -0.02), tip + o, 0.06, 0.04, "side_snout", "neck", blend=0.03))
    # Soft spines down the back and tail.
    spine = [np.asarray(J[k], float) for k in ("withers", "spine_mid", "pelvis", "tail_base", "tail_mid")]
    bones = ["chest", "chest", "hips", "tail1", "tail2"]
    for i in range(len(spine) - 1):
        for u in (0.0, 0.5):
            at = spine[i] + (spine[i + 1] - spine[i]) * u
            r = 0.17 * (1 - (i + u) / len(spine)) + 0.04
            base = at + (0, 0, r)
            c.shapes.append(cone(base, base + (0, -0.03, 0.07), 0.035, 0.008, "spine", bones[i], blend=0.015))
    add_face(c, eye_dir=(-0.6, 0.7, 0.4), eye_radius=0.016, eye_sink=0.006, nose_radius=0.0, iris="#3a2410", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.35, "bump": 0.1, "roughness": 0.45}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.9, "wiggle": 0.12, "gape": 0.6, "cycle_tiles": 0.8}
    c.cartoon = {"head": 1.0}
    c.after_cartoon = _after
    return c
