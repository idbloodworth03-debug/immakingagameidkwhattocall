"""Komodo Dragon as a toy: a long, low, grey-brown lizard on short sprawled
legs, a flat wide head, a heavy tail, darker bands down its back and tail,
a sandy belly, and its forked yellow tongue flicking out.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "hide": "#8b8667",
    "band": "#5f5b46",
    "belly": "#dccba2",
    "tongue": "#f4d43a",
    "claw": "#3a372e",
}


def make():
    # (Its legs stay sprawled out to its sides, as a lizard's are.)
    d = Design("komodo_dragon", COLORS, "hide", straight_legs=False, unit=0.3)
    d.torso(rump=(0.52, 0.85, 0.42), chest=(0.55, 0.75, 0.44), rump_at=(0, 0.2, -0.1), chest_at=(0, -0.1, -0.1))
    d.neck(0.42, 0.36)
    d.head((0.5, 0.55, 0.36))
    d.muzzle(root=(0, 0.3, -0.08), base=0.33, end=0.22)
    # The tongue: a thin stalk and a fork.
    d.stick(d.p("snout_tip", (0, 0.0, -0.06)), d.p("snout_tip", (0, 0.42, -0.1)), 0.04, 0.035, "tongue", "head", blend=0.02)
    d.pair(lambda s, k: d.stick(d.p("snout_tip", (0, 0.42, -0.1)), d.p("snout_tip", side((-0.12, 0.62, -0.1), k)), 0.035, 0.015,
                                "tongue", "head", blend=0.02))
    d.legs(front=(0.2, 0.17, 0.14), hind=(0.22, 0.18, 0.14), paw=(0.17, 0.22, 0.1))
    d.tail((0.4, 0.3, 0.16, 0.05))
    d.eye(toward=(-0.74, 0.5, 0.44), radius=0.135)

    body = part("torso", "head", "muzzle", "tail")
    d.paint("band", both(part("torso", "tail"), facing((0, 0, 1), 0.1), d.bands("spine_mid", (0, 0, 0), (0, 1, 0), 0.62, 0.32)))
    d.paint("belly", both(body, facing((0, 0, -1), 0.35)))
    d.paint("tongue", part("tongue"))
    d.paint("claw", both(part("leg"), either(d.around("front_toe.L", (0, 0.1, 0), (0.2, 0.16, 0.09), mirrored=True),
                                             d.around("hind_toe.L", (0, 0.1, 0), (0.2, 0.16, 0.09), mirrored=True))))
    return d.toy()
