"""Pygmy Three-toed Sloth as a toy: a round shaggy tan body tinted green
along its back, a big round head with a pale face that smiles, a dark
stripe back from each eye, and thick arms spread wide, each ending in
three long pale claws.
"""
from kit import Design, both, but, card_pose, either, facing, part, side

COLORS = {
    "tan": "#c6ab7f",
    "green": "#9dab68",
    "face": "#f4e8cf",
    "stripe": "#4b3929",
    "claw": "#f0e3c8",
    "nose": "#4b3929",
}


def make():
    # (It crawls with its arms and legs spread out to its sides.)
    d = Design("pygmy_three_toed_sloth", COLORS, "tan", straight_legs=False)
    d.torso(rump=(0.62, 0.68, 0.58), chest=(0.6, 0.62, 0.58), rump_at=(0, 0.1, -0.04), chest_at=(0, -0.08, 0.0))
    d.neck(0.46, 0.44)
    d.head((0.66, 0.56, 0.58))
    d.muzzle(root=(0, 0.26, -0.1), base=0.23, end=0.17, tip=(0, 0.26, -0.06))
    d.jaw(0.16, 0.13, tip=(0, 0.26, -0.06))
    d.nose("snout_tip", (0, 0.37, 0.03), (0.1, 0.065, 0.065))

    def limbs(s, k):
        d.limb("fl", s, (0.26, 0.24, 0.21), (0.23, 0.27, 0.13), "arm", "hand")
        d.limb("hl", s, (0.27, 0.24, 0.21), (0.23, 0.25, 0.13), "leg", "foot")
        # Three long claws on each hand, three short ones on each foot.
        for toe, bone, reach in (("front_toe", "fl_foot", 0.5), ("hind_toe", "hl_foot", 0.3)):
            at = d.j(toe + s)
            for i in (-1, 0, 1):
                d.stick(d.p(at, (0.11 * i, 0.14, 0.09)), d.p(at, (0.18 * i - 0.1 * k, 0.14 + reach, 0.03)), 0.065, 0.03,
                        "claw", bone + s, blend=0.03)
    d.pair(limbs)
    d.eye(toward=(-0.42, 0.9, 0.08), radius=0.135)

    d.paint("green", both(part("torso"), facing((0, 0, 1), 0.45)))
    # Its face: a pale disc, a dark stripe back from each eye, and its smile.
    d.paint("face", both(part("head", "muzzle", "jaw"), d.around("skull", (0, 0.44, -0.03), (0.54, 0.36, 0.5))))
    d.paint("stripe", both(part("head"), d.around("skull", (-0.52, 0.32, 0.02), (0.25, 0.3, 0.1), mirrored=True)))
    d.paint("stripe", both(d.mouth_line(0.05), d.ahead("skull", (0, 0.4, 0))))
    d.paint("claw", part("claw"))
    # On its card it reaches out mid-swipe with its smiling face to us (the old pose, a great yawn, turned its face up and away).
    return d.toy(hero=card_pose(0.3, jaw=-0.12, turn=0.3, head=(0.3, 0.2)))
