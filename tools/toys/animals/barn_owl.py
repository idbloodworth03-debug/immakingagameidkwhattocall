"""Barn Owl as a toy: a round golden-buff body with a big round head held
high, a white heart of a face with two dark button eyes and a small pale
beak, white underneath, stubby wings with darker flight feathers, a short
tail and little feet dangling under it.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "tan": "#e8c486",
    "bar": "#b98f5c",
    "white": "#fcf8ef",
    "beak": "#f1d7a0",
    "foot": "#e6bf63",
}


def make():
    # (A bird has no withers to measure by: its sizes are in tenths of a meter.)
    d = Design("barn_owl", COLORS, "tan", unit=0.1)
    d.bird_stance()
    d.shorten_wings(0.3)
    d.put("beak_tip", "skull", (0, 0.92, -0.3))
    d.torso(rump=(0.72, 0.8, 0.7), chest=(0.8, 0.74, 0.78), rump_at=(0, 0.35, 0), chest_at=(0, -0.15, 0.05), blend=0.2)
    d.neck(0.6, 0.6)
    d.head((1.0, 0.78, 0.92))
    d.beak(root=(0, 0.6, -0.18), base=0.15, end=0.07, hook=0.1)
    d.wings((1.1, 1.0, 0.8), thick=0.13)
    d.tail_fan(1.3, root=0.5)
    d.bird_legs(0.13, (0.2, 0.24, 0.12))
    d.eye(toward=(-0.36, 0.92, 0.1), radius=0.24, pupil=0.86)

    # Its face: a white heart (two ovals, one round each eye).
    d.paint("white", both(part("head"), d.around("skull", (-0.34, 0.46, 0.26), (0.62, 0.5, 0.68), mirrored=True)))
    # Darker flight feathers along the back of its wings and the end of its tail; white underneath.
    d.paint("bar", both(part("wing"), d.behind("spine_mid", (0, 0.2, 0))))
    d.paint("bar", both(part("tail"), d.behind("tail_end", (0, 0.3, 0))))
    d.paint("white", both(part("torso", "wing", "tail", "leg"), facing((0, 0.2, -1), 0.3)))
    d.paint("beak", part("beak"))
    d.paint("foot", part("foot"))
    return d.toy()
