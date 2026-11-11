"""Hyacinth Macaw as a toy: cobalt blue all over, with a bright yellow ring
round each eye and a yellow patch beside its great dark hooked beak, deeper
blue flight feathers, and a long pointed tail.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "blue": "#3158dc",
    "deep": "#2443ab",
    "yellow": "#ffd43f",
    "beak": "#33363e",
    "foot": "#4b4e57",
}


def make():
    # (A bird has no withers to measure by: its sizes are in units of 13 cm.)
    d = Design("hyacinth_macaw", COLORS, "blue", unit=0.13)
    d.shorten_wings(0.55)
    d.torso(rump=(0.56, 0.7, 0.52), chest=(0.64, 0.64, 0.6), rump_at=(0, 0.25, 0), chest_at=(0, -0.1, 0), blend=0.2)
    d.neck(0.48, 0.46)
    d.head((0.66, 0.62, 0.62), at=(0, -0.05, 0.08))
    # A parrot's beak: big, deep and strongly hooked.
    d.beak(root=(0, 0.32, -0.02), base=0.3, end=0.13, hook=0.3, tip=(0, -0.22, 0.08))
    d.jaw(0.17, 0.1, tip=(0, -0.26, 0))
    d.wings((1.55, 1.45, 1.15), thick=0.1)
    # Its long tail, tapering to a point.
    d.flat(d.p("tail_base", (-0.34, 0.3, 0)), d.p("tail_base", (0.34, 0.3, 0)), "tail_end", 0.09, 0.1, "tail", "tail1", blend=0.08)
    d.bird_legs(0.1, (0.16, 0.19, 0.09))
    d.eye(toward=(-0.66, 0.7, 0.2), radius=0.12, offset=(0, -0.05, 0.08))

    d.paint("deep", both(part("wing"), d.behind("spine_mid", (0, 0.12, 0))))
    d.paint("deep", both(part("tail"), d.behind("tail_base", (0, -0.5, 0))))
    d.paint("beak", part("beak", "jaw"))
    # Yellow: a ring round each eye, and a patch at the root of its lower beak.
    d.paint("yellow", both(part("head"), d.around("skull", (-0.42, 0.33, 0.2), (0.25, 0.25, 0.25), mirrored=True)))
    d.paint("yellow", both(part("head", "jaw"), d.around("jaw_hinge", (-0.3, 0.0, -0.06), (0.16, 0.2, 0.2), mirrored=True)))
    d.paint("foot", part("foot"))
    return d.toy()
