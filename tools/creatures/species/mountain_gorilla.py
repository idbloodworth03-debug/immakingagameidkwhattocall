"""Mountain gorilla, a silverback standing tall: a huge chest and
shoulders, long powerful arms, short legs, a high crest on the head, a
black leathery face with a broad nose and small ears. Long thick black fur
with a silver saddle across the back.

Real size: about 1.7 m standing.
Built from the bonobo's upright body, scaled up and bulked out.
"""
import numpy as np

from anatomy import add_face, quadruped
from paint import Painter
from sdf import ellipsoid
from bonobo import J as BJ, R as BR

K = 1.35
J = {key: tuple(np.asarray(v, float) * K) for key, v in BJ.items()}
J.update({"shoulder": (-0.21, 0.0, 0.88), "elbow": (-0.3, 0.05, 0.64), "wrist": (-0.32, 0.1, 0.4), "front_toe": (-0.32, 0.14, 0.3),
          "snout_tip": (0, 0.135, 1.05)})
R = {key: (tuple(np.asarray(v) * K) if isinstance(v, tuple) else v * K) for key, v in BR.items()}
R.update({"chest": (0.22, 0.14, 0.17), "belly": (0.19, 0.14, 0.15), "rump": (0.15, 0.12, 0.12),
          "neck_base": 0.09, "neck_top": 0.08, "skull": (0.1, 0.095, 0.105), "snout_base": 0.06, "snout_end": 0.05,
          "upper_arm": (0.09, 0.07), "forearm": (0.072, 0.06), "front_paw": (0.06, 0.05),
          "upper_leg": (0.08, 0.06), "shin": (0.06, 0.05), "hind_paw": (0.05, 0.045),
          "ear_width": 0.03, "ear_round": 0.015})

COLORS = {"fur": "#2a2829", "silver": "#b4b3b0", "face": "#5e5558", "chest": "#45403f", "palm": "#5a5052"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    v, n = p.v, p.n
    p.fill("fur")
    # The silver saddle across the lower back.
    back = p.smooth(-n[:, 1], 0.2, 0.4) * p.smooth(v[:, 2] - 0.55, 0.0, 0.06) * p.smooth(0.9 - v[:, 2], 0.0, 0.08)
    p.blend("silver", back * p.mesh.region_weight("torso"))
    # A bare dark-gray chest and a gray leathery face.
    p.blend("chest", p.smooth(n[:, 1], 0.4, 0.3) * p.smooth(v[:, 2] - 0.7, 0.0, 0.05) * p.smooth(0.92 - v[:, 2], 0.0, 0.05)
            * p.smooth(0.11 - np.abs(v[:, 0]), 0.0, 0.04) * p.mesh.region_weight("torso"))
    for region in ("face", "snout", "jaw"):
        p.region(region, "face")
    p.region("front_paw", "palm", 0.7)
    p.region("hind_paw", "palm", 0.7)
    p.speckle(0.08)
    return p.colors


def make():
    c = quadruped("mountain_gorilla", J, R, paint=paint, tiles_long=1.7)
    c.voxel = 0.006
    sk = np.asarray(J["skull"], float)
    # The tall crest, a heavy brow and a broad face.
    c.shapes.append(ellipsoid(tuple(sk + (0, -0.02, 0.07)), (0.06, 0.08, 0.07), "head", "head", blend=0.05))
    c.shapes.append(ellipsoid(tuple(sk + (0, 0.085, 0.03)), (0.085, 0.03, 0.025), "face", "head", blend=0.02))
    c.shapes.append(ellipsoid(tuple(sk + (0, 0.1, -0.03)), (0.07, 0.035, 0.065), "face", "head", blend=0.025))
    # Big shoulders.
    for side in (1, -1):
        c.shapes.append(ellipsoid((side * 0.17, 0.0, 0.88), (0.1, 0.1, 0.1), "torso", "chest", blend=0.06))
    add_face(c, eye_dir=(-0.33, 0.92, 0.06), eye_radius=0.016, eye_sink=0.007, nose_radius=0.022, nose_sink=0.008,
             iris="#3b2412", pupil="round")
    c.fur = {"strands": False, "variation": 0.15, "sheen": 0.25, "bump": 0.35, "roughness": 0.75}
    c.motion = {"gait": "biped", "attack": "stomp", "rear": 0.0, "stride": 0.9, "cycle_tiles": 1.0}
    c.palette = {"eye_line": "#1d1715", "mouth": "#5a3a3a"}
    return c
