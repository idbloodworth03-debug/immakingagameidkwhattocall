"""California Condor soaring: huge broad wings with "fingered" wingtip
feathers, long tail, bare pink-orange head and neck rising out of a black
feather ruff, ivory beak. Black all over, with the white triangles under
the wings and a pale bar along the top of each wing.

Real size: about 1.2 m long with a 2.9 m wingspan.
"""
import numpy as np

from anatomy import add_face, bird
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.25, 0.0),
    "spine_mid": (0, 0.0, 0.01),
    "withers": (0, 0.2, 0.02),
    "neck_base": (0, 0.25, 0.03),
    "head_base": (0, 0.36, 0.05),
    "skull": (0, 0.395, 0.055),
    "beak_tip": (0, 0.49, 0.03),
    "jaw_hinge": (0, 0.415, 0.035),
    "chin": (0, 0.47, 0.022),
    "shoulder": (-0.09, 0.18, 0.04),
    "elbow": (-0.45, 0.15, 0.05),
    "wrist": (-0.85, 0.2, 0.05),
    "wing_tip": (-1.38, 0.08, 0.045),
    "hip": (-0.06, -0.12, -0.05),
    "foot": (-0.06, -0.3, -0.07),
    "tail_base": (0, -0.3, 0.0),
    "tail_end": (0, -0.62, 0.0),
}

R = {
    "body": (0.13, 0.32, 0.12), "body_drop": 0.01,
    "breast": (0.12, 0.15, 0.12), "breast_back": 0.05, "breast_drop": 0.03, "body_blend": 0.08,
    "neck": (0.055, 0.042), "neck_blend": 0.03,
    "skull": (0.052, 0.058, 0.048), "head_blend": 0.03,
    "beak_root": (0, 0.065, -0.014), "beak": (0.021, 0.011), "beak_blend": 0.012,
    "jaw": (0.014, 0.008),
    "chord": (0.34, 0.38, 0.37, 0.28), "wing_thick": 0.012, "wing_blend": 0.025,
    "feathers": 18, "fan": 0.6, "fingers": 5, "finger_length": 1.25, "feather_overlap": 1.7,
    "arm": (0.045, 0.032, 0.022),
    "leg": (0.02, 0.018), "leg_blend": 0.01,
    "tail_width": (0.08, 0.13), "tail_thick": 0.008, "tail_blend": 0.03,
}

COLORS = {
    "black": "#141416",
    "gloss": "#2a2a30",
    "skin": "#d8826a",
    "skin_dark": "#a85a4a",
    "white": "#e9e6df",
    "silver": "#8e8b86",
    "ivory": "#e6dac2",
    "leg": "#958a85",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    up = p.smooth(n[:, 2], -0.1, 0.3)
    down = 1 - up
    p.fill("black")
    p.blend("gloss", up * 0.4)
    wing = p.mesh.region_weight("wing")
    reach = np.abs(v[:, 0])
    # White triangle under each wing, along the leading half.
    lead_y = np.interp(reach, [0.09, 0.45, 0.85, 1.38], [0.18, 0.15, 0.2, 0.08])
    behind = lead_y - v[:, 1]
    p.blend("white", wing * down * p.smooth(reach - 0.15, 0.0, 0.05) * p.smooth(0.9 - reach, 0.0, 0.08)
            * p.smooth(0.2 - behind, 0.0, 0.05))
    # Pale bar on the top of the wing, toward the trailing edge.
    p.blend("silver", wing * up * p.smooth(reach - 0.2, 0.0, 0.05) * p.smooth(0.82 - reach, 0.0, 0.08)
            * p.smooth(behind - 0.18, 0.0, 0.04) * p.smooth(0.3 - behind, 0.0, 0.04) * 0.75)
    # Bare head and neck.
    p.region("head", "skin")
    p.region("neck", "skin")
    p.blend("skin_dark", (p.mesh.region_weight("head") + p.mesh.region_weight("neck")) * p.smooth(n[:, 2], 0.3, 0.5) * 0.4)
    p.region("ruff", "black")
    p.region("beak", "ivory")
    p.region("leg", "leg")
    p.speckle(0.08)
    return p.colors


def make():
    c = bird("california_condor", J, R, paint=paint, tiles_long=2.2)
    c.voxel = 0.006
    # The ruff: a collar of black feathers round the base of the neck.
    c.shapes.append(ellipsoid((0, 0.24, 0.03), (0.105, 0.08, 0.095), "ruff", "chest", blend=0.04))
    add_face(c, eye_dir=(-0.75, 0.55, 0.35), eye_radius=0.011, eye_sink=0.005, nose_radius=0, iris="#8a2a1a", pupil="round")
    c.palette = {"eye_line": "#5a2a22", "eye_line_size": 1.4}
    c.fur = {"strands": False, "variation": 0.15, "sheen": 0.15, "bump": 0.25, "roughness": 0.55, "specular": 0.4}
    c.motion = {"body": "bird", "attack": "dive", "altitude": 0.9, "flap": 0.45, "hover_power": 0.35, "cycle_tiles": 2.0}
    return c
