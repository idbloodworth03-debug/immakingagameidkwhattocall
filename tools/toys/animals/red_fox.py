"""Red Fox as a toy: a small orange bean of a body on four dark stick legs,
a big wedge of a head with cheek tufts and a short white muzzle, tall ears
with dark tips, button eyes, and a plume of a tail with a white tip (the
part of a fox you see from behind).
"""
import numpy as np

from kit import Design, both, part, side

COLORS = {
    "orange": "#ee7b2b",
    "white": "#fff4e4",
    "dark": "#43302c",
    "inner": "#ffd3ad",
}


def make():
    d = Design("red_fox", COLORS, "orange", changes={
        # Ears a little shorter than the old model's, and a plume carried up.
        "ear_base": (-0.08, 0.27, 0.612), "ear_tip": (-0.112, 0.262, 0.805),
        "tail_base": (0, -0.17, 0.275), "tail_mid": (0, -0.275, 0.355), "tail_end": (0, -0.355, 0.455),
        "tail_tip_end": (0, -0.385, 0.5),
    })
    # Body: one bean, and a short neck up to the head.
    d.torso(rump=(0.29, 0.38, 0.29), chest=(0.29, 0.31, 0.3), rump_at=(0, 0.1, -0.12), chest_at=(0, -0.03, -0.1))
    d.neck(0.27, 0.25)
    # Head: a wide soft wedge, cheek tufts, a short muzzle.
    d.head((0.44, 0.39, 0.36))
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.23, 0.04, -0.11), k)), d.p("skull", side((-0.56, -0.07, -0.17), k)), 0.18, 0.04,
                                "cheek", "head", blend=0.12))
    d.muzzle(root=(0, 0.23, -0.1), base=0.2, end=0.097)
    d.nose("snout_tip", (0, 0.07, 0.013), (0.09, 0.067, 0.07))
    d.ears_pointed(width=0.39)
    d.legs(front=(0.12, 0.113, 0.103), hind=(0.127, 0.117, 0.103), paw=(0.11, 0.14, 0.093))
    d.tail((0.16, 0.31, 0.23, 0.067))
    d.eye(toward=(-0.6, 0.76, 0.13), radius=0.14)

    # White chest and belly, lower face and tail tip; dark legs and ears.
    d.paint("white", both(d.around("withers", (0, 0.15, -0.28), (0.23, 0.5, 0.42)), part("torso")))
    skull, u = d.j("skull"), d.u
    line = lambda s: (skull[2] - 0.1 * u - 0.10 * np.clip(np.abs(s.v[:, 0]) - 0.1 * u, 0, None)
                      + 0.18 * np.clip(s.v[:, 1] - (skull[1] + 0.35 * u), 0, None) - s.v[:, 2])
    d.paint("white", both(part("head", "cheek", "muzzle"), line))
    along = d.j("tail_end") - d.j("tail_base")
    d.paint("white", both(part("tail"), d.beyond(d.j("tail_base") + along * 0.66, (0, 0, 0), along)))
    d.paint("dark", part("leg"))
    d.paint("inner", d.ear_fronts())
    d.paint("dark", d.ear_backs())
    d.paint("dark", d.ear_tips(0.36))
    return d.toy()
