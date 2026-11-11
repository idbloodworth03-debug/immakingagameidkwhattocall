"""Hippopotamus as a toy: a great grey-purple barrel on short thick legs, a
huge square muzzle with pink lips and nostrils on top, a jaw that drops
wide open on two pegs of teeth, small round ears, and eyes up on top of its
head.
"""
from kit import Design, both, but, card_pose, either, facing, part, side

COLORS = {
    "hide": "#8f8099",
    "pink": "#e9a9b3",
    "mouth": "#c9506a",
    "tooth": "#fff8e6",
    "inner": "#e9a9b3",
    "toe": "#6f6278",
}


def make():
    d = Design("hippopotamus", COLORS, "hide", changes={
        # A shorter, squarer head than the old model's, with the lower jaw
        # right under the muzzle.
        "snout_tip": (0, 1.36, 1.06), "chin": (0, 1.3, 0.86), "jaw_hinge": (0, 0.9, 0.98),
    })
    d.put("ear_base", "skull", (-0.3, -0.1, 0.3))
    d.put("ear_tip", "skull", (-0.38, -0.1, 0.42))
    d.torso(rump=(0.5, 0.56, 0.47), chest=(0.52, 0.52, 0.5), rump_at=(0, 0.1, -0.1), chest_at=(0, -0.05, -0.1))
    d.neck(0.44, 0.42)
    d.head((0.42, 0.4, 0.36))
    d.muzzle(root=(0, 0.16, -0.1), base=0.36, end=0.37, blend=0.16)
    d.jaw(0.3, 0.33)
    # Its two pegs of teeth, on the jaw: they show when it yawns.
    d.pair(lambda s, k: d.stick(d.p("chin", side((-0.17, -0.02, 0.2), k)), d.p("chin", side((-0.17, -0.02, 0.42), k)), 0.06, 0.04,
                                "tooth", "jaw", blend=0.02))
    # Nostrils and the bumps its eyes sit on.
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.14, -0.04, 0.33), k), (0.05, 0.06, 0.03)))
    d.pair(lambda s, k: d.blob(d.p("skull", side((-0.24, 0.14, 0.3), k)), (0.13, 0.13, 0.12), "head", "head", blend=0.08))
    d.ears_round((0.1, 0.06, 0.11))
    d.legs(front=(0.23, 0.21, 0.2), hind=(0.24, 0.215, 0.2), paw=(0.22, 0.24, 0.13))
    d.tail((0.07, 0.06, 0.05, 0.04))
    d.eye(toward=(-0.5, 0.5, 0.7), radius=0.085, origin="skull", offset=(0, 0.1, 0.1))

    d.paint("pink", both(part("torso"), facing((0, 0, -1), 0.45)))
    d.paint("pink", both(part("muzzle", "jaw"), d.ahead("snout_tip", (0, -0.22, 0))))
    d.paint("mouth", both(d.mouth_line(0.12), d.ahead("jaw_hinge", (0, 0.1, 0))))
    d.paint("tooth", part("tooth"))
    d.paint("inner", both(part("ear"), facing((0, 1, 0), 0.55)))
    d.paint("toe", both(part("leg"), d.below("front_toe.L", (0, 0, 0.1))))
    # On its card it grins at us (the old pose, gaping as wide as it could, hid its face behind its snout).
    return d.toy(hero=card_pose(0.3, jaw=-0.45, turn=0.3, head=(0.1, 0.2)))
