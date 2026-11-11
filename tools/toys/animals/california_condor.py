"""California Condor as a toy: a big round black body on the widest wings
in the game, their tips spread in fingers, a bald orange head held high
over a black ruff, a pale hooked beak, a white bar along each wing, and
grey feet dangling under it.
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
    d.bird_stance(head=(0, -0.1, 0.6), foot=(-0.32, 0.05, -1.0))
    d.shorten_wings(0.37)
    d.put("beak_tip", "skull", (0, 1.04, -0.24))
    d.put("jaw_hinge", "skull", (0, 0.6, -0.36))
    d.put("chin", "skull", (0, 0.94, -0.42))
    d.torso(rump=(0.76, 0.84, 0.72), chest=(0.86, 0.78, 0.82), rump_at=(0, 0.35, 0), chest_at=(0, -0.15, 0.05), blend=0.2)
    # A bare neck, out of a ruff of feathers round its root.
    d.neck(0.42, 0.4, part_name="neck")
    d.blob(d.p("neck_base", (0, 0.05, 0.3)), (0.72, 0.5, 0.36), "ruff", "neck", blend=0.08)
    d.head((0.9, 0.78, 0.84))
    d.beak(root=(0, 0.56, -0.18), base=0.26, end=0.12, hook=0.22)
    d.jaw(0.13, 0.07)
    d.wings((1.45, 1.35, 1.05), thick=0.13)
    d.wing_fingers(4, 0.56, 0.17)
    d.tail_fan(1.3, root=0.5)
    d.bird_legs(0.15, (0.24, 0.28, 0.14))
    d.eye(toward=(-0.5, 0.84, 0.14), radius=0.2)

    d.paint("head", part("head", "neck"))
    # A white bar along the top of each wing, and white under them next to its body.
    d.paint("white", both(part("wing"), facing((0, 0, 1), 0.2), d.behind("spine_mid", (0, 0.5, 0)), d.ahead("spine_mid", (0, 0.14, 0)),
                          d.off_middle(0.95)))
    d.paint("white", both(part("wing"), facing((0, 0, -1), 0.3), d.ahead("spine_mid", (0, 0.0, 0))))
    d.paint("beak", part("beak", "jaw"))
    d.paint("foot", part("leg", "foot"))
    return d.toy()
