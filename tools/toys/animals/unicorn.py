"""Unicorn as a toy: a white pony on slim legs with golden hooves, a long
neck up to a small head with a pink muzzle, a golden horn with a spiral
round it, and a mane and tail in bands of pink, violet and sky blue.
"""
import numpy as np
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "white": "#fdfbff",
    "gold": "#f4bf3a",
    "shine": "#fff1a6",
    "pink": "#ff8fc0",
    "violet": "#b08af0",
    "sky": "#7cc6ff",
    "muzzle": "#ffc7d9",
    "nose": "#d77a9c",
}


def make():
    d = Design("unicorn", COLORS, "white")
    d.torso(rump=(0.3, 0.36, 0.3), chest=(0.3, 0.33, 0.33), rump_at=(0, 0.06, -0.1), chest_at=(0, -0.05, -0.1))
    d.neck(0.24, 0.18)
    d.head((0.25, 0.28, 0.24))
    d.muzzle(root=(0, 0.12, -0.1), base=0.2, end=0.15)
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.06, 0.11, 0.05), k), (0.025, 0.02, 0.03)))
    # The horn, up and forward from its brow.
    d.stick(d.p("skull", (0, 0.14, 0.18)), d.p("skull", (0, 0.4, 0.95)), 0.075, 0.012, "horn", "head", blend=0.02)
    # The mane: locks down the back of its neck, and a forelock behind the horn.
    top, low = d.j("head_base"), d.j("neck_base")
    for k in range(6):
        t = k / 5.0
        at = top + (low - top) * t
        d.blob(d.p(at, (0, -0.2 - 0.03 * k, 0.06 - 0.02 * k)), (0.12, 0.17, 0.18), "mane%d" % (k // 2), "head" if k < 2 else "neck", blend=0.06)
    d.blob(d.p("skull", (0, -0.1, 0.24)), (0.13, 0.15, 0.12), "mane0", "head", blend=0.06)
    d.ears_pointed(width=0.13, thick=0.04, rounding=0.05)
    d.legs(front=(0.11, 0.085, 0.07), hind=(0.12, 0.09, 0.07), paw=(0.1, 0.12, 0.08))
    d.tail((0.09, 0.15, 0.14, 0.05))
    d.eye(toward=(-0.72, 0.62, 0.2), radius=0.085)

    d.paint("muzzle", both(part("muzzle"), d.ahead("snout_tip", (0, -0.03, 0))))
    d.paint("pink", part("mane0"))
    d.paint("violet", part("mane1"))
    d.paint("sky", part("mane2"))
    # The tail in the same three bands, from its root to its tip.
    base, along = d.j("tail_base"), d.j("tail_tip_end") - d.j("tail_base")
    d.paint("pink", part("tail"))
    d.paint("violet", both(part("tail"), d.beyond(base + along * 0.36, (0, 0, 0), along)))
    d.paint("sky", both(part("tail"), d.beyond(base + along * 0.7, (0, 0, 0), along)))
    # Gold: the horn with a paler spiral round it, and the hooves.
    d.paint("gold", part("horn"))
    d.paint("shine", both(part("horn"), d.bands("skull", (0, 0.14, 0.18), (0.5, 0.33, 1.0), 0.2, 0.42)))
    d.paint("gold", both(part("leg"), d.below("front_toe.L", (0, 0, 0.12))))
    d.paint("muzzle", d.ear_fronts())
    return d.toy()
