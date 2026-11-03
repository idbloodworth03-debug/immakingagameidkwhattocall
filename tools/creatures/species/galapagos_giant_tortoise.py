"""Galapagos giant tortoise (Western Santa Cruz): a huge, slow, ancient
tortoise with a big high-domed gray shell, a long wrinkly neck holding up
a small head with a gentle face, and thick elephant-like legs.

Real size: about 1.2 m shell.
Built on the snapping turtle's skeleton with a long neck and big legs.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from shellkit import add_shell, scute_mask
import snapping_turtle as ST

J = dict(ST.J)
J.update({"neck_base": (0, 0.18, 0.16), "head_base": (0, 0.3, 0.24), "skull": (0, 0.33, 0.25), "snout_tip": (0, 0.39, 0.235),
          "jaw_hinge": (0, 0.33, 0.225), "chin": (0, 0.38, 0.215), "ear_base": (-0.04, 0.32, 0.27), "ear_tip": (-0.041, 0.318, 0.273),
          "tail_mid": (0, -0.24, 0.08), "tail_end": (0, -0.27, 0.06),
          "shoulder": (-0.13, 0.12, 0.1), "elbow": (-0.18, 0.15, 0.08), "wrist": (-0.18, 0.16, 0.02), "front_toe": (-0.185, 0.18, 0.008),
          "hip": (-0.13, -0.12, 0.1), "knee": (-0.18, -0.14, 0.08), "hock": (-0.18, -0.15, 0.02), "hind_toe": (-0.185, -0.16, 0.008)})
R = dict(ST.R)
R.update({"neck_base": 0.05, "neck_top": 0.04, "skull": (0.05, 0.055, 0.045), "snout_base": 0.035, "snout_end": 0.022,
          "upper_arm": (0.05, 0.045), "forearm": (0.048, 0.045), "front_paw": (0.046, 0.04),
          "upper_leg": (0.055, 0.05), "shin": (0.05, 0.047), "hind_paw": (0.048, 0.042), "tail": (0.03, 0.02, 0.01, 0.003)})

SHELL = ((0, 0.0, 0.2), (0.21, 0.25, 0.16))
COLORS = {"shell": "#6d6a60", "line": "#3d3b35", "skin": "#8a857a", "dark": "#5d5a52", "belly": "#a39c88"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("skin")
    p.stripes("dark", lambda q: q[:, 2] * 3 + q[:, 1], frequency=60.0, width=0.15, mask=Wt("neck") * 0.6)
    p.region("shell", "shell")
    p.blend("line", Wt("shell") * scute_mask(p, *SHELL) * 0.9)
    p.region("plastron", "belly")
    p.speckle(0.12)
    return p.colors


def make():
    c = quadruped("galapagos_giant_tortoise", J, R, paint=paint, tiles_long=1.9)
    c.voxel = 0.0035
    add_shell(c, *SHELL, plastron=(0.9, 0.88, 0.3), plastron_drop=0.6)
    add_face(c, eye_dir=(-0.62, 0.62, 0.45), eye_radius=0.009, eye_sink=0.004, nose_radius=0.0, iris="#2a1d12", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.2, "bump": 0.4, "roughness": 0.75}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.6, "gape": 0.5, "cycle_tiles": 0.45}
    return c
