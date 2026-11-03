"""Harbor seal: a plump, spotted seal that lies on its belly with a round
head, big dark eyes, a short whiskery muzzle, no ear flaps, short front
flippers and back flippers that trail behind like a fishtail. Silver-gray
with dark spots, a paler belly. On land it galumphs along on its belly.

Real size: about 1.6 m long.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid, plate

J = {
    "pelvis": (0, -0.34, 0.15),
    "spine_mid": (0, 0.0, 0.19),
    "withers": (0, 0.28, 0.21),
    "neck_base": (0, 0.36, 0.23),
    "head_base": (0, 0.46, 0.28),
    "skull": (0, 0.51, 0.3),
    "snout_tip": (0, 0.62, 0.27),
    "jaw_hinge": (0, 0.51, 0.25),
    "chin": (0, 0.6, 0.235),
    "ear_base": (-0.07, 0.5, 0.33),
    "ear_tip": (-0.072, 0.497, 0.336),
    "shoulder": (-0.13, 0.27, 0.13),
    "elbow": (-0.17, 0.29, 0.07),
    "wrist": (-0.19, 0.33, 0.03),
    "front_toe": (-0.2, 0.41, 0.012),
    "hip": (-0.07, -0.48, 0.11),
    "knee": (-0.08, -0.56, 0.09),
    "hock": (-0.085, -0.64, 0.08),
    "hind_toe": (-0.1, -0.76, 0.07),
    "tail_base": (0, -0.52, 0.12),
    "tail_mid": (0, -0.57, 0.11),
    "tail_end": (0, -0.6, 0.1),
}

R = {
    "rump": (0.15, 0.22, 0.12), "rump_back": 0.0, "rump_drop": 0.0,
    "belly": (0.23, 0.38, 0.18), "belly_drop": 0.0,
    "chest": (0.21, 0.22, 0.18), "chest_back": 0.0, "chest_drop": 0.0, "torso_blend": 0.12,
    "neck_base": 0.17, "neck_top": 0.13, "neck_blend": 0.1,
    "skull": (0.12, 0.12, 0.11), "head_blend": 0.06,
    "snout_root": (0, 0.06, -0.03), "snout_base": 0.07, "snout_end": 0.055, "snout_blend": 0.04,
    "jaw_base": 0.04, "jaw_end": 0.03, "jaw_blend": 0.02,
    "ear_width": 0.008, "ear_thick": 0.004, "ear_round": 0.004, "ear_yaw": 0.0, "ear_sink": 0.006, "ear_voxel": 0.002,
    "scapula": (0.06, 0.08, 0.07), "scapula_up": 0.0,
    "upper_arm": (0.06, 0.045), "forearm": (0.045, 0.035), "front_paw": (0.035, 0.012),
    "thigh": (0.08, 0.1, 0.07), "thigh_drop": 0.0,
    "upper_leg": (0.065, 0.05), "shin": (0.045, 0.035), "hind_paw": (0.03, 0.012),
    "limb_blend": 0.05, "joint_blend": 0.02,
    "tail": (0.03, 0.02, 0.012), "tail_blend": 0.02,
}

COLORS = {"gray": "#9aa0a3", "spot": "#4a4f54", "belly": "#d9d6cf", "dark": "#585d61"}


def flippers(c, J, front=0.05, hind=0.07, blend=0.02):
    """Webbed flippers: a fan at the end of each foot."""
    for side, sx in ((".L", 1), (".R", -1)):
        toe, wrist = np.asarray(J["front_toe"], float), np.asarray(J["wrist"], float)
        toe = toe * (sx, 1, 1)
        wrist = wrist * (sx, 1, 1)
        c.shapes.append(plate(wrist, toe + (-sx * front * 0.6, 0.0, 0.0), toe + (sx * front * 0.4, front * 0.3, 0.0), front * 0.18,
                              front * 0.12, "front_paw", "fl_foot" + side, blend=blend))
        hock, htoe = np.asarray(J["hock"], float) * (sx, 1, 1), np.asarray(J["hind_toe"], float) * (sx, 1, 1)
        c.shapes.append(plate(hock, htoe + (-sx * hind * 0.5, 0.0, 0.0), htoe + (sx * hind * 0.5, -hind * 0.2, 0.0), hind * 0.16,
                              hind * 0.1, "hind_paw", "hl_foot" + side, blend=blend))


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("gray")
    p.blend("belly", p.smooth(-n[:, 2], 0.1, 0.4) * 0.85)
    p.spots("spot", cell=0.06, radius=0.013, mask=p.smooth(n[:, 2], -0.1, 0.4) * (1 - p.mesh.region_weight("snout")), seed=5)
    p.region("front_paw", "dark", 0.6)
    p.region("hind_paw", "dark", 0.6)
    p.speckle(0.08)
    return p.colors


def make():
    c = quadruped("harbor_seal", J, R, paint=paint, tiles_long=1.6)
    c.voxel = 0.005
    # Whisker pads either side of the muzzle.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.04, 0.6, 0.26), (0.035, 0.03, 0.03), "snout", "head", blend=0.02))
    flippers(c, J)
    add_face(c, eye_dir=(-0.6, 0.72, 0.35), eye_radius=0.02, eye_sink=0.008, nose_radius=0.018, nose_sink=0.006,
             iris="#120e0c", pupil="round")
    c.fur = {"strands": False, "variation": 0.08, "sheen": 0.45, "bump": 0.1, "roughness": 0.45}
    c.motion = {"body": "pinniped", "attack": "bite", "gape": 0.6, "cycle_tiles": 0.8}
    return c
