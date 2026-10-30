"""Tiger: the biggest cat. Powerful body, deep chest, big round head with
cheek ruffs and small round ears, thick legs, long tail. Orange coat with
black stripes running down the flanks (wavy, sometimes doubled), ringed
tail, white belly, chest, muzzle, cheeks and spots over the eyes, black ear
backs.

Real size: about 1 m at the shoulder, 1.9 m head and body, 90 cm tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.55, 0.92),
    "spine_mid": (0, -0.05, 0.9),
    "withers": (0, 0.45, 0.95),
    "neck_base": (0, 0.52, 0.86),
    "head_base": (0, 0.72, 0.92),
    "skull": (0, 0.8, 0.93),
    "snout_tip": (0, 0.98, 0.86),
    "jaw_hinge": (0, 0.8, 0.85),
    "chin": (0, 0.93, 0.79),
    "ear_base": (-0.088, 0.77, 1.03),
    "ear_tip": (-0.11, 0.75, 1.1),
    "shoulder": (-0.13, 0.5, 0.72),
    "elbow": (-0.14, 0.38, 0.48),
    "wrist": (-0.13, 0.43, 0.12),
    "front_toe": (-0.13, 0.53, 0.03),
    "hip": (-0.14, -0.56, 0.82),
    "knee": (-0.15, -0.38, 0.55),
    "hock": (-0.14, -0.72, 0.2),
    "hind_toe": (-0.13, -0.62, 0.03),
    "tail_base": (0, -0.72, 0.86),
    "tail_mid": (0, -1.05, 0.55),
    "tail_end": (0, -1.3, 0.35),
}

R = {
    "rump": (0.19, 0.27, 0.21), "rump_back": 0.02, "rump_drop": 0.16,
    "belly": (0.2, 0.55, 0.19), "belly_drop": 0.2,
    "chest": (0.22, 0.33, 0.28), "chest_back": 0.08, "chest_drop": 0.24,
    "torso_blend": 0.16,
    "neck_base": 0.2, "neck_top": 0.15, "neck_blend": 0.13,
    "skull": (0.13, 0.13, 0.12), "skull_pitch": -0.05, "head_blend": 0.07,
    "snout_root": (0, 0.09, -0.04), "snout_base": 0.085, "snout_end": 0.062, "snout_blend": 0.05,
    "jaw_base": 0.06, "jaw_end": 0.036, "jaw_blend": 0.025,
    "ear_width": 0.085, "ear_thick": 0.008, "ear_round": 0.024, "ear_yaw": 0.45, "ear_sink": 0.025,
    "ear_voxel": 0.003, "ear_fur": 0.01,
    "scapula": (0.1, 0.14, 0.2), "scapula_up": 0.13, "scapula_pitch": 0.3,
    "upper_arm": (0.13, 0.09), "forearm": (0.08, 0.06), "front_paw": (0.065, 0.06),
    "thigh": (0.17, 0.25, 0.26), "thigh_drop": 0.12, "thigh_pitch": -0.25,
    "upper_leg": (0.15, 0.09), "shin": (0.075, 0.056), "hind_paw": (0.062, 0.06),
    "limb_blend": 0.12, "joint_blend": 0.04,
    "tail": (0.06, 0.05, 0.045, 0.042), "tail_blend": 0.04,
}

COLORS = {
    "orange": "#cf6e24",
    "deep": "#a8521a",
    "white": "#efe8dc",
    "stripe": "#141010",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    W = p.mesh.region_weight
    p.fill("orange")
    p.top_darken("deep", start=0.3, strength=0.45)
    # White underside and face patches.
    p.region_underside("torso", "white", below=-0.35, soft=0.3)
    p.region_where("neck", "white", lambda v, n: p.smooth(-n[:, 2] * 0.8 + n[:, 1] * 0.4, 0.15, 0.3))
    p.region("jaw", "white")
    p.region_where("snout", "white", lambda v, n: p.smooth(-n[:, 2], -0.25, 0.35))
    p.region_where("cheek", "white", lambda v, n: p.smooth(0.92 - v[:, 2], 0.0, 0.04))
    for leg in ("front_lower", "hind_lower", "front_paw", "hind_paw"):
        p.region_where(leg, "white", lambda v, n: p.smooth(-n[:, 0] * np.sign(v[:, 0] + 1e-9), 0.1, 0.4), 0.7)
    for center, radius in creature.eyes:
        spot = center + np.array([np.sign(center[0]) * 0.004, 0.0, radius * 2.2])
        d = np.linalg.norm(v - spot, axis=1)
        p.blend("white", np.clip((radius * 1.2 - d) / (radius * 0.5), 0, 1))
    # Stripes: wavy bands down the body, rings round legs and tail.
    body = np.clip(W("torso") + W("neck") + W("thigh") + W("shoulder") + W("front_upper"), 0, 1)
    not_belly = 1 - p.smooth(-n[:, 2], 0.55, 0.3)
    p.stripes("stripe", lambda q: q[:, 1], frequency=10.0, width=0.17, wobble=0.35, breakup=0.9,
              mask=body * not_belly * p.smooth(n[:, 2], -0.6, 0.4))
    legs = np.clip(W("front_lower") + W("hind_lower"), 0, 1)
    p.stripes("stripe", lambda q: q[:, 2], frequency=9.0, width=0.15, wobble=0.25, breakup=0.8, seed=7,
              mask=legs * p.smooth(n[:, 0] * -np.sign(v[:, 0] + 1e-9), 0.0, 0.4) * p.smooth(v[:, 2] - 0.2, 0.0, 0.05))
    face = np.clip(W("head") + W("cheek"), 0, 1)
    p.stripes("stripe", lambda q: q[:, 2] + 0.5 * np.abs(q[:, 0]), frequency=26.0, width=0.13, wobble=0.2, breakup=0.8, seed=9,
              mask=face * p.smooth(np.abs(v[:, 0]) - 0.05, 0.0, 0.02))
    tail = np.clip(W("tail") + W("tail_tip"), 0, 1)
    tb, te = np.asarray(creature.joints["tail_base"]), np.asarray(creature.joints["tail_tip_end"])
    along = lambda q: (q - tb) @ (te - tb) / ((te - tb) @ (te - tb))
    p.stripes("stripe", along, frequency=9.0, width=0.22, mask=tail)
    p.blend("stripe", tail * p.smooth(along(v) - 0.92, 0.0, 0.03))
    # Ears: black backs.
    p.region("ear", "stripe", 0.85)
    p.region_where("ear", "white", lambda v, n: p.smooth(n[:, 1], 0.4, 0.3), 0.8)
    p.speckle(0.06)
    return p.colors


def make():
    c = quadruped("tiger", J, R, paint=paint, tiles_long=2.4)
    c.voxel = 0.007
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.1, 0.8, 0.86), (0.085, 0.09, 0.085), "cheek", "head", blend=0.06, yaw=side * 0.3))
    add_face(c, eye_dir=(-0.48, 0.82, 0.32), eye_radius=0.016, eye_sink=0.009, nose_radius=0.024, nose_sink=0.01,
             iris="#d0a030", pupil="round")
    c.extras[-1].color = "#c98a7a"     # pinkish nose
    c.fur = {"variation": 0.08, "sheen": 0.3, "bump": 0.25, "length": 0.035, "density": 14000, "hair_gamma": 1.8,
             "lengths": {"cheek": 1.3, "tail": 0.8, "tail_tip": 0.8, "neck": 1.0}}
    c.motion = {"gait": "walk", "attack": "pounce_bite", "stride": 1.0}
    c.palette = {"eye_line_size": 1.5}
    return c
