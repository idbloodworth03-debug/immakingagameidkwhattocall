"""Peregrine Falcon in flight: compact body, long pointed swept-back wings,
medium tail. Slate blue-gray back and wings, the dark "helmet" over the head
with a thick moustache stripe, white throat, cream underparts with fine dark
bars, banded tail, short hooked blue-gray beak with yellow skin at the base,
yellow feet and eye rings.

Real size: about 42 cm long with a 1 m wingspan.
"""
import numpy as np

from anatomy import add_face, bird
from paint import Painter

J = {
    "pelvis": (0, -0.08, 0.0),
    "spine_mid": (0, 0.0, 0.005),
    "withers": (0, 0.07, 0.01),
    "neck_base": (0, 0.085, 0.012),
    "head_base": (0, 0.118, 0.02),
    "skull": (0, 0.138, 0.024),
    "beak_tip": (0, 0.182, 0.012),
    "jaw_hinge": (0, 0.148, 0.01),
    "chin": (0, 0.172, 0.006),
    "shoulder": (-0.033, 0.06, 0.02),
    "elbow": (-0.15, 0.035, 0.026),
    "wrist": (-0.27, 0.065, 0.022),
    "wing_tip": (-0.5, -0.03, 0.016),
    "hip": (-0.02, -0.04, -0.02),
    "foot": (-0.02, -0.1, -0.032),
    "tail_base": (0, -0.1, 0.0),
    "tail_end": (0, -0.25, -0.004),
}

R = {
    "body": (0.045, 0.11, 0.04), "body_drop": 0.005,
    "breast": (0.043, 0.05, 0.043), "breast_back": 0.02, "breast_drop": 0.012, "body_blend": 0.03,
    "neck": (0.03, 0.025), "neck_blend": 0.02,
    "skull": (0.026, 0.028, 0.025), "head_blend": 0.015,
    "beak_root": (0, 0.03, -0.008), "beak": (0.009, 0.0042), "beak_blend": 0.006,
    "jaw": (0.006, 0.003),
    "chord": (0.1, 0.115, 0.12, 0.06), "wing_thick": 0.0045, "wing_blend": 0.01,
    "feathers": 18, "fan": 1.0, "feather_overlap": 2.0,
    "arm": (0.014, 0.01, 0.007),
    "leg": (0.007, 0.006), "leg_blend": 0.004,
    "tail_width": (0.02, 0.042), "tail_thick": 0.003, "tail_blend": 0.01,
}

COLORS = {
    "slate": "#55606d",
    "dark": "#1f242b",
    "tips": "#2b323b",
    "cream": "#e9dfcf",
    "white": "#f2eee6",
    "bar": "#3b3b3e",
    "yellow": "#e2b236",
    "beak": "#5d6672",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    up = p.smooth(n[:, 2], -0.1, 0.3)           # facing the sky
    down = 1 - up
    p.fill("cream")
    # Upperparts slate, darkening toward the wingtips.
    p.blend("slate", up)
    wing = p.mesh.region_weight("wing")
    p.blend("tips", wing * up * p.smooth(np.abs(v[:, 0]) - 0.28, 0.0, 0.1))
    p.blend("dark", wing * p.smooth(np.abs(v[:, 0]) - 0.42, 0.0, 0.05) * 0.8)
    # Underparts: cream with dark bars across the belly and underwings.
    bars_mask = down * (p.mesh.region_weight("torso") + wing * 0.7)
    p.stripes("bar", lambda q: q[:, 1], frequency=55.0, width=0.18, wobble=0.15, mask=bars_mask, strength=0.75)
    p.blend("cream", p.mesh.region_weight("breast") * down * 0.6)
    # Head: dark helmet and moustache, white throat and cheeks.
    head = p.mesh.region_weight("head") + p.mesh.region_weight("neck") * p.smooth(v[:, 1] - 0.1, 0.0, 0.01)
    p.blend("dark", head * p.smooth(n[:, 2], -0.2, 0.4))
    p.blend("white", head * p.smooth(-n[:, 2], 0.1, 0.3) * p.smooth(np.abs(v[:, 0]) - 0.012, 0.0, 0.006) * 0
            + p.mesh.region_weight("neck") * p.smooth(-n[:, 2], 0.2, 0.3))
    p.blend("dark", head * p.smooth(np.abs(n[:, 0]), 0.6, 0.3) * p.smooth(0.03 - v[:, 2], 0.0, 0.01))
    # Tail: slate bands on top, barred underneath.
    tail = p.mesh.region_weight("tail")
    p.stripes("dark", lambda q: q[:, 1], frequency=40.0, width=0.2, mask=tail * up, strength=0.7)
    p.region("leg", "yellow")
    p.region("beak", "beak")
    p.region_where("beak", "yellow", lambda v, n: p.smooth(0.158 - v[:, 1], 0.0, 0.006))
    p.speckle(0.08)
    return p.colors


def make():
    c = bird("peregrine_falcon", J, R, paint=paint, tiles_long=1.4)
    c.voxel = 0.002
    add_face(c, eye_dir=(-0.75, 0.55, 0.3), eye_radius=0.0068, eye_sink=0.003, nose_radius=0, iris="#1a0d06", pupil="round")
    c.palette = {"eye_line": "#e2b236", "eye_line_size": 1.45}
    c.fur = {"strands": False, "variation": 0.12, "sheen": 0.1, "bump": 0.2, "roughness": 0.65}
    c.motion = {"body": "bird", "attack": "dive", "altitude": 0.42, "flap": 0.8, "hover_power": 0.5,
                "cycle_tiles": 1.4}
    return c
