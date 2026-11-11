"""Kraken as a toy: a cheeky little sea monster. A big coral-red bulb of a
head with pale spots on top, huge friendly eyes and a grin, on eight
curling tentacles that are pale underneath: four to walk on, one out to
each side and two trailing behind.
"""
import numpy as np
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "red": "#ee664e",
    "spot": "#ffa58c",
    "sucker": "#ffd9c2",
    "mouth": "#8b2b2b",
}

SPOTS = [(0.0, -0.1, 1.0), (-0.62, 0.2, 0.8), (0.62, 0.2, 0.8), (-0.35, -0.8, 0.7), (0.4, -0.75, 0.7)]


def make():
    # (Built on a four-legged skeleton: its legs are four of its tentacles, splayed as its skeleton has them.)
    d = Design("kraken", COLORS, "red", straight_legs=False)
    # Its head: a big bulb over a round skirt where the tentacles join.
    d.blob(d.p("skull", (0, -0.08, 0.1)), (1.2, 1.25, 1.3), "head", "head", blend=0.0)
    d.blob(d.p("spine_mid", (0, 0, 0.1)), (0.95, 0.95, 0.7), "skirt", "chest", blend=0.3)

    def tentacle(points, radii, bones, tip_up=0.3):
        for a, b, ra, rb, bone in zip(points, points[1:], radii, radii[1:], bones):
            d.stick(a, b, ra, rb, "tentacle", bone, blend=0.08)
        # Its tip curls up.
        end, before = np.asarray(points[-1], float), np.asarray(points[-2], float)
        out = (end - before) / np.linalg.norm(end - before)
        d.stick(end, end + (out * 0.3 + np.array([0.0, 0.0, tip_up])) * d.u, radii[-1], radii[-1] * 0.7, "tentacle", bones[-1], blend=0.08)

    def tentacles(s, k):
        for kind, names in (("fl", ("shoulder", "elbow", "wrist", "front_toe")), ("hl", ("hip", "knee", "hock", "hind_toe"))):
            tentacle([d.j(n + s) for n in names], (0.42, 0.35, 0.27, 0.2), [f"{kind}_upper{s}", f"{kind}_lower{s}", f"{kind}_foot{s}"])
        # One out to each side, and two trailing behind along its tail.
        tentacle([d.p("spine_mid", side((-0.55, 0, -0.3), k)), d.p("spine_mid", side((-1.5, 0, -0.62), k)),
                  d.p("spine_mid", side((-2.2, 0.1, -0.7), k))], (0.36, 0.28, 0.19), ["chest", "chest"])
        tentacle([d.p(j, side((-0.28, 0, 0), k)) for j in ("tail_base", "tail_mid", "tail_end", "tail_tip_end")],
                 (0.36, 0.3, 0.22, 0.16), ["tail1", "tail2", "tail3"], tip_up=0.25)
    d.pair(tentacles)
    d.eye(toward=(-0.46, 0.89, 0.0), radius=0.36, offset=(0, -0.08, -0.15))

    d.paint("spot", both(part("head"), either(*[d.around("skull", at, (0.3, 0.3, 0.9)) for at in SPOTS])))
    d.paint("sucker", both(part("tentacle"), facing((0, 0, -1), 0.25)))
    # Its grin: a crescent low on the front of its head.
    d.paint("mouth", both(part("head"), but(d.around("skull", (0, 0.9, -0.74), (0.46, 0.5, 0.2)),
                                             d.around("skull", (0, 0.9, -0.58), (0.62, 0.6, 0.2)))))
    return d.toy()
