"""Snow leopard: a smoky-gray mountain cat with a thick coat, small round
ears, big furry paws and an enormous, very thick tail almost as long as its
body. Pale gray-cream fur with open charcoal rosettes, solid spots on the
head and legs, a white belly and pale green-gray eyes.

Real size: about 60 cm at the shoulder, 1.1 m head and body, 1 m tail.
Built from the leopard's skeleton.
"""
import numpy as np

from anatomy import add_face, quadruped
from sdf import ellipsoid
import amur_leopard as L

K = 0.66
J = dict(L.J)
J["ear_base"] = (-0.085, 0.76, 1.02)
J["ear_tip"] = (-0.1, 0.75, 1.07)
J["tail_mid"] = (0, -1.1, 0.5)
J["tail_end"] = (0, -1.42, 0.42)
R = dict(L.R)
R.update({"ear_width": 0.075, "ear_round": 0.03, "front_paw": (0.075, 0.072), "hind_paw": (0.072, 0.07),
          "tail": (0.085, 0.08, 0.075, 0.07), "rump": (0.2, 0.27, 0.22), "belly": (0.21, 0.55, 0.2), "chest": (0.23, 0.33, 0.29)})

COLORS = {
    "cream": "#dcd8cc",
    "gold": "#b9b4a6",
    "white": "#f6f4ee",
    "spot": "#3b3a3c",
    "center": "#a9a397",
}


def paint(mesh, creature):
    old = dict(L.COLORS)
    L.COLORS.update(COLORS)
    try:
        return L.paint(mesh, creature)
    finally:
        L.COLORS.clear()
        L.COLORS.update(old)


def make():
    c = quadruped("snow_leopard", L._scaled(J, K), L._scaled_r(R, K), paint=paint, tiles_long=1.9)
    c.voxel = 0.0048
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.1 * K, 0.8 * K, 0.86 * K), (0.09 * K, 0.095 * K, 0.09 * K), "cheek", "head",
                                  blend=0.06 * K, yaw=side * 0.3))
    # The huge fluffy tail.
    tm, te = np.asarray(c.joints["tail_mid"]), np.asarray(c.joints["tail_end"])
    c.shapes.append(ellipsoid((tm + te) / 2, (0.07, 0.18, 0.07), "tail", "tail2", blend=0.05,
                              pitch=np.arctan2(tm[2] - te[2], tm[1] - te[1])))
    add_face(c, eye_dir=(-0.48, 0.82, 0.32), eye_radius=0.017 * K, eye_sink=0.009 * K, nose_radius=0.024 * K, nose_sink=0.01 * K,
             iris="#9fb59a", pupil="round")
    c.extras[-1].color = "#c99a92"
    c.fur = {"variation": 0.06, "sheen": 0.3, "bump": 0.25, "length": 0.06, "density": 22000, "hair_gamma": 1.95,
             "lengths": {"cheek": 1.2, "tail": 1.5, "tail_tip": 1.4, "neck": 1.1, "torso": 1.0, "front_paw": 1.2, "hind_paw": 1.2}}
    c.motion = {"gait": "gallop", "attack": "pounce_bite", "stride": 1.15}
    c.palette = {"eye_line_size": 1.5}
    return c
