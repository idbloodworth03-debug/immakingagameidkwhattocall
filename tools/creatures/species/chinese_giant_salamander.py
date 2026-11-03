"""Chinese giant salamander: the world's biggest amphibian, a long, flat,
wrinkly brown salamander with a broad flat head, tiny eyes, a wide grin,
loose skin folds along its sides, short stubby legs and a paddle tail with
a fin. It wiggles along like a lizard.

Real size: about 1.2 m long.
Built from the axolotl's body, without the gills.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid, plate
import axolotl as AX

J = dict(AX.J)
J.update({"skull": (0, 0.66, 0.31), "snout_tip": (0, 0.84, 0.3)})
R = dict(AX.R)
R.update({"skull": (0.18, 0.15, 0.075), "snout_base": 0.12, "snout_end": 0.09, "rump": (0.17, 0.25, 0.1),
          "belly": (0.2, 0.42, 0.1), "chest": (0.18, 0.25, 0.1)})

COLORS = {"brown": "#6a5236", "dark": "#3f2f20", "light": "#9c8260", "fin": "#7a6040"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("brown")
    p.spots("dark", cell=0.08, radius=0.025, mask=p.smooth(p.n[:, 2], -0.2, 0.4) * 0.8, seed=27)
    p.blend("light", p.smooth(-p.n[:, 2], 0.2, 0.4) * 0.6)
    p.region("fin", "fin")
    p.region("fold", "light", 0.4)
    p.speckle(0.2)
    return p.colors


def make():
    c = quadruped("chinese_giant_salamander", J, R, paint=paint, tiles_long=1.8)
    c.voxel = 0.008
    # Loose wrinkly skin folds along each side.
    for side in (1, -1):
        for y in np.linspace(-0.35, 0.35, 5):
            c.shapes.append(ellipsoid((side * 0.19, float(y), 0.26), (0.04, 0.07, 0.03), "fold", "chest" if y > 0 else "hips", blend=0.03))
    tb, tm, te = (np.asarray(J[k], float) for k in ("tail_base", "tail_mid", "tail_end"))
    c.shapes.append(plate(tb + (0, 0, 0.05), tm + (0, 0, 0.09), te + (0, 0, 0.03), 0.012, 0.01, "fin", "tail2", blend=0.02))
    add_face(c, eye_dir=(-0.6, 0.55, 0.6), eye_radius=0.012, eye_sink=0.005, nose_radius=0.0, iris="#2a1e12", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.35, "bump": 0.4, "roughness": 0.5}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.85, "wiggle": 0.2, "gape": 0.6, "cycle_tiles": 0.7}
    c.palette = {"mouth": "#7a3a3a"}
    return c
