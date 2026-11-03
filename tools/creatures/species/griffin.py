"""Griffin: a lion's body with an eagle's white head, golden hooked beak,
feathered ear tufts and big brown wings with pale tips. It flies, so only
Ranged and Air animals can reach it.
"""
import numpy as np

from anatomy import add_face, quadruped
from bodies import add_wings
from lion import J as LJ, R as LR
from paint import Painter
from sdf import cone

J = dict(LJ)
sk = np.asarray(J["skull"], float)
J["snout_tip"] = tuple(sk + np.array([0, 0.16, -0.06]))
J["chin"] = tuple(np.asarray(J["jaw_hinge"], float) + np.array([0, 0.1, -0.02]))
R = dict(LR, snout_base=0.045, snout_end=0.012, snout_root=(0, 0.05, -0.02), jaw_base=0.03, jaw_end=0.008)
WING_J = {"shoulder": (-0.13, 0.25, 0.75), "elbow": (-0.45, 0.2, 0.86), "wrist": (-0.8, 0.26, 0.9), "wing_tip": (-1.25, 0.06, 0.88)}
WING_R = {"chord": (0.36, 0.44, 0.46, 0.26), "wing_thick": 0.012, "wing_blend": 0.02, "feathers": 18, "fan": 1.0,
          "feather_overlap": 2.0, "arm": (0.045, 0.034, 0.022), "fingers": 5, "finger_length": 1.2}
COLORS = {"tawny": "#d9a24a", "belly": "#efd59a", "white": "#f5f2ea", "wing": "#8a5a2c", "tip": "#f0e2c0", "beak": "#f2c23a"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("tawny")
    p.blend("belly", p.smooth(-p.n[:, 2], 0.3, 0.4) * 0.6)
    for region in ("head", "neck", "ear"):
        p.region(region, "white")
    p.region("snout", "beak")
    p.region("jaw", "beak")
    wing = p.mesh.region_weight("wing")
    p.blend("wing", wing)
    p.blend("tip", wing * p.smooth(np.abs(v[:, 0]) - 0.95, 0.0, 0.1))
    return p.colors


def make():
    c = quadruped("griffin", J, R, paint=paint, tiles_long=2.6)
    c.voxel = 0.008
    tip = np.asarray(J["snout_tip"], float)
    c.shapes.append(cone(tip, tip + np.array([0, -0.01, -0.05]), 0.012, 0.004, "snout", "head", blend=0.004))
    add_wings(c, WING_J, WING_R)
    add_face(c, eye_dir=(-0.7, 0.55, 0.35), eye_radius=0.018, eye_sink=0.007, nose_radius=0, iris="#d88a1a", pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.25, "bump": 0.2, "roughness": 0.6}
    c.motion.update({"attack": "winged_dive", "altitude": 0.6, "flap": 0.7, "hover_power": 0.5, "cycle_tiles": 2.0})
    return c
