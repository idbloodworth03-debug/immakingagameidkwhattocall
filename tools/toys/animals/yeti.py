"""Yeti as a toy: a big white pear of a body standing upright, long arms
ending in big pale-blue hands, short legs on big blue feet, a round head
with a blue face, a wide friendly mouth, two little horns and tufts of fur
at its cheeks and crown.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "fur": "#f5f8fc",
    "blue": "#8ec1ea",
    "horn": "#a9bdd6",
    "mouth": "#3f6ea3",
    "nose": "#3a5f8a",
}


def make():
    # (It stands upright: its arms hang as its skeleton has them.)
    d = Design("yeti", COLORS, "fur", straight_legs=False)
    # Its arms hang clear of its round body.
    d.move(["shoulder", "elbow", "wrist", "front_toe"], (-0.24, 0, 0))
    d.blob(d.p("pelvis", (0, 0, 0.14)), (0.5, 0.46, 0.5), "torso", "hips", blend=0.0)
    d.blob(d.p("withers", (0, 0, -0.06)), (0.46, 0.42, 0.44), "torso", "chest", blend=0.25)
    d.neck(0.36, 0.34)
    d.head((0.48, 0.44, 0.44))
    # Tufts: its cheeks and the crown of its head.
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.3, 0.0, -0.16), k)), d.p("skull", side((-0.62, -0.04, -0.34), k)), 0.2, 0.05,
                                "tuft", "head", blend=0.12))
    d.stick(d.p("skull", (0, 0.02, 0.36)), d.p("skull", (0, -0.06, 0.6)), 0.12, 0.03, "tuft", "head", blend=0.08)
    d.muzzle(root=(0, 0.24, -0.14), base=0.27, end=0.22, tip=(0, 0.12, 0.02))
    d.jaw(0.23, 0.2, tip=(0, 0.12, -0.02))
    d.nose("snout_tip", (0, 0.3, 0.1), (0.085, 0.055, 0.06))
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.3, 0.02, 0.3), k)), d.p("skull", side((-0.52, -0.02, 0.6), k)), 0.1, 0.03,
                                "horn", "head", blend=0.03))
    # Arms and legs, along their joints: big hands and feet.
    def limbs(s, k):
        d.limb("fl", s, (0.2, 0.19, 0.18), (0.21, 0.21, 0.19), "arm", "hand", on_ground=False)
        d.limb("hl", s, (0.23, 0.21, 0.2), (0.21, 0.29, 0.12), "leg", "foot")
    d.pair(limbs)
    d.eye(toward=(-0.4, 0.9, 0.12), radius=0.125)

    d.paint("blue", part("hand", "foot"))
    d.paint("blue", both(part("head", "muzzle", "jaw"), d.around("skull", (0, 0.42, -0.04), (0.36, 0.3, 0.34))))
    d.paint("mouth", both(d.mouth_line(0.12), d.ahead("skull", (0, 0.2, 0))))
    d.paint("horn", part("horn"))
    return d.toy()
