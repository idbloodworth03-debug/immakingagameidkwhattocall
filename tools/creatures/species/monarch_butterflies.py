"""Monarch butterfly in flight: bright orange wings with black veins, a wide
black border dotted with white, a black body with white spots and clubbed
antennae. Modeled bigger than life (it would be a speck otherwise); the
game shows a pair of them.

Real size: about 10 cm wingspan.
"""
import numpy as np

from anatomy import add_face
from bodies import butterfly
from paint import Painter

J = {
    "spine_mid": (0, 0.0, 0.0),
    "withers": (0, 0.025, 0.002),
    "neck_base": (0, 0.03, 0.003),
    "head_base": (0, 0.036, 0.004),
    "skull": (0, 0.046, 0.005),
    "snout_tip": (0, 0.058, 0.002),
    "tail_base": (0, -0.012, 0.0),
    "tail_end": (0, -0.085, -0.006),
    "fore_root": (-0.008, 0.014, 0.006),
    "fore_tip": (-0.15, 0.075, 0.012),
    "fore_back": (-0.115, -0.03, 0.008),
    "hind_root": (-0.008, -0.006, 0.005),
    "hind_out": (-0.112, -0.055, 0.006),
    "hind_back": (-0.045, -0.115, 0.003),
    "antenna_base": (-0.005, 0.05, 0.012),
    "antenna_tip": (-0.03, 0.105, 0.035),
}

R = {
    "thorax": (0.012, 0.021, 0.012), "abdomen": (0.0085, 0.0045), "skull": (0.014, 0.013, 0.0135),
    "wing_thick": 0.0016, "wing_round": (0.024, 0.032), "wing_blend": 0.004, "blend": 0.006,
    "antenna": 0.0011, "club": 0.0028,
}

COLORS = {
    "orange": "#f08418",
    "deep": "#d4620c",
    "black": "#141212",
    "white": "#f7f2e6",
}


def _wing(p, creature, region, root_joint, veins):
    """Orange wing with black veins fanning from the root, a black border with
    white dots, and black along the front edge."""
    v = p.v
    w = p.mesh.region_weight(region)
    root = np.asarray(creature.joints[root_joint + ".L"], float)
    dx = np.abs(v[:, 0]) - abs(root[0])
    dy = v[:, 1] - root[1]
    theta = np.arctan2(dy, dx)
    d = np.hypot(dx, dy)
    # How far out each point is, compared with the edge of the wing in its direction.
    bins = np.digitize(theta, np.linspace(-np.pi, np.pi, 90))
    reach = np.zeros_like(d)
    on = w > 0.3
    for b in np.unique(bins[on]):
        m = on & (bins == b)
        reach[m] = d[m].max()
    rel = d / np.maximum(reach, 1e-6)
    p.blend("orange", w)
    p.blend("deep", w * p.smooth(0.35 - rel, 0.0, 0.25) * 0.6)
    p.stripes("black", lambda q: theta, frequency=veins / np.pi, width=0.12, mask=w * p.smooth(rel - 0.12, 0.0, 0.1))
    border = w * p.smooth(rel - 0.8, 0.0, 0.04)
    p.blend("black", border)
    dots = np.cos(theta * veins * 1.5) > 0.6
    p.blend("white", border * dots * p.smooth(0.035 - np.abs(rel - 0.9), 0.0, 0.02))


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    p.fill("black")
    _wing(p, creature, "wing_fore", "fore_root", veins=9)
    _wing(p, creature, "wing_hind", "hind_root", veins=7)
    # White spots on the thorax and head.
    body = p.mesh.region_weight("torso") + p.mesh.region_weight("head")
    p.spots("white", cell=0.008, radius=0.0018, mask=body * 0.9)
    return p.colors


def make():
    c = butterfly("monarch_butterflies", J, R, paint=paint, tiles_long=0.8)
    c.voxel = 0.0012
    add_face(c, eye_dir=(-0.8, 0.5, 0.15), eye_radius=0.0045, eye_sink=0.002, nose_radius=0, iris="#111111", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.2, "bump": 0.0, "roughness": 0.6}
    c.motion = {"body": "insect", "attack": "flutter_dive", "altitude": 0.12, "flap": 0.9, "cycle_tiles": 0.9}
    c.palette = {"eye_line": "#141212"}
    return c
