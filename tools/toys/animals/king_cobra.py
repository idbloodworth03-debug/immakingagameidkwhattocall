"""King Cobra as a toy: an olive rope of a body lying in bends on the
ground, rearing up to a wide flat hood with a pale throat, a blunt head
with big eyes, dark bands across its back, a pale belly, and a forked red
tongue.
"""
from kit import Design, both, but, card_pose, either, facing, part, side

COLORS = {
    "olive": "#93a13f",
    "band": "#5f6f2b",
    "belly": "#f4e195",
    "tongue": "#e8475c",
    "mouth": "#7a2f3a",
}


def make():
    # (No withers to measure by: its sizes are in tenths of a meter.)
    d = Design("king_cobra", COLORS, "olive", unit=0.1)
    # Its body, from the tip of its tail along the bends on the ground and up into the raised neck.
    d.stick("tail_end", "tail_mid", 0.12, 0.3, "body", "tail3", blend=0.1)
    d.stick("tail_mid", "tail_base", 0.3, 0.4, "body", "tail3", "tail2", blend=0.1)
    d.stick("tail_base", "pelvis", 0.4, 0.46, "body", "tail2", "tail1", blend=0.1)
    d.stick("pelvis", "spine_mid", 0.46, 0.48, "body", "hips", "chest", blend=0.1)
    d.stick("spine_mid", "withers", 0.48, 0.46, "body", "chest", "neck", blend=0.1)
    d.stick("withers", "neck_base", 0.46, 0.4, "neck", "neck", "neck2", blend=0.1)
    d.stick("neck_base", "head_base", 0.4, 0.36, "neck", "neck2", "head", blend=0.1)
    # The hood: wide and flat, facing forward.
    d.blob(d.p("neck_base", (0, 0.06, 0.5)), (1.15, 0.26, 1.0), "hood", "neck2", blend=0.2)
    d.head((0.62, 0.74, 0.44), at=(0, 0.1, 0))
    d.muzzle(root=(0, 0.4, -0.06), base=0.46, end=0.3)
    d.jaw(0.3, 0.24)
    # The tongue: a thin stalk and a fork.
    d.stick(d.p("snout_tip", (0, 0.1, -0.2)), d.p("snout_tip", (0, 0.75, -0.3)), 0.07, 0.06, "tongue", "head", blend=0.03)
    d.pair(lambda s, k: d.stick(d.p("snout_tip", (0, 0.75, -0.3)), d.p("snout_tip", side((-0.22, 1.1, -0.3), k)), 0.06, 0.025,
                                "tongue", "head", blend=0.03))
    d.eye(toward=(-0.7, 0.56, 0.44), radius=0.2)

    # Dark bands across its back; a pale belly, throat and hood front.
    d.paint("band", both(part("body"), facing((0, 0, 1), 0.0), d.bands("pelvis", (0, 0.2, 0), (0, 1, 0), 0.9, 0.36)))
    d.paint("band", both(part("neck", "hood"), facing((0, -1, 0), 0.0), d.bands("withers", (0, 0, 0.3), (0, 0, 1), 0.9, 0.36)))
    d.paint("belly", both(part("body"), facing((0, 0, -1), 0.3)))
    d.paint("belly", both(part("neck", "hood"), facing((0, 1, 0), 0.3), d.near_middle(0.5)))
    d.paint("belly", both(part("jaw", "muzzle", "head"), d.below("chin", (0, 0, 0.08))))
    d.paint("mouth", both(d.mouth_line(0.1), d.ahead("skull", (0, 0.3, 0))))
    d.paint("tongue", part("tongue"))
    # On its card it rears up facing us, hood spread, its head tipped down so both eyes show (the old pose showed its chin).
    return d.toy(hero=card_pose(0.0, jaw=-0.45, turn=0.3, head=(-0.5, 0.3), clip="idle"))
