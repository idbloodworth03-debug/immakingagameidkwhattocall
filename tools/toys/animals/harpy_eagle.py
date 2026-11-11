"""Harpy Eagle as a toy: a heavy dark body on broad wings with fingered
tips, a pale grey head with a double crest standing up behind it, a white
belly under a dark chest, white legs, huge yellow feet, a big hooked beak
and grey bands across its tail.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "dark": "#3d4453",
    "grey": "#bdc4cd",
    "white": "#f8f6f1",
    "yellow": "#f4c43d",
    "beak": "#30343c",
}


def make():
    # (A bird has no withers to measure by: its sizes are in units of 22 cm.)
    d = Design("harpy_eagle", COLORS, "dark", unit=0.22)
    d.shorten_wings(0.5)
    d.torso(rump=(0.58, 0.7, 0.52), chest=(0.66, 0.64, 0.6), rump_at=(0, 0.25, 0), chest_at=(0, -0.1, 0), blend=0.2)
    d.neck(0.48, 0.46)
    d.head((0.64, 0.58, 0.6), at=(0, -0.05, 0.08))
    # The crest: two tufts standing up and back from its crown.
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.2, -0.2, 0.5), k)), d.p("skull", side((-0.42, -0.5, 1.0), k)), 0.17, 0.05,
                                "crest", "head", blend=0.06))
    d.beak(root=(0, 0.38, -0.04), base=0.2, end=0.085, hook=0.17, tip=(0, -0.2, 0.05))
    d.jaw(0.11, 0.06, tip=(0, -0.2, 0))
    d.wings((1.55, 1.45, 1.15), thick=0.1)
    d.wing_fingers(4, 0.62, 0.14)
    d.tail_fan(1.15)
    d.bird_legs(0.14, (0.25, 0.29, 0.13))
    d.eye(toward=(-0.6, 0.76, 0.18), radius=0.13, offset=(0, -0.05, 0.08))

    d.paint("grey", part("head", "crest"))
    d.paint("dark", both(part("crest"), d.above("skull", (0, 0, 0.82))))
    # White underneath, behind its dark chest; white legs; grey bands across its tail.
    d.paint("white", both(part("torso"), facing((0, 0, -1), 0.1), d.behind("withers", (0, -0.25, 0))))
    d.paint("white", both(part("wing"), facing((0, 0, -1), 0.25)))
    d.paint("white", part("leg"))
    d.paint("grey", both(part("tail"), d.bands("tail_end", (0, 0.14, 0), (0, 1, 0), 0.56, 0.4)))
    d.paint("beak", part("beak", "jaw"))
    d.paint("yellow", both(part("beak"), d.behind("skull", (0, 0.6, 0))))
    d.paint("yellow", part("foot"))
    return d.toy()
