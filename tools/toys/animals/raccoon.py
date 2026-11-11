"""Raccoon as a toy: a chubby grey body with its rump up on four thick
dark-pawed legs, a big wide head with cheek tufts, a black mask round its
eyes over a white face, white ears with dark insides, and its ringed tail
carried up behind.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "grey": "#918e96",
    "pale": "#d3cfcc",
    "white": "#f9f5eb",
    "mask": "#302c33",
}


def make():
    d = Design("raccoon", COLORS, "grey", changes={
        # Its ringed tail is carried up behind it (the part of a raccoon you see from behind).
        "tail_base": (0, -0.15, 0.25), "tail_mid": (0, -0.2, 0.345), "tail_end": (0, -0.215, 0.46),
        "tail_tip_end": (0, -0.212, 0.515),
    })
    d.put("ear_base", "skull", (-0.42, -0.06, 0.34))
    d.put("ear_tip", "skull", (-0.6, -0.08, 0.68))
    d.torso(rump=(0.46, 0.5, 0.46), chest=(0.43, 0.45, 0.44), rump_at=(0, 0.14, -0.26), chest_at=(0, -0.06, -0.02))
    d.neck(0.38, 0.36)
    d.head((0.62, 0.48, 0.5))
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.36, 0.04, -0.14), k)), d.p("skull", side((-0.76, -0.04, -0.24), k)), 0.23, 0.05,
                                "cheek", "head", blend=0.12))
    d.muzzle(root=(0, 0.26, -0.14), base=0.25, end=0.15, tip=(0, -0.02, 0.06))
    d.nose("snout_tip", (0, 0.1, 0.1), (0.095, 0.065, 0.065))
    d.ears_pointed(width=0.36, thick=0.06, rounding=0.11, turn=0.3)
    d.legs(front=(0.18, 0.17, 0.16), hind=(0.19, 0.175, 0.16), paw=(0.17, 0.21, 0.12))
    d.tail((0.2, 0.3, 0.27, 0.12))
    d.eye(toward=(-0.5, 0.84, 0.06), radius=0.15)

    d.paint("pale", both(part("torso"), facing((0, 0, -1), 0.3)))
    # A white face under the brow, and the mask across it: an oval round each eye, joined over the nose.
    face = part("head", "muzzle", "cheek")
    d.paint("white", both(face, d.ahead("skull", (0, 0.1, 0)), d.below("skull", (0, 0, 0.3))))
    d.paint("mask", both(face, either(d.around("skull", (-0.31, 0.38, 0.03), (0.31, 0.34, 0.2), mirrored=True),
                                      d.around("skull", (0, 0.46, 0.0), (0.24, 0.3, 0.13)))))
    # Rings round its tail, the last one its tip.
    along = d.j("tail_end") - d.j("tail_base")
    d.paint("mask", both(part("tail"), d.bands("tail_tip_end", (0, 0, 0), along, 0.42, 0.5)))
    d.paint("mask", both(part("leg"), d.below("wrist.L", (0, 0, 0.16))))
    d.paint("white", part("ear"))
    d.paint("mask", d.ear_fronts(inset=0.04))
    return d.toy()
