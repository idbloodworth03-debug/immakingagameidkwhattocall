"""Wolf as a toy: a grey bean on four sturdy legs, a thick ruff of a neck,
a longer muzzle than the fox's, upright ears, a pale mask, chest and socks,
a dark saddle down its back and a bushy tail carried low with a dark tip.
"""
import numpy as np

from kit import Design, both, but, facing, part, side

COLORS = {
    "grey": "#76808f",
    "pale": "#eceff2",
    "dark": "#3c414f",
    "inner": "#f3cfc8",
}


def make():
    d = Design("wolf_pack", COLORS, "grey", changes={
        "ear_base": (-0.14, 0.47, 1.135), "ear_tip": (-0.185, 0.45, 1.4),
        # A bushy tail carried low, out behind it.
        "tail_base": (0, -0.36, 0.55), "tail_mid": (0, -0.53, 0.43), "tail_end": (0, -0.66, 0.29), "tail_tip_end": (0, -0.7, 0.23),
    })
    d.torso(rump=(0.3, 0.38, 0.3), chest=(0.32, 0.34, 0.34), rump_at=(0, 0.08, -0.12), chest_at=(0, -0.03, -0.1))
    d.neck(0.33, 0.3)
    d.head((0.43, 0.39, 0.36))
    # The ruff: cheek tufts swept out and down.
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.22, 0.02, -0.14), k)), d.p("skull", side((-0.55, -0.1, -0.3), k)), 0.2, 0.05,
                                "cheek", "head", blend=0.12))
    d.muzzle(root=(0, 0.2, -0.08), base=0.21, end=0.115)
    d.nose("snout_tip", (0, 0.07, 0.02), (0.1, 0.075, 0.075))
    d.ears_pointed(width=0.36, turn=0.3)
    d.legs(front=(0.13, 0.12, 0.11), hind=(0.14, 0.125, 0.11), paw=(0.12, 0.15, 0.1))
    d.tail((0.15, 0.27, 0.21, 0.07))
    d.eye(toward=(-0.58, 0.78, 0.14), radius=0.13)

    # A pale chest, belly, mask and socks; a dark saddle, ear tips and tail tip.
    d.paint("pale", both(d.around("withers", (0, 0.1, -0.3), (0.26, 0.55, 0.42)), part("torso")))
    skull, u = d.j("skull"), d.u
    line = lambda s: (skull[2] - 0.06 * u - 0.12 * np.clip(np.abs(s.v[:, 0]) - 0.1 * u, 0, None)
                      + 0.2 * np.clip(s.v[:, 1] - (skull[1] + 0.33 * u), 0, None) - s.v[:, 2])
    d.paint("pale", both(part("head", "cheek", "muzzle"), line))
    d.paint("pale", both(part("leg"), d.below("wrist.L", (0, 0, 0.1))))
    d.paint("dark", both(part("torso"), d.above("withers", (0, 0, 0.0)), d.behind("withers", (0, 0.3, 0))))
    along = d.j("tail_end") - d.j("tail_base")
    d.paint("dark", both(part("tail"), d.beyond(d.j("tail_base") + along * 0.72, (0, 0, 0), along)))
    d.paint("inner", d.ear_fronts())
    d.paint("dark", d.ear_backs())
    d.paint("dark", d.ear_tips(0.3))
    return d.toy()
