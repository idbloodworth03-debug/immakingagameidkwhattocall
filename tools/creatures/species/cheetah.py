"""Cheetah: built for speed. Very slender with long thin legs, a deep narrow
chest, tucked-up waist, small round head with a short muzzle and small
round ears. Golden coat with solid black spots, white belly, the black
"tear lines" from the eyes to the mouth, a long tail with dark rings near
the end and a white tip.

Real size: about 80 cm at the shoulder, 1.2 m head and body, 70 cm tail.
"""
import numpy as np

from anatomy import add_face, add_mouth, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.42, 0.80),
    "spine_mid": (0, -0.05, 0.775),
    "withers": (0, 0.32, 0.80),
    "neck_base": (0, 0.37, 0.72),
    "head_base": (0, 0.54, 0.83),
    "skull": (0, 0.585, 0.85),
    "snout_tip": (0, 0.705, 0.81),
    "jaw_hinge": (0, 0.585, 0.80),
    "chin": (0, 0.68, 0.77),
    "ear_base": (-0.048, 0.57, 0.905),
    "ear_tip": (-0.062, 0.555, 0.955),
    "shoulder": (-0.08, 0.36, 0.62),
    "elbow": (-0.085, 0.26, 0.44),
    "wrist": (-0.08, 0.29, 0.10),
    "front_toe": (-0.08, 0.35, 0.02),
    "hip": (-0.085, -0.42, 0.70),
    "knee": (-0.095, -0.28, 0.48),
    "hock": (-0.085, -0.56, 0.18),
    "hind_toe": (-0.08, -0.49, 0.02),
    "tail_base": (0, -0.55, 0.74),
    "tail_mid": (0, -0.84, 0.48),
    "tail_end": (0, -1.04, 0.30),
}

R = {
    "rump": (0.095, 0.15, 0.1), "rump_back": 0.02, "rump_drop": 0.1,
    "belly": (0.095, 0.32, 0.085), "belly_drop": 0.1,
    "chest": (0.115, 0.22, 0.17), "chest_back": 0.06, "chest_drop": 0.16,
    "torso_blend": 0.12,
    "neck_base": 0.11, "neck_top": 0.078, "neck_blend": 0.09,
    "skull": (0.07, 0.068, 0.064), "skull_pitch": -0.1, "head_blend": 0.04,
    "snout_root": (0, 0.05, -0.02), "snout_base": 0.045, "snout_end": 0.03, "snout_blend": 0.03,
    "jaw_base": 0.03, "jaw_end": 0.018, "jaw_blend": 0.015,
    "ear_width": 0.052, "ear_thick": 0.004, "ear_round": 0.014, "ear_yaw": 0.55, "ear_sink": 0.012,
    "ear_voxel": 0.0018, "ear_fur": 0.006,
    "scapula": (0.055, 0.085, 0.12), "scapula_up": 0.09, "scapula_pitch": 0.3,
    "upper_arm": (0.07, 0.045), "forearm": (0.037, 0.027), "front_paw": (0.027, 0.028),
    "thigh": (0.09, 0.14, 0.15), "thigh_drop": 0.07, "thigh_pitch": -0.25,
    "upper_leg": (0.085, 0.047), "shin": (0.037, 0.026), "hind_paw": (0.026, 0.027),
    "limb_blend": 0.07, "joint_blend": 0.022,
    "tail": (0.034, 0.028, 0.024, 0.021), "tail_blend": 0.03,
}

