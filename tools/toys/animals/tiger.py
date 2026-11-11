"""Tiger as a toy: an orange body on big paws with black stripes across its
back, legs and tail, a white belly, chest, cheeks and muzzle, round ears
(black behind, with a white spot), and a pink nose.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "orange": "#f08a24",
    "white": "#fff6e8",
    "black": "#2b2327",
    "pink": "#f29a9a",
    "inner": "#ffd9b8",
}


def make():
    d = Design("tiger", COLORS, "orange", changes={
        "tail_mid": (0, -0.62, 0.46), "tail_end": (0, -0.78, 0.42), "tail_tip_end": (0, -0.84, 0.47),
    })
    d.put("ear_base", "skull", (-0.3, -0.02, 0.3))
    d.put("ear_tip", "skull", (-0.38, -0.02, 0.46))
    d.torso(rump=(0.3, 0.4, 0.3), chest=(0.33, 0.36, 0.35), rump_at=(0, 0.08, -0.12), chest_at=(0, -0.03, -0.1))
    d.neck(0.3, 0.28)
    d.head((0.43, 0.39, 0.36))
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.24, 0.04, -0.12), k)), d.p("skull", side((-0.5, -0.04, -0.2), k)), 0.2, 0.07,
                                "cheek", "head", blend=0.12))
    d.muzzle(root=(0, 0.2, -0.1), base=0.23, end=0.16)
    d.nose("snout_tip", (0, 0.07, 0.05), (0.11, 0.07, 0.075), color="pink")
    d.ears_round((0.15, 0.07, 0.15))
    d.legs(front=(0.15, 0.135, 0.125), hind=(0.16, 0.14, 0.125), paw=(0.15, 0.19, 0.11))
    d.tail((0.1, 0.09, 0.085, 0.07))
    d.eye(toward=(-0.55, 0.8, 0.14), radius=0.12)

    d.paint("white", both(part("torso"), facing((0, 0, -1), 0.3)))
    d.paint("white", both(d.around("withers", (0, 0.2, -0.3), (0.25, 0.4, 0.4)), part("torso")))
    d.paint("white", either(part("cheek"), both(part("muzzle", "head"), d.below("snout_tip", (0, 0, 0.1)), d.ahead("skull", (0, 0.1, 0)))))
    # Stripes: across the back and flanks, round the legs and the tail, and
    # three on the brow.
    d.paint("black", both(part("torso"), facing((0, 0, 1), -0.25), d.bands("spine_mid", (0, 0, 0), (0, 1, 0.25), 0.3, 0.36)))
    d.paint("black", both(part("leg"), d.above("wrist.L", (0, 0, 0.05)), d.bands("wrist.L", (0, 0, 0), (0, 0.2, 1), 0.2, 0.4)))
    along = d.j("tail_end") - d.j("tail_base")
    d.paint("black", both(part("tail"), d.bands("tail_base", (0, 0, 0), along, 0.24, 0.45)))
    d.paint("black", both(part("head"), facing((0, 0, 1), 0.55), d.near_middle(0.2), d.bands("skull", (0, 0.03, 0), (0, 1, 0), 0.15, 0.4)))
    d.paint("black", both(part("ear"), facing((0, -1, 0), 0.1)))
    d.paint("white", both(part("ear"), facing((0, -1, 0), 0.75)))
    d.paint("inner", both(part("ear"), facing((0, 1, 0), 0.5)))
    return d.toy()
