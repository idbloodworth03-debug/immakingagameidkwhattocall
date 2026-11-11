"""Raccoon as a toy: a chubby grey body with its rump up, a wide head with
cheek tufts, a black mask round its eyes over a white face, white ears
with dark insides, dark paws, and its ringed tail carried up behind.
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
    d.put("ear_base", "skull", (-0.36, -0.06, 0.26))
    d.put("ear_tip", "skull", (-0.5, -0.08, 0.52))
    d.torso(rump=(0.5, 0.54, 0.5), chest=(0.45, 0.46, 0.46), rump_at=(0, 0.14, -0.28), chest_at=(0, -0.08, -0.04))
    d.neck(0.36, 0.34)
    d.head((0.52, 0.42, 0.38))
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.3, 0.04, -0.12), k)), d.p("skull", side((-0.64, -0.04, -0.2), k)), 0.2, 0.05,
                                "cheek", "head", blend=0.12))
    d.muzzle(root=(0, 0.22, -0.1), base=0.22, end=0.13, tip=(0, -0.11, 0.1))
    d.nose("snout_tip", (0, 0.01, 0.13), (0.085, 0.06, 0.06))
    d.ears_pointed(width=0.3, thick=0.06, rounding=0.1, turn=0.3)
    d.legs(front=(0.15, 0.14, 0.13), hind=(0.16, 0.145, 0.13), paw=(0.15, 0.19, 0.11))
    d.tail((0.19, 0.28, 0.25, 0.11))
    d.eye(toward=(-0.5, 0.84, 0.08), radius=0.115)

    d.paint("pale", both(part("torso"), facing((0, 0, -1), 0.3)))
    # A white face under the brow, and the mask across it: an oval round each eye, joined over the nose.
    face = part("head", "muzzle", "cheek")
    d.paint("white", both(face, d.ahead("skull", (0, 0.08, 0)), d.below("skull", (0, 0, 0.22))))
    d.paint("mask", both(face, either(d.around("skull", (-0.26, 0.34, 0.02), (0.25, 0.3, 0.15), mirrored=True),
                                      d.around("skull", (0, 0.42, 0.0), (0.2, 0.3, 0.1)))))
    # Rings round its tail, the last one its tip.
    along = d.j("tail_end") - d.j("tail_base")
    d.paint("mask", both(part("tail"), d.bands("tail_tip_end", (0, 0, 0), along, 0.42, 0.5)))
    d.paint("mask", both(part("leg"), d.below("wrist.L", (0, 0, 0.14))))
    d.paint("white", part("ear"))
    d.paint("mask", d.ear_fronts(inset=0.035))
    return d.toy()
