"""Harbor Seal as a toy: a plump silver-grey teardrop lying on its belly,
dark spots over its back, a pale belly, a big round head held up with big
dark eyes and a pale whiskery muzzle, short front flippers and two back
flippers trailing behind like a fishtail.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "grey": "#9ca8b4",
    "dark": "#5d6874",
    "pale": "#eff1ef",
    "mouth": "#6b4b54",
}

# Where its spots are: from the middle of its back, in its own units (across, along, up).
SPOTS = [(0.36, 0.55, 0.6), (-0.42, 0.15, 0.62), (0.22, -0.5, 0.58), (-0.3, -0.95, 0.5), (0.46, -1.15, 0.36), (-0.58, 0.9, 0.5),
         (0.05, 1.2, 0.8), (0.62, -0.1, 0.4), (-0.1, -1.6, 0.4)]


def make():
    # (It lies on its belly: its sizes are in units of 20 cm, and its flippers stay where its skeleton has them.)
    d = Design("harbor_seal", COLORS, "grey", straight_legs=False, unit=0.2)
    d.blob(d.p("pelvis", (0, 0.05, 0)), (0.62, 0.9, 0.56), "torso", "hips", blend=0.0)
    d.blob("spine_mid", (0.8, 1.0, 0.76), "torso", "hips", blend=0.3)
    d.blob("withers", (0.82, 0.9, 0.82), "torso", "chest", blend=0.3)
    d.stick("pelvis", "tail_base", 0.5, 0.3, "torso", "hips", "tail1", blend=0.2)
    d.tail((0.28, 0.2, 0.14, 0.08))
    d.neck(0.66, 0.58)
    d.head((0.88, 0.82, 0.8))
    d.muzzle(root=(0, 0.36, -0.18), base=0.44, end=0.32, tip=(0, 0.2, -0.06))
    # Whisker pads either side of its nose.
    d.pair(lambda s, k: d.blob(d.p("snout_tip", side((-0.22, 0.2, -0.1), k)), (0.24, 0.22, 0.18), "muzzle", "head", blend=0.08))
    d.jaw(0.3, 0.24, tip=(0, 0.2, -0.06))
    d.nose("snout_tip", (0, 0.46, 0.1), (0.14, 0.09, 0.1))

    def flippers(s, k):
        d.limb("fl", s, (0.3, 0.26, 0.22), (0.34, 0.46, 0.1), "flipper")
        d.limb("hl", s, (0.34, 0.26, 0.2), (0.3, 0.5, 0.1), "flipper", on_ground=False)
    d.pair(flippers)
    d.eye(toward=(-0.5, 0.84, 0.16), radius=0.23, pupil=0.8)

    d.paint("dark", both(part("torso"), facing((0, 0, 1), -0.1),
                         either(*[d.around("spine_mid", at, (0.2, 0.23, 0.4)) for at in SPOTS])))
    d.paint("pale", both(part("torso", "head", "jaw"), facing((0, 0.5, -0.85), 0.35)))
    d.paint("pale", part("muzzle"))
    d.paint("dark", part("flipper"))
    d.paint("mouth", both(d.mouth_line(0.07), d.ahead("skull", (0, 0.4, 0))))
    return d.toy()