COLORS = {
    "gold": "#bd8640",
    "back": "#a06a2c",
    "white": "#efe7d8",
    "spot": "#16110e",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v = p.v
    p.fill("gold")
    p.top_darken("back", start=0.4, strength=0.4)
    p.region_underside("torso", "white", below=-0.35, soft=0.3)
    p.region("jaw", "white")
    p.region_where("neck", "white", lambda v, n: p.smooth(-n[:, 2] * 0.8 + n[:, 1] * 0.4, 0.15, 0.3))
    p.region_where("snout", "white", lambda v, n: p.smooth(-n[:, 2], -0.1, 0.4), 0.8)
    for part in ("front_lower", "hind_lower"):
        p.region_where(part, "white", lambda v, n: p.smooth(-n[:, 0] * np.sign(v[:, 0] + 1e-9), 0.2, 0.4), 0.4)
    # Solid black spots everywhere except the belly; small on the face.
    belly = p.smooth(-p.n[:, 2], 0.5, 0.3) * (p.mesh.region_weight("torso"))
    face = p.mesh.region_weight("head") + p.mesh.region_weight("snout") + p.mesh.region_weight("cheek") + p.mesh.region_weight("jaw")
    body = np.clip(1 - face - p.mesh.region_weight("tail") - p.mesh.region_weight("tail_tip") - p.mesh.region_weight("ear"), 0, 1)
    p.spots("spot", cell=0.042, radius=0.0115, mask=body * (1 - belly * 0.6), seed=11)
    p.spots("spot", cell=0.018, radius=0.0042, mask=face * p.smooth(v[:, 2] - 0.835, 0.0, 0.015), seed=12)
    # Tear lines: from the inner corner of each eye down to the corner of
    # the mouth, drawn on the face as seen from the side.
    for center, radius in creature.eyes:
        side = np.sign(center[0])
        a = np.array([center[1] + radius * 0.4, center[2] - radius * 0.7])
        b = np.array([0.665, 0.79])
        yz = v[:, 1:3]
        ab = b - a
        t = np.clip((yz - a) @ ab / (ab @ ab), 0, 1)
        d = np.linalg.norm(yz - (a + np.outer(t, ab)), axis=1)
        on_side = p.smooth(v[:, 0] * side, 0.01, 0.008) * p.smooth(0.06 - v[:, 0] * side, 0.0, 0.01)
        p.blend("spot", np.clip((0.0065 - d) / 0.0025, 0, 1) * on_side * face)
    # Tail: spots near the base, rings toward the end, white tip.
    tb, te = np.asarray(creature.joints["tail_base"]), np.asarray(creature.joints["tail_tip_end"])
    along = lambda q: (q - tb) @ (te - tb) / ((te - tb) @ (te - tb))
    tail = p.mesh.region_weight("tail") + p.mesh.region_weight("tail_tip")
    p.spots("spot", cell=0.04, radius=0.011, mask=tail * p.smooth(0.6 - along(v), 0.0, 0.1), seed=13)
    p.stripes("spot", along, frequency=9.0, width=0.24, mask=tail * p.smooth(along(v) - 0.62, 0.0, 0.05) * p.smooth(0.93 - along(v), 0.0, 0.02))
    p.blend("white", tail * p.smooth(along(v) - 0.94, 0.0, 0.03))
    p.region("ear", "back", 0.5)
    p.speckle(0.08)
    return p.colors


def make():
    c = quadruped("cheetah", J, R, paint=paint, tiles_long=1.9)
    c.voxel = 0.0045
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.045, 0.6, 0.805), (0.04, 0.045, 0.04), "cheek", "head", blend=0.03))
    add_mouth(c, center=(0, 0.66, 0.783), radii=(0.07, 0.07, 0.007), blend=0.004)
    add_face(c, eye_dir=(-0.5, 0.8, 0.3), eye_radius=0.012, eye_sink=0.007, nose_radius=0.012, nose_sink=0.006,
             iris="#b8862a", pupil="round")
    c.fur = {"variation": 0.1, "sheen": 0.3, "bump": 0.25, "length": 0.018, "density": 40000, "hair_gamma": 2.0,
             "lengths": {"tail": 1.0, "tail_tip": 1.0, "cheek": 1.0, "neck": 1.0}}
    c.motion = {"gait": "gallop", "attack": "pounce_bite", "stride": 1.25, "gape": 0.75}
    c.palette = {"eye_line_size": 1.45}
    return c
