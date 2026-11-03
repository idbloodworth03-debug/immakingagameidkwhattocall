"""Eastern box turtle: a small land turtle with a tall domed shell, dark
brown with bright yellow-orange flecks and starbursts on every scute, a
dark head and legs freckled with orange, and red-orange eyes. Stubby legs
and a short tail.

Real size: about 15 cm shell.
Built from the snapping turtle's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from shellkit import add_shell, scute_mask
import snapping_turtle as ST

J = dict(ST.J)
J.update({"tail_mid": (0, -0.25, 0.09), "tail_end": (0, -0.29, 0.07), "snout_tip": (0, 0.345, 0.12), "chin": (0, 0.335, 0.098)})
R = dict(ST.R)
R.update({"skull": (0.06, 0.064, 0.05), "snout_base": 0.04, "snout_end": 0.022, "tail": (0.03, 0.02, 0.01, 0.003)})

SHELL = ((0, 0.0, 0.19), (0.18, 0.22, 0.15))

COLORS = {"shell": "#4a3420", "fleck": "#f2b233", "line": "#2a1d12", "skin": "#3d2d22", "orange": "#e98a2c", "belly": "#d8b45a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    Wt = p.mesh.region_weight
    p.fill("skin")
    p.spots("orange", cell=0.03, radius=0.008, mask=1 - Wt("shell") - Wt("plastron"), seed=12)
    p.region("shell", "shell")
    # Starbursts: yellow-orange rays fanning across each scute.
    cx, cy, cz = SHELL[0]
    ang = np.arctan2(v[:, 1] - cy, v[:, 0] - cx)
    p.stripes("fleck", lambda q: ang, frequency=7.0, width=0.18, wobble=0.3, mask=Wt("shell") * 0.9)
    p.spots("fleck", cell=0.035, radius=0.009, mask=Wt("shell") * 0.8, seed=13)
    p.blend("line", Wt("shell") * scute_mask(p, *SHELL) * 0.9)
    p.region("plastron", "belly")
    p.speckle(0.1)
    return p.colors


def make():
    c = quadruped("eastern_box_turtle", J, R, paint=paint, tiles_long=1.0)
    c.voxel = 0.0035
    add_shell(c, *SHELL, plastron=(0.9, 0.9, 0.3), plastron_drop=0.55)
    add_face(c, eye_dir=(-0.62, 0.62, 0.45), eye_radius=0.009, eye_sink=0.004, nose_radius=0.0, iris="#d4401f", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.35, "bump": 0.3, "roughness": 0.6}
    c.motion = {"gait": "walk", "attack": "bite", "stride": 0.75, "gape": 0.6, "cycle_tiles": 0.5}
    return c
