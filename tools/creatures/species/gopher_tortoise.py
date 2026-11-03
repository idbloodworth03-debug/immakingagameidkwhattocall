"""Gopher tortoise: a burrowing land tortoise with a flattish tan-brown
shell with pale centers on each scute, a blunt gray head and broad,
shovel-like front legs for digging.

Real size: about 25 cm shell.
Built on the snapping turtle's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from shellkit import add_shell, scute_mask
import snapping_turtle as ST

J = dict(ST.J)
J.update({"tail_mid": (0, -0.24, 0.09), "tail_end": (0, -0.27, 0.07), "snout_tip": (0, 0.34, 0.12), "chin": (0, 0.33, 0.1)})
R = dict(ST.R)
R.update({"skull": (0.058, 0.06, 0.048), "snout_base": 0.04, "snout_end": 0.028, "front_paw": (0.04, 0.03), "forearm": (0.04, 0.036),
          "tail": (0.025, 0.018, 0.01, 0.003)})

SHELL = ((0, 0.0, 0.18), (0.19, 0.23, 0.11))
COLORS = {"shell": "#8a6a44", "pale": "#c9a874", "line": "#4a3826", "skin": "#7b7468", "belly": "#d6c18f"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    Wt = p.mesh.region_weight
    p.fill("skin")
    p.region("shell", "shell")
    lines = scute_mask(p, *SHELL, width=0.07)
    p.blend("pale", Wt("shell") * (1 - lines) * p.smooth(p.n[:, 2], 0.6, 0.3) * 0.6)
    p.blend("line", Wt("shell") * lines * 0.9)
    p.region("plastron", "belly")
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("gopher_tortoise", J, R, paint=paint, tiles_long=1.1)
    c.voxel = 0.0035
    add_shell(c, *SHELL, plastron=(0.9, 0.9, 0.3), plastron_drop=0.6)
    add_face(c, eye_dir=(-0.62, 0.62, 0.45), eye_radius=0.009, eye_sink=0.004, nose_radius=0.0, iris="#3a2410", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.25, "bump": 0.3, "roughness": 0.65}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.7, "gape": 0.5, "cycle_tiles": 0.5}
    return c
