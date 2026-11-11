"""Peregrine Falcon as a toy: a slate-blue bullet of a body with pointed
swept wings, a dark cap and a dark stripe down each cream cheek, a cream
chest with slate bars, a short hooked beak with a yellow base, and yellow
feet.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "slate": "#647a93",
    "dark": "#2e3848",
    "cream": "#fcf4e0",
    "yellow": "#f7c83d",
    "beak": "#39424f",
}


def make():
    # (A bird has no withers to measure by: its sizes are in units of 10.5 cm.)
    d = Design("peregrine_falcon", COLORS, "slate", unit=0.105)
    d.torso(rump=(0.56, 0.7, 0.5), chest=(0.64, 0.62, 0.58), rump_at=(0, 0.25, 0), chest_at=(0, -0.1, 0), blend=0.2)
    d.neck(0.48, 0.46)
    d.head((0.64, 0.58, 0.58), at=(0, -0.1, 0.06))
    d.beak(root=(0, 0.36, -0.06), base=0.17, end=0.075, hook=0.14, tip=(0, -0.25, 0.02))
    d.jaw(0.1, 0.05, tip=(0, -0.2, 0))
    d.wings((1.3, 1.25, 0.95), thick=0.1)
    d.tail_fan(0.85)
    d.bird_legs(0.09, (0.15, 0.18, 0.09))
    d.eye(toward=(-0.62, 0.74, 0.2), radius=0.13, offset=(0, -0.1, 0.06))

    # Cream underneath and on its cheeks and throat, with bars across its chest.
    under = facing((0, 0, -1), 0.15)
    d.paint("cream", both(part("torso", "wing", "tail", "leg"), under))
    d.paint("cream", both(part("head"), d.below("skull", (0, 0, 0.02)), d.ahead("skull", (0, -0.3, 0))))
    d.paint("slate", both(part("torso"), facing((0, 0, -1), 0.3), d.bands("spine_mid", (0, 0, 0), (0, 1, 0), 0.4, 0.34)))
    # Its dark cap, the stripe down each cheek, wing tips and the end of its tail.
    d.paint("dark", both(part("head"), d.above("skull", (0, 0, 0.16))))
    d.paint("dark", both(part("head"), d.around("skull", (-0.4, 0.18, -0.12), (0.2, 0.17, 0.4), mirrored=True)))
    d.paint("dark", both(part("wing"), facing((0, 0, 1), -0.2), d.off_middle(1.75)))
    d.paint("dark", both(part("tail"), facing((0, 0, 1), -0.2), d.behind("tail_end", (0, 0.28, 0))))
    d.paint("beak", part("beak", "jaw"))
    d.paint("yellow", both(part("beak"), d.behind("skull", (0, 0.58, 0))))
    d.paint("yellow", part("foot"))
    return d.toy()
