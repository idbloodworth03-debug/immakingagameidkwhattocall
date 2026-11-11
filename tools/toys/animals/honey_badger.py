"""Honey Badger as a toy: a low black bean on stubby legs with a flat wide
head, and its mark: a broad grey mantle from its brow over its back to its
tail, edged in white. Small round ears and pale claws.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "black": "#2c2932",
    "mantle": "#9a978f",
    "white": "#fbfaf4",
    "claw": "#e9e2d0",
}


def make():
    d = Design("honey_badger", COLORS, "black", changes={
        "tail_base": (0, -0.16, 0.2), "tail_mid": (0, -0.21, 0.22), "tail_end": (0, -0.25, 0.235), "tail_tip_end": (0, -0.265, 0.24),
    })
    d.put("ear_base", "skull", (-0.38, -0.08, 0.16))
    d.put("ear_tip", "skull", (-0.47, -0.08, 0.26))
    d.torso(rump=(0.44, 0.5, 0.42), chest=(0.44, 0.45, 0.42), rump_at=(0, 0.1, -0.08), chest_at=(0, -0.05, -0.02))
    d.neck(0.36, 0.34)
    d.head((0.52, 0.42, 0.34))
    d.muzzle(root=(0, 0.22, -0.08), base=0.26, end=0.17, tip=(0, -0.1, 0.13))
    d.nose("snout_tip", (0, -0.04, 0.17), (0.1, 0.07, 0.07))
    d.ears_round((0.11, 0.06, 0.11))
    d.legs(front=(0.17, 0.16, 0.15), hind=(0.18, 0.165, 0.15), paw=(0.16, 0.2, 0.12))
    d.tail((0.16, 0.14, 0.1, 0.05))
    d.eye(toward=(-0.5, 0.84, 0.08), radius=0.125)

    # The mantle: its top, from the brow to the tail, with a white edge.
    top = but(part("head", "torso", "tail"), part("ear"))
    d.paint("white", both(top, facing((0, 0, 1), 0.2), d.behind("skull", (0, 0.3, 0))))
    d.paint("mantle", both(top, facing((0, 0, 1), 0.36), d.behind("skull", (0, 0.24, 0))))
    d.paint("claw", both(part("leg"), either(d.around("front_toe.L", (0, 0.08, 0), (0.17, 0.14, 0.09), mirrored=True),
                                             d.around("hind_toe.L", (0, 0.08, 0), (0.17, 0.14, 0.09), mirrored=True))))
    return d.toy()
