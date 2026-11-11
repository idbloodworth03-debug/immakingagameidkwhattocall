"""Sumatran Orangutan as a toy: a round orange belly standing upright on
short thick legs, long arms hanging to big grey hands, a big head with
wide grey cheek pads round a pale muzzle, a tuft of hair on top and an
orange beard.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "fur": "#dc6a2a",
    "skin": "#7d6862",
    "muzzle": "#cdaa94",
    "mouth": "#4b3030",
    "nose": "#3d2d2d",
}


def make():
    # (It stands upright: its arms hang as its skeleton has them.)
    d = Design("sumatran_orangutan", COLORS, "fur", straight_legs=False)
    # Its arms hang clear of its round body.
    d.move(["shoulder", "elbow", "wrist", "front_toe"], (-0.13, 0, 0))
    d.blob(d.p("pelvis", (0, 0.02, 0.14)), (0.44, 0.4, 0.42), "torso", "hips", blend=0.0)
    d.blob(d.p("withers", (0, 0, -0.1)), (0.4, 0.35, 0.36), "torso", "chest", blend=0.25)
    d.neck(0.28, 0.26)
    d.head((0.44, 0.4, 0.42))
    # Cheek pads: a wide flat disc each side of its face.
    d.pair(lambda s, k: d.blob(d.p("skull", side((-0.4, 0.1, -0.06), k)), (0.2, 0.12, 0.34), "pad", "head", blend=0.05))
    d.blob(d.p("skull", (0, -0.04, 0.42)), (0.2, 0.2, 0.16), "hair", "head", blend=0.06)
    d.muzzle(root=(0, 0.14, -0.16), base=0.26, end=0.22, tip=(0, 0.3, -0.08))
    d.jaw(0.2, 0.18, tip=(0, 0.3, -0.06))
    d.blob(d.p("chin", (0, 0.22, -0.16)), (0.2, 0.15, 0.17), "beard", "jaw", blend=0.05)
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.05, 0.5, 0.02), k), (0.028, 0.022, 0.035)))

    def limbs(s, k):
        d.limb("fl", s, (0.18, 0.17, 0.16), (0.18, 0.18, 0.16), "arm", "hand", on_ground=False)
        d.limb("hl", s, (0.2, 0.18, 0.17), (0.19, 0.26, 0.11), "leg", "foot")
    d.pair(limbs)
    d.eye(toward=(-0.3, 0.94, 0.14), radius=0.1)

    d.paint("skin", part("pad", "hand", "foot"))
    d.paint("skin", both(part("head", "muzzle", "jaw"), d.around("skull", (0, 0.36, -0.04), (0.34, 0.26, 0.34))))
    d.paint("muzzle", both(part("muzzle", "jaw"), d.ahead("snout_tip", (0, 0.08, 0))))
    d.paint("mouth", both(d.mouth_line(0.06), d.ahead("skull", (0, 0.2, 0))))
    return d.toy()
