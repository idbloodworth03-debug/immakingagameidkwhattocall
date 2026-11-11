"""Gray Squirrel as a toy: a small grey body sat low on little legs, a round
head with fat white cheeks, two buck teeth and tufted ears, and its great
bushy tail curled up over its back, frosted white along its edges.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "grey": "#9d9ca6",
    "white": "#f8f5ee",
    "inner": "#f2b9b0",
    "nose": "#5b4046",
}


def make():
    # (A small animal with a big head: its sizes are in tenths of a meter.)
    d = Design("gray_squirrel", COLORS, "grey", unit=0.1)
    # Small ears with a tuft at the tip.
    d.put("ear_base", "skull", (-0.25, -0.04, 0.31))
    d.put("ear_tip", "skull", (-0.32, -0.06, 0.6))
    d.torso(rump=(0.41, 0.45, 0.44), chest=(0.35, 0.37, 0.37), rump_at=(0, 0.13, -0.1), chest_at=(0, -0.07, 0.0))
    d.neck(0.29, 0.28)
    d.head((0.48, 0.42, 0.42))
    d.pair(lambda s, k: d.blob(d.p("skull", side((-0.22, 0.14, -0.16), k)), (0.2, 0.2, 0.18), "head", "head", blend=0.1))
    d.muzzle(root=(0, 0.2, -0.1), base=0.19, end=0.11, tip=(0, -0.08, 0.08))
    d.nose("snout_tip", (0, 0.02, 0.1), (0.06, 0.045, 0.045))
    d.nose("snout_tip", (0, -0.05, -0.035), (0.04, 0.025, 0.035), color="white")
    d.ears_pointed(width=0.2, thick=0.05, rounding=0.06)
    d.legs(front=(0.1, 0.095, 0.09), hind=(0.13, 0.11, 0.09), paw=(0.1, 0.15, 0.07))
    d.tail((0.2, 0.38, 0.36, 0.2), blend=0.12)
    d.eye(toward=(-0.6, 0.76, 0.14), radius=0.125)

    d.paint("white", both(part("torso"), facing((0, 0.3, -1), 0.2)))
    d.paint("white", both(part("head", "muzzle"), d.below("skull", (0, 0, -0.12)), d.ahead("skull", (0, 0.05, 0))))
    d.paint("white", both(part("tail"), d.off_middle(0.3)))
    d.paint("inner", d.ear_fronts())
    return d.toy()
