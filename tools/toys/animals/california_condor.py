"""California Condor as a toy: a big black body on the widest wings in the
game, their tips spread in fingers, a bare orange head and neck rising out
of a black ruff, a pale hooked beak, a white bar along each wing, and grey
feet.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "black": "#2c2c35",
    "head": "#f28b5b",
    "white": "#f5f2eb",
    "beak": "#eadcbf",
    "foot": "#9c9ca5",
}


def make():
    # (A bird has no withers to measure by: its sizes are in units of 32 cm.)
    d = Design("california_condor", COLORS, "black", unit=0.32)
    d.shorten_wings(0.62)
    d.torso(rump=(0.6, 0.72, 0.54), chest=(0.68, 0.66, 0.62), rump_at=(0, 0.25, 0), chest_at=(0, -0.1, 0), blend=0.2)
    # A bare neck, out of a ruff of feathers round its root.
    d.neck(0.3, 0.27, part_name="neck")
    d.blob(d.p("neck_base", (0, 0.0, 0.02)), (0.52, 0.3, 0.48), "ruff", "neck", blend=0.06)
    d.head((0.44, 0.46, 0.42), at=(0, 0, 0.02))
    d.beak(root=(0, 0.3, -0.05), base=0.17, end=0.085, hook=0.15)
    d.jaw(0.09, 0.05)
    d.wings((1.65, 1.55, 1.25), thick=0.1)
    d.wing_fingers(5, 0.7, 0.14)
    d.tail_fan(1.05)
    d.bird_legs(0.12, (0.18, 0.21, 0.1))
    d.eye(toward=(-0.64, 0.72, 0.22), radius=0.11, offset=(0, 0, 0.02))

    d.paint("head", part("head", "neck"))
    # A white bar along the top of each wing, and white under them next to its body.
    d.paint("white", both(part("wing"), facing((0, 0, 1), 0.2), d.behind("spine_mid", (0, 0.36, 0)), d.ahead("spine_mid", (0, 0.06, 0)),
                          d.near_middle(2.5), d.off_middle(0.75)))
    d.paint("white", both(part("wing"), facing((0, 0, -1), 0.25), d.near_middle(2.3), d.ahead("spine_mid", (0, 0.0, 0))))
    d.paint("beak", part("beak", "jaw"))
    d.paint("foot", part("leg", "foot"))
    return d.toy()
