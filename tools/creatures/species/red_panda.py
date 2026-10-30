"""Red Panda: small and fluffy, round face with a short muzzle, big pointed
ears with white rims, long bushy tail with red and buff rings. Rusty red
above, black legs and belly, white muzzle, cheeks and brows, and a red-brown
"tear" streak below each eye.

Real size: about 25 cm at the shoulder, 55 cm head and body, 45 cm tail.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid

J = {
    "pelvis": (0, -0.17, 0.27),
    "spine_mid": (0, 0.0, 0.275),
    "withers": (0, 0.15, 0.26),
    "neck_base": (0, 0.18, 0.24),
    "head_base": (0, 0.25, 0.28),
    "skull": (0, 0.28, 0.29),
    "snout_tip": (0, 0.36, 0.255),
    "jaw_hinge": (0, 0.28, 0.255),
    "chin": (0, 0.34, 0.24),
    "ear_base": (-0.042, 0.27, 0.33),
    "ear_tip": (-0.06, 0.26, 0.38),
    "shoulder": (-0.045, 0.17, 0.19),
    "elbow": (-0.05, 0.12, 0.12),
    "wrist": (-0.045, 0.15, 0.035),
    "front_toe": (-0.045, 0.19, 0.01),
    "hip": (-0.05, -0.17, 0.23),
    "knee": (-0.055, -0.1, 0.15),
    "hock": (-0.05, -0.2, 0.045),
    "hind_toe": (-0.045, -0.13, 0.01),
    "tail_base": (0, -0.25, 0.25),
    "tail_mid": (0, -0.43, 0.2),
    "tail_end": (0, -0.6, 0.17),
}

R = {
    "rump": (0.085, 0.11, 0.085), "rump_back": 0.01, "rump_drop": 0.05,
    "belly": (0.09, 0.17, 0.08), "belly_drop": 0.06,
    "chest": (0.082, 0.1, 0.08), "chest_back": 0.02, "chest_drop": 0.06,
    "torso_blend": 0.08,
    "neck_base": 0.06, "neck_top": 0.05, "neck_blend": 0.05,
    "skull": (0.058, 0.05, 0.048), "skull_pitch": -0.05, "head_blend": 0.035,
    "snout_root": (0, 0.032, -0.014), "snout_base": 0.028, "snout_end": 0.016, "snout_blend": 0.022,
    "jaw_base": 0.017, "jaw_end": 0.01, "jaw_blend": 0.01,
    "ear_width": 0.05, "ear_thick": 0.004, "ear_round": 0.011, "ear_yaw": 0.5, "ear_sink": 0.012,
    "ear_fur": 0.007,
    "scapula": (0.03, 0.045, 0.055), "scapula_up": 0.035, "scapula_pitch": 0.3,
    "upper_arm": (0.036, 0.026), "forearm": (0.024, 0.019), "front_paw": (0.019, 0.018),
    "thigh": (0.048, 0.065, 0.07), "thigh_drop": 0.03, "thigh_pitch": -0.2,
    "upper_leg": (0.044, 0.03), "shin": (0.024, 0.019), "hind_paw": (0.019, 0.019),
    "limb_blend": 0.035, "joint_blend": 0.012,
    "tail": (0.036, 0.045, 0.042, 0.034), "tail_blend": 0.03,
}

COLORS = {
    "rust": "#983815",
    "deep": "#7c2c12",
    "black": "#1c1310",
    "white": "#efe8dc",
    "buff": "#c98a4e",
    "tear": "#6e2a14",
}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    W = p.mesh.region_weight
    p.fill("rust")
    p.top_darken("deep", start=0.5, strength=0.3)
    # Black legs and belly.
    for leg in ("front_lower", "front_paw", "hind_lower", "hind_paw", "front_upper"):
        p.region(leg, "black")
    p.region_where("thigh", "black", lambda v, n: p.smooth(0.2 - v[:, 2], 0.0, 0.04))
    p.region_underside("torso", "black", below=-0.35, soft=0.3)
    p.region_where("neck", "black", lambda v, n: p.smooth(-n[:, 2], 0.3, 0.3))
    # White face: muzzle, cheeks and brows; a red-brown tear streak under each eye.
    p.region("snout", "white")
    p.region("jaw", "white")
    p.region("cheek", "white")
    face = W("head")
    for center, radius in creature.eyes:
        side = np.sign(center[0])
        brow = center + np.array([side * 0.004, -0.004, radius * 2.3])
        p.blend("white", face * np.clip((radius * 1.4 - np.linalg.norm(v - brow, axis=1)) / (radius * 0.5), 0, 1))
        a = np.array([center[1], center[2] - radius])
        b = np.array([0.315, 0.245])
        yz = v[:, 1:3]
        t = np.clip((yz - a) @ (b - a) / ((b - a) @ (b - a)), 0, 1)
        d = np.linalg.norm(yz - (a + np.outer(t, b - a)), axis=1)
        on_side = p.smooth(v[:, 0] * side, 0.012, 0.01)
        p.blend("tear", np.clip((0.009 - d) / 0.004, 0, 1) * on_side * (W("cheek") + W("head") + W("snout")))
    # Ears: rusty backs, white rims and insides.
    p.region("ear", "rust")
    p.region_where("ear", "white", lambda v, n: np.maximum(p.smooth(n[:, 1], 0.3, 0.3), p.smooth(v[:, 2] - 0.36, 0.0, 0.01)))
    # Tail rings.
    tb, te = np.asarray(creature.joints["tail_base"]), np.asarray(creature.joints["tail_tip_end"])
    along = lambda q: (q - tb) @ (te - tb) / ((te - tb) @ (te - tb))
    tail = W("tail") + W("tail_tip")
    p.stripes("buff", along, frequency=6.0, width=0.25, mask=tail * p.smooth(along(v), 0.1, 0.05))
    p.blend("deep", tail * p.smooth(along(v) - 0.9, 0.0, 0.05))
    p.speckle(0.08)
    return p.colors


def make():
    c = quadruped("red_panda", J, R, paint=paint, tiles_long=1.35)
    c.voxel = 0.0028
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.045, 0.285, 0.262), (0.034, 0.034, 0.032), "cheek", "head", blend=0.025))
    tm, te = np.asarray(J["tail_mid"]), np.asarray(J["tail_end"])
    c.shapes.append(ellipsoid((tm + te) / 2, (0.05, 0.13, 0.048), "tail", "tail2", blend=0.04,
                              pitch=np.arctan2(tm[2] - te[2], tm[1] - te[1])))
    add_face(c, eye_dir=(-0.5, 0.8, 0.3), eye_radius=0.008, eye_sink=0.004, nose_radius=0.008, nose_sink=0.004,
             iris="#1a0e08", pupil="round")
    c.fur = {"variation": 0.12, "sheen": 0.3, "bump": 0.3, "length": 0.035, "density": 60000, "hair_gamma": 2.2,
             "lengths": {"cheek": 0.9, "tail": 1.3, "tail_tip": 1.2, "torso": 0.9, "neck": 0.9}}
    c.motion = {"gait": "walk", "attack": "swipe", "rear": 0.4, "stride": 1.1}
    c.palette = {"eye_line": "#3a1a10", "eye_line_size": 1.6}
    return c
