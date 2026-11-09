"""Barn owl: a white heart-shaped face with a buff rim, dark eyes, golden
buff and soft grey upperparts finely speckled, white underparts, short
tail and broad rounded wings.

Real size: about 35 cm long, 1 m wingspan.
"""
from anatomy import bird
from birdkit import finish, flying, layout, masks
import numpy as np
from paint import Painter
from sdf import ellipsoid

SPAN = 1.0
J, R = layout(SPAN, body=0.85, girth=1.3, neck=0.6, head=1.65, beak=(0.45, 1.0), hook=0.8, tail=(0.6, 1.0),
              chord=1.15, fingers=0, legs=0.9, fan=0.4)
COLORS = {"white": "#f7f2e8", "buff": "#d9a75e", "grey": "#a9a49b", "rim": "#b9824a", "speck": "#5a4a3a",
          "beak": "#e8d8c0"}


def paint(mesh, creature):
    p = Painter(mesh, COLORS)
    up, down, out = masks(p, SPAN)
    v = p.v
    p.fill("white")
    p.blend("buff", up)
    p.blend("grey", up * p.mesh.region_weight("wing") * p.smooth(out - 0.3, 0.0, 0.2) * 0.6)
    p.spots("speck", cell=SPAN * 0.04, radius=SPAN * 0.005, mask=up * 0.8)
    face = p.mesh.region_weight("face")
    p.blend("white", face)
    # (A design may paint the face as a heart: white inside a heart shape on
    # the front of the head, outlined in the rim color, buff round it: R
    # face_heart, the heart's size as a share of the head.)
    heart = float(getattr(creature, "face_heart", 0.0))
    if heart > 0:
        head = p.mesh.region_weight("head") + face
        sel = head > 0.5
        lo, hi = v[sel].min(axis=0), v[sel].max(axis=0)
        mid = (lo + hi) / 2
        u = (v[:, 0] - mid[0]) / ((hi[0] - lo[0]) * 0.5 * heart)
        w = (v[:, 2] - mid[2]) / ((hi[2] - lo[2]) * 0.5 * heart) + 0.2
        f = u * u + (1.25 * w - np.sqrt(np.abs(u))) ** 2
        front = np.clip((p.n[:, 1] + 0.1) * 3.0, 0, 1) * np.clip(head, 0, 1)
        inside = np.clip((1.0 - f) * 6.0, 0, 1) * front
        band = np.clip((1.25 - f) * 6.0, 0, 1) * front
        p.blend("buff", np.clip(head, 0, 1) * (1.0 - band))
        p.blend("rim", band * (1.0 - inside))
        p.blend("white", inside)
    if heart <= 0:
        p.blend("rim", p.mesh.region_weight("head") * up * 0.5)
    p.region("beak", "beak")
    p.region("leg", "white")
    return p.colors


def make():
    c = bird("barn_owl", J, R, paint=paint, tiles_long=1.3)
    c.face_heart = float(R.get("face_heart", 0.0))
    # The flat, heart-shaped face disc.
    sk = J["skull"]
    k = R.get("face_k", 1.0)
    c.shapes.append(ellipsoid((0, sk[1] + R["skull"][1] * 0.55, sk[2] - R["skull"][2] * 0.05),
                              (R["skull"][0] * 1.05 * k, R["skull"][1] * 0.35, R["skull"][2] * 1.05 * k), "face", "head", blend=R["skull"][0] * 0.3))
    # (A design may give the disc a heart's two rounded tops: R face_lobes.)
    lobes = R.get("face_lobes", 0.0)
    if lobes > 0:
        for side in (1, -1):
            c.shapes.append(ellipsoid((side * R["skull"][0] * 0.45 * k, sk[1] + R["skull"][1] * 0.5, sk[2] + R["skull"][2] * 0.55 * k),
                                      (R["skull"][0] * 0.6 * lobes * k, R["skull"][1] * 0.3, R["skull"][2] * 0.55 * lobes * k), "face", "head",
                                      blend=R["skull"][0] * 0.2))
    finish(c, R, iris="#160c06", eye_dir=(-0.42, 0.88, 0.15), eye=0.3)
    c = flying(c, SPAN, flap=0.6, hover=0.45)
    # Its second attack, alternating with the first (common animals).
    c.motion["attack2"] = "rake"
    return c
