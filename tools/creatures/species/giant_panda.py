"""Giant panda: a round, chunky bear with a big round head, a short muzzle,
small round black ears, black eye patches, black legs and a black band over
the shoulders, and a white body. A stubby white tail.

Real size: about 75 cm at the shoulder, 1.6 m long.
Built from the brown bear's skeleton, without the hump.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import brown_bear as B

J = dict(B.J)
J.update({"withers": (0, 0.4, 1.02), "head_base": (0, 0.78, 0.9), "skull": (0, 0.87, 0.92),
          "snout_tip": (0, 1.08, 0.82), "chin": (0, 1.03, 0.76), "jaw_hinge": (0, 0.86, 0.82),
          "ear_base": (-0.12, 0.84, 1.05), "ear_tip": (-0.15, 0.83, 1.13)})
R = dict(B.R)
R.update({"skull": (0.18, 0.17, 0.16), "snout_base": 0.09, "snout_end": 0.065, "snout_root": (0, 0.11, -0.06),
          "ear_width": 0.1, "ear_round": 0.045, "rump": (0.26, 0.34, 0.28), "belly": (0.3, 0.58, 0.28)})

COLORS = {"white": "#f4f1ea", "black": "#1c1a1b", "nose": "#151314"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    Wt = p.mesh.region_weight
    p.fill("white")
    for leg in ("front_upper", "front_lower", "front_paw", "shoulder", "thigh", "hind_lower", "hind_paw"):
        p.region(leg, "black")
    # Black stockings all the way up the legs to the body.
    p.blend("black", p.smooth(0.66 - v[:, 2], 0.0, 0.06) * (1 - Wt("head") - Wt("snout") - Wt("jaw")))
    # The band over the shoulders that joins the front legs.
    p.blend("black", Wt("torso") * p.smooth(0.15 - np.abs(v[:, 1] - 0.45), 0.0, 0.04))
    # Rump stays white where the thighs blend in.
    p.blend("white", Wt("torso") * p.smooth(v[:, 2] - 0.95, 0.0, 0.05) * p.smooth(-0.3 - v[:, 1], 0.0, 0.06))
    p.region("ear", "black")
    # Teardrop eye patches, sloping down and out.
    # (The eyes sit at x 0.082, y 1.0, z 0.96; the cartoon eyes are big, so
    # the patches reach well past them.)
    ax = np.abs(v[:, 0])
    d = np.sqrt(((ax - 0.095) / 0.08) ** 2 + ((v[:, 1] - 0.99) / 0.08) ** 2 + ((v[:, 2] - 0.945 + (ax - 0.095) * 0.5) / 0.07) ** 2)
    p.blend("black", (Wt("head") + Wt("cheek")) * p.smooth(1.0 - d, 0.0, 0.2))
    p.speckle(0.04)
    return p.colors


def make():
    c = quadruped("giant_panda", J, R, paint=paint, tiles_long=2.1)
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.13, 0.86, 0.86), (0.1, 0.1, 0.1), "cheek", "head", blend=0.07))
    add_face(c, eye_dir=(-0.5, 0.8, 0.25), eye_radius=0.019, eye_sink=0.012, nose_radius=0.035, nose_sink=0.016,
             iris="#2a1d14", pupil="round")
    c.fur = {"variation": 0.06, "sheen": 0.25, "bump": 0.3, "length": 0.06, "density": 9000, "hair_gamma": 2.1,
             "frizz": 0.003, "clump": 0.4, "lengths": {"cheek": 1.1, "head": 0.6, "front_paw": 0.4, "hind_paw": 0.4}}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.35, "stride": 0.85}
    return c
