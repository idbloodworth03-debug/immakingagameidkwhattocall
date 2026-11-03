"""Pistol shrimp (bigclaw snapping shrimp): a small shrimp with one huge
claw that snaps shut so fast it shoots out a bubble with a loud pop. Coral
red with cream bands on the tail, long antennae swept back, and big eyes.

Real size: about 5 cm long.
"""
import numpy as np

from anatomy import add_face
from bodies import shrimp
from paint import Painter

J = {
    "spine_mid": (0, 0.0, 0.06),
    "withers": (0, 0.05, 0.065),
    "head_base": (0, 0.07, 0.066),
    "skull": (0, 0.085, 0.072),
    "snout_tip": (0, 0.125, 0.07),
    "tail_base": (0, -0.04, 0.06),
    "tail_mid": (0, -0.09, 0.056),
    "tail_end": (0, -0.13, 0.042),
    "tail_fan": (0, -0.16, 0.022),
    "fan": (-0.032, -0.2, 0.012),
    "claw_shoulder": (-0.022, 0.06, 0.045),
    "claw_elbow": (-0.042, 0.1, 0.04),
    "claw_wrist": (-0.046, 0.16, 0.046),
    "claw_tip": (-0.046, 0.215, 0.052),
    "antenna_base": (-0.012, 0.11, 0.08),
    "antenna_tip": (-0.085, -0.05, 0.15),
    "leg1_hip": (-0.018, 0.03, 0.042), "leg1_knee": (-0.05, 0.04, 0.036), "leg1_foot": (-0.062, 0.05, 0.002),
    "leg2_hip": (-0.02, 0.0, 0.042), "leg2_knee": (-0.056, 0.0, 0.036), "leg2_foot": (-0.07, -0.005, 0.002),
    "leg3_hip": (-0.018, -0.03, 0.042), "leg3_knee": (-0.05, -0.04, 0.036), "leg3_foot": (-0.062, -0.05, 0.002),
}

R = {
    "shell": (0.035, 0.062, 0.031), "shell_pitch": 0.05,
    "skull": (0.023, 0.023, 0.023), "snout_root": (0, 0.015, 0.0), "snout": (0.008, 0.002),
    "segments": [(0.031, 0.026, 0.027), (0.026, 0.023, 0.023), (0.019, 0.019, 0.017)], "segment_pitch": (0.2, 0.5, 0.8),
    "fin_thick": 0.002, "fin_round": 0.008, "fin_blend": 0.004, "antenna": (0.0018, 0.001),
    "arm": 0.009, "palm": (0.03, 0.055, 0.027), "finger_root": (0, 0, 0.01), "finger": (0.012, 0.005), "small_claw": 0.38,
    "leg": (0.0045, 0.0035, 0.0025), "blend": 0.01,
}

COLORS = {
    "red": "#e8603c",
    "dark": "#b8402a",
    "cream": "#f4dcbc",
    "claw": "#f07a3c",
    "tip": "#fbe9d8",
    "leg": "#f2a58c",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("red")
    p.blend("dark", p.smooth(n[:, 2], 0.5, 0.4) * 0.5)
    tail = p.mesh.region_weight("tail")
    p.stripes("cream", lambda q: q[:, 1], frequency=24.0, width=0.14, mask=tail)
    claw = p.mesh.region_weight("claw")
    p.blend("claw", claw)
    p.blend("tip", claw * p.smooth(v[:, 1] - 0.19, 0.0, 0.015))
    p.region("leg", "leg")
    p.region("antenna", "dark")
    p.region("fin", "cream", 0.7)
    return p.colors


def make():
    c = shrimp("pistol_shrimp", J, R, big_claw=".R", paint=paint, tiles_long=0.8)
    c.voxel = 0.0015
    add_face(c, eye_dir=(-0.6, 0.7, 0.4), eye_radius=0.006, eye_sink=0.002, nose_radius=0, iris="#111111", pupil="round")
    c.fur = {"strands": False, "variation": 0.0, "sheen": 0.35, "bump": 0.0, "roughness": 0.4, "specular": 0.4}
    c.motion = {"body": "crustacean", "attack": "snap", "big_claw": "R", "cycle_tiles": 0.6}
    return c
