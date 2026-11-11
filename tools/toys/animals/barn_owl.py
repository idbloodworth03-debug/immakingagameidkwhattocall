"""Barn Owl as a toy: a round golden-tan body with a big round head, a
white heart of a face with two dark button eyes and a small pale beak,
white underneath, and broad stubby wings with darker flight feathers.
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
    d.shorten_wings(0.45)
    d.torso(rump=(0.6, 0.7, 0.54), chest=(0.66, 0.62, 0.6), rump_at=(0, 0.25, 0), chest_at=(0, -0.1, 0), blend=0.2)
    d.neck(0.5, 0.5)
    d.head((0.8, 0.58, 0.72), at=(0, -0.1, 0.12))
    d.beak(root=(0, 0.34, -0.1), base=0.12, end=0.055, hook=0.08, tip=(0, 0.06, 0))
    d.wings((1.5, 1.4, 1.1), thick=0.1)
    d.tail_fan(1.2)
    d.bird_legs(0.1, (0.15, 0.18, 0.09))
    d.eye(toward=(-0.38, 0.92, 0.08), radius=0.17, offset=(0, -0.1, 0.12), pupil=0.86)

    # Its face: a white heart (two ovals, one round each eye).
    d.paint("white", both(part("head"), d.around("skull", (-0.28, 0.34, 0.22), (0.48, 0.38, 0.52), mirrored=True)))
    # Darker flight feathers along the back of its wings and the end of its tail; white underneath.
    d.paint("bar", both(part("wing"), d.behind("spine_mid", (0, 0.12, 0))))
    d.paint("bar", both(part("tail"), d.behind("tail_end", (0, 0.3, 0))))
    d.paint("white", both(part("torso", "wing", "tail", "leg"), facing((0, 0, -1), 0.25)))
    d.paint("beak", part("beak"))
    d.paint("foot", part("foot"))
    return d.toy()
