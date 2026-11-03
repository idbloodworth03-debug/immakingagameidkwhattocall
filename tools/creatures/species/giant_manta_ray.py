"""Giant oceanic manta ray, made small and friendly: a flat, diamond-shaped
ray with huge wing-like fins, two rolled-up horn fins beside its wide mouth,
a short whip of a tail, a black back with white shoulder patches and a
white belly. On land it ripples along, flapping its wings.

Real size: up to 7 m across.
Built on the fish body plan, flattened, with the side fins as wings.
"""
import numpy as np

from anatomy import add_face
from bodies import fish
from paint import Painter
from sdf import ellipsoid

J = {
    "snout_tip": (0, 0.25, 0.06), "skull": (0, 0.18, 0.07), "head_base": (0, 0.12, 0.07), "withers": (0, 0.06, 0.07),
    "spine_mid": (0, -0.04, 0.07), "pelvis": (0, -0.12, 0.065), "tail_base": (0, -0.16, 0.06), "tail_mid": (0, -0.3, 0.05),
    "tail_end": (0, -0.44, 0.04), "caudal_a": (-0.012, -0.47, 0.04), "caudal_b": (0.012, -0.47, 0.04),
    "jaw_hinge": (0, 0.2, 0.045), "chin": (0, 0.245, 0.045),
    "dorsal_front": (0, -0.1, 0.11), "dorsal_back": (0, -0.14, 0.105), "dorsal_tip": (0, -0.135, 0.125),
    "pect_base": (-0.07, 0.13, 0.065), "pect_back": (-0.07, -0.12, 0.065), "pect_tip": (-0.55, -0.06, 0.09),
}
R = {
    "body": (0.11, 0.15, 0.04), "front": (0.12, 0.1, 0.045),
    "skull": (0.07, 0.06, 0.035), "snout_root": (0, 0.03, 0.0), "snout": (0.06, 0.055), "snout_blend": 0.02,
    "jaw": (0.05, 0.045), "tail": (0.015, 0.01, 0.005), "blend": 0.03,
    "fin_thick": 0.02, "fin_round": 0.035, "fin_blend": 0.035, "fin_root": 0.004,
}
COLORS = {"black": "#24272d", "white": "#f2f2ee", "patch": "#d9dbdc"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("black")
    p.blend("white", p.smooth(-n[:, 2], 0.1, 0.4))
    # White shoulder patches on the back.
    d = np.sqrt(((np.abs(v[:, 0]) - 0.16) / 0.09) ** 2 + ((v[:, 1] - 0.08) / 0.07) ** 2)
    p.blend("patch", p.smooth(n[:, 2], 0.3, 0.3) * p.smooth(1 - d, 0.0, 0.3) * 0.9)
    return p.colors


def make():
    c = fish("giant_manta_ray", J, R, fluke=True, paint=paint, tiles_long=1.5)
    c.voxel = 0.004
    # The two horn fins either side of the mouth.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.065, 0.27, 0.055), (0.016, 0.045, 0.013), "head", "head", blend=0.012, yaw=side * 0.2))
    add_face(c, eye_dir=(-0.9, 0.3, 0.3), eye_radius=0.011, eye_sink=0.004, nose_radius=0, iris="#141414", pupil="round")
    c.cartoon = {"head": 1.2, "muzzle": 1.0}
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.35, "bump": 0.0, "roughness": 0.4}
    c.motion = {"body": "cetacean", "attack": "snap", "gape": 0.3, "cycle_tiles": 1.2}
    return c
