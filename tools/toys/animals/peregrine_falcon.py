"""Peregrine Falcon as a toy: a round slate-blue body with a big head held
high, a dark cap and a dark stripe down each cream cheek, a cream chest
with slate bars, a short hooked beak with a yellow base, stubby pointed
wings with dark tips, and yellow feet dangling under it.
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
    d.bird_stance()
    d.shorten_wings(0.62)
    d.put("beak_tip", "skull", (0, 1.02, -0.26))
    d.put("jaw_hinge", "skull", (0, 0.6, -0.36))
    d.put("chin", "skull", (0, 0.92, -0.42))
    d.torso(rump=(0.7, 0.8, 0.68), chest=(0.78, 0.72, 0.76), rump_at=(0, 0.35, 0), chest_at=(0, -0.15, 0.05), blend=0.2)
    d.neck(0.58, 0.58)
    d.head((0.94, 0.78, 0.88))
    d.beak(root=(0, 0.56, -0.2), base=0.22, end=0.1, hook=0.18)
    d.jaw(0.12, 0.06)
    d.wings((1.15, 1.05, 0.8), thick=0.13)
    d.tail_fan(1.1, root=0.5)
    d.bird_legs(0.13, (0.2, 0.24, 0.12))
    d.eye(toward=(-0.5, 0.84, 0.14), radius=0.21)

    # Cream underneath and on its cheeks and throat, with bars across its chest.
    d.paint("cream", both(part("torso", "wing", "tail", "leg"), facing((0, 0.2, -1), 0.25)))
    d.paint("cream", both(part("head"), d.below("skull", (0, 0, 0.0)), d.ahead("skull", (0, -0.2, 0))))
    d.paint("slate", both(part("torso"), facing((0, 0.2, -1), 0.4), d.bands("spine_mid", (0, 0, 0), (0, 1, 0), 0.46, 0.34)))
    # Its dark cap, the stripe down each cheek, wing tips and the end of its tail.
    d.paint("dark", both(part("head"), d.above("skull", (0, 0, 0.3))))
    d.paint("dark", both(part("head"), d.around("skull", (-0.62, 0.3, -0.2), (0.3, 0.26, 0.56), mirrored=True)))
    d.paint("dark", both(part("wing"), facing((0, 0, 1), -0.2), d.off_middle(1.45)))
    d.paint("dark", both(part("tail"), facing((0, 0, 1), -0.2), d.behind("tail_end", (0, 0.3, 0))))
    d.paint("beak", part("beak", "jaw"))
    d.paint("yellow", both(part("beak"), d.behind("skull", (0, 0.86, 0))))
    d.paint("yellow", part("foot"))
    return d.toy()
