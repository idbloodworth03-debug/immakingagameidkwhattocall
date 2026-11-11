"""Unicorn as a toy: a chubby white pony on four thick legs with golden
hooves, a big head with a pink muzzle and big eyes, a golden horn with a
spiral round it, and a mane and tail in fat locks of pink, violet and sky
blue.
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
    # A toy pony's neck is short: its head comes down toward its shoulders.
    d.move(["head_base", "skull", "snout_tip", "jaw_hinge", "chin"], (0, 0.0, -0.3))
    d.put("ear_base", "skull", (-0.27, -0.1, 0.32))
    d.put("ear_tip", "skull", (-0.36, -0.14, 0.64))
    d.torso(rump=(0.4, 0.44, 0.4), chest=(0.4, 0.42, 0.43), rump_at=(0, 0.07, -0.1), chest_at=(0, -0.05, -0.12))
    d.neck(0.3, 0.26)
    d.head((0.44, 0.44, 0.4))
    d.muzzle(root=(0, 0.2, -0.12), base=0.28, end=0.2)
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.08, 0.15, 0.08), k), (0.03, 0.025, 0.035)))
    # The horn, up and forward from its brow.
    d.stick(d.p("skull", (0, 0.22, 0.3)), d.p("skull", (0, 0.5, 1.15)), 0.1, 0.02, "horn", "head", blend=0.02)
    # The mane: fat locks down the back of its neck, and a forelock behind the horn.
    top, low = d.j("head_base"), d.j("neck_base")
    for k in range(5):
        at = top + (low - top) * (k / 4.0)
        d.blob(d.p(at, (0, -0.26 - 0.02 * k, 0.12 - 0.03 * k)), (0.17, 0.21, 0.22), "mane%d" % (k * 3 // 5), "head" if k < 2 else "neck", blend=0.06)
    d.blob(d.p("skull", (0, -0.12, 0.4)), (0.19, 0.2, 0.16), "mane0", "head", blend=0.06)
    d.ears_pointed(width=0.2, thick=0.05, rounding=0.07)
    d.legs(front=(0.18, 0.16, 0.145), hind=(0.19, 0.165, 0.145), paw=(0.17, 0.2, 0.12))
    d.tail((0.13, 0.21, 0.2, 0.08))
    d.eye(toward=(-0.6, 0.76, 0.16), radius=0.125)

    d.paint("muzzle", both(part("muzzle"), d.ahead("snout_tip", (0, -0.06, 0))))
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
    d.paint("shine", both(part("horn"), d.bands("skull", (0, 0.22, 0.3), (0.5, 0.33, 1.0), 0.24, 0.42)))
    d.paint("gold", both(part("leg"), d.below("front_toe.L", (0, 0, 0.17))))
    d.paint("muzzle", d.ear_fronts())
    return d.toy()
