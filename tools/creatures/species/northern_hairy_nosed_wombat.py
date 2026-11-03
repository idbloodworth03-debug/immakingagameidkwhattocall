"""Northern hairy-nosed wombat: a round, heavy, barrel-shaped burrower on
short legs with a big broad head, a wide fuzzy nose, small pointed ears and
almost no tail. Soft silvery gray-brown fur.

Real size: about 35 cm at the shoulder, 1 m long.
Built from the honey badger's skeleton, rounder.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
import honey_badger as HB
from derive import scaled, scaled_r

K = 1.25
J = scaled(HB.J, K)
J["ear_tip"] = tuple(np.asarray(J["ear_base"]) + (-0.012, -0.008, 0.04))
J["tail_mid"] = tuple(np.asarray(J["tail_base"]) + (0, -0.02, -0.01))
J["tail_end"] = tuple(np.asarray(J["tail_base"]) + (0, -0.03, -0.02))
R = scaled_r(HB.R, K)
R.update({"rump": (0.15, 0.14, 0.12), "belly": (0.16, 0.2, 0.13), "chest": (0.14, 0.13, 0.12), "skull": (0.085, 0.075, 0.07),
          "snout_base": 0.055, "snout_end": 0.048, "ear_width": 0.028, "ear_round": 0.008, "tail": (0.02, 0.015, 0.01)})

COLORS = {"gray": "#9a8f84", "light": "#c9bfb2", "nose": "#6f655c", "dark": "#5f554d"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("gray")
    p.blend("light", p.smooth(-p.n[:, 2], 0.0, 0.4) * 0.5)
    p.region_where("snout", "nose", lambda v, n: p.smooth(v[:, 1] - 0.43, 0.0, 0.02), 0.6)
    for leg in ("front_paw", "hind_paw"):
        p.region(leg, "dark", 0.6)
    p.speckle(0.15)
    return p.colors


def make():
    c = quadruped("northern_hairy_nosed_wombat", J, R, paint=paint, tiles_long=1.3)
    c.voxel = 0.0032
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.06 * K, 0.275 * K, 0.215 * K), (0.05, 0.05, 0.045), "cheek", "head", blend=0.03))
    add_face(c, eye_dir=(-0.55, 0.78, 0.3), eye_radius=0.009, eye_sink=0.005, nose_radius=0.02, nose_sink=0.006,
             iris="#1a1210", pupil="round")
    c.extras[-1].color = "#4a423c"
    c.fur = {"strands": False, "variation": 0.12, "sheen": 0.25, "bump": 0.3, "roughness": 0.7}
    c.motion = {"gait": "walk", "attack": "charge", "stride": 1.0, "charge_reach": 0.3}
    return c
