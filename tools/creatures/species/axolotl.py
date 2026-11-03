"""Axolotl: a smiling pink salamander that never grows up: a wide flat head
with a big grin, three feathery gills on each side, little dark eyes, short
legs with tiny toes and a long tail with a soft fin along the top. Out of
the water it wiggles along like a lizard.

Real size: about 25 cm long.
Built from the Komodo dragon's skeleton, with a bigger head and a fin.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import cone, ellipsoid, plate
import komodo_dragon as K

J = dict(K.J)
J.update({"head_base": (0, 0.58, 0.33), "skull": (0, 0.66, 0.34), "snout_tip": (0, 0.82, 0.32), "chin": (0, 0.79, 0.27),
          "jaw_hinge": (0, 0.64, 0.27)})
R = dict(K.R)
R.update({"skull": (0.17, 0.14, 0.1), "snout_base": 0.11, "snout_end": 0.08, "snout_root": (0, 0.06, -0.01),
          "jaw_base": 0.09, "jaw_end": 0.07, "rump": (0.15, 0.25, 0.12), "belly": (0.17, 0.42, 0.13),
          "chest": (0.16, 0.25, 0.12), "tail": (0.1, 0.07, 0.035, 0.01),
          "upper_arm": (0.05, 0.042), "forearm": (0.04, 0.032), "front_paw": (0.035, 0.022),
          "upper_leg": (0.055, 0.045), "shin": (0.042, 0.034), "hind_paw": (0.036, 0.022)})

COLORS = {"pink": "#f6b3c0", "light": "#fbd7de", "gill": "#e9577a", "fin": "#f9c8d2"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("pink")
    p.blend("light", p.smooth(-p.n[:, 2], 0.0, 0.4) * 0.7)
    p.region("gill", "gill")
    p.region("fin", "fin")
    p.speckle(0.04)
    return p.colors


def make():
    c = quadruped("axolotl", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.008
    sk = np.asarray(J["skull"], float)
    # Three feathery gill stalks on each side of the head.
    for side in (1, -1):
        for k, (dy, dz, ang) in enumerate(((-0.02, 0.07, 0.5), (-0.05, 0.03, 0.0), (-0.07, -0.02, -0.45))):
            base = sk + (side * 0.15, dy, dz)
            tip = base + (side * 0.12, -0.12, 0.13 * np.sin(ang) + 0.04)
            c.shapes.append(cone(base, tip, 0.025, 0.014, "gill", "head", blend=0.015))
            for u in (0.35, 0.65, 0.92):
                at = base + (tip - base) * u
                c.shapes.append(ellipsoid(tuple(at), (0.028, 0.02, 0.028), "gill", "head", blend=0.012))
    # The soft fin along the top of the tail.
    tb, tm, te = (np.asarray(J[k], float) for k in ("tail_base", "tail_mid", "tail_end"))
    c.shapes.append(plate(tb + (0, 0, 0.05), tm + (0, 0, 0.1), te + (0, 0, 0.03), 0.012, 0.01, "fin", "tail2", blend=0.02))
    c.shapes.append(plate(tb + (0, 0, 0.05), tm + (0, 0, -0.06), te + (0, 0, 0.0), 0.012, 0.01, "fin", "tail2", blend=0.02))
    add_face(c, eye_dir=(-0.75, 0.45, 0.45), eye_radius=0.014, eye_sink=0.006, nose_radius=0.0, iris="#1b1214", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.4, "bump": 0.05, "roughness": 0.4, "subsurface": 0.2}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.9, "wiggle": 0.2, "gape": 0.5, "cycle_tiles": 0.6}
    c.palette = {"mouth": "#c24a66"}
    return c
