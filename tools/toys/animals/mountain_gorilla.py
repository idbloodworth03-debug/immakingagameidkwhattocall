"""Mountain Gorilla as a toy: a silverback standing tall. A huge black
chest and shoulders over a round belly, thick arms to big grey hands,
short thick legs, a big head with a grey face under a heavy brow and a
high crest behind it, and a silver saddle across his back.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "fur": "#302e38",
    "silver": "#aeb2bb",
    "face": "#655b60",
    "chest": "#4b464f",
    "mouth": "#3b2a2f",
    "nose": "#2b2227",
}


def make():
    # (He stands upright: his arms hang as his skeleton has them.)
    d = Design("mountain_gorilla", COLORS, "fur", straight_legs=False)
    # His arms hang clear of his body.
    d.move(["shoulder", "elbow", "wrist", "front_toe"], (-0.14, 0, 0))
    d.blob(d.p("pelvis", (0, 0.02, 0.14)), (0.42, 0.38, 0.4), "torso", "hips", blend=0.0)
    d.blob(d.p("withers", (0, 0, -0.08)), (0.5, 0.38, 0.4), "torso", "chest", blend=0.25)
    d.neck(0.3, 0.28)
    d.head((0.44, 0.42, 0.42))
    # The crest on his head, and his heavy brow.
    d.blob(d.p("skull", (0, -0.08, 0.36)), (0.26, 0.3, 0.24), "crest", "head", blend=0.1)
    d.blob(d.p("skull", (0, 0.36, 0.1)), (0.36, 0.1, 0.085), "brow", "head", blend=0.04)
    d.muzzle(root=(0, 0.14, -0.18), base=0.27, end=0.23, tip=(0, 0.34, -0.08))
    d.jaw(0.21, 0.19, tip=(0, 0.34, -0.06))
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.07, 0.56, 0.02), k), (0.04, 0.028, 0.04)))

    def limbs(s, k):
        d.limb("fl", s, (0.21, 0.2, 0.19), (0.21, 0.21, 0.18), "arm", "hand", on_ground=False)
        d.limb("hl", s, (0.21, 0.19, 0.18), (0.2, 0.27, 0.12), "leg", "foot")
    d.pair(limbs)
    d.eye(toward=(-0.3, 0.94, 0.06), radius=0.095)

    d.paint("face", part("hand", "foot", "brow"))
    d.paint("face", both(part("head", "muzzle", "jaw"), d.around("skull", (0, 0.4, -0.08), (0.34, 0.26, 0.36))))
    d.paint("mouth", both(d.mouth_line(0.05), d.ahead("skull", (0, 0.2, 0))))
    # His bare chest, and the silver saddle across his back.
    d.paint("chest", both(part("torso"), facing((0, 1, 0), 0.55), d.above("spine_mid", (0, 0, 0.02)), d.below("withers", (0, 0, 0.14))))
    d.paint("silver", both(part("torso"), facing((0, -1, 0), 0.25), d.above("pelvis", (0, 0, 0.1)), d.below("withers", (0, 0, 0.22))))
    return d.toy()
