"""King Cobra as a toy: a fat olive rope of a body lying in bends on the
ground, rearing up to a wide flat hood with a pale throat, a big blunt
head with big eyes, dark bands across its back, a pale belly, and a
forked red tongue.
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
    # (No withers to measure by: its sizes are in tenths of a meter. A toy snake is short and fat: its bends lie closer
    # together and its raised neck is shorter than the old model's.)
    d = Design("king_cobra", COLORS, "olive", unit=0.1, changes={
        "tail_end": (0.075, -0.2, 0.018), "tail_mid": (-0.09, -0.155, 0.036), "tail_base": (0.065, -0.095, 0.05),
        "pelvis": (-0.05, -0.025, 0.06), "spine_mid": (0.03, 0.055, 0.062), "withers": (0.0, 0.115, 0.125),
        "neck_base": (0, 0.145, 0.27), "head_base": (0, 0.16, 0.35), "skull": (0, 0.23, 0.4), "snout_tip": (0, 0.32, 0.375),
        "jaw_hinge": (0, 0.237, 0.352), "chin": (0, 0.308, 0.34),
    })
    # Its body: one rope from the tip of its tail, curving through its bends on the ground and up into the raised neck.
    d.rope(("tail_end", "tail_mid", "tail_base", "pelvis", "spine_mid", "withers", "neck_base", "head_base"),
           (0.14, 0.36, 0.5, 0.6, 0.62, 0.6, 0.52, 0.48), ("tail3", "tail2", "tail1", "hips", "chest", "neck", "neck2", "head"),
           ["body"] * 5 + ["neck"] * 2)
    # The hood: wide and flat, facing forward.
    d.blob(d.p("neck_base", (0, 0.05, 0.45)), (1.35, 0.3, 1.05), "hood", "neck2", blend=0.2)
    d.head((0.85, 0.95, 0.62), at=(0, 0.05, 0))
    d.muzzle(root=(0, 0.5, -0.08), base=0.6, end=0.42)
    d.jaw(0.42, 0.34)
    # The tongue: a stalk and a fork.
    d.stick(d.p("snout_tip", (0, 0.2, -0.26)), d.p("snout_tip", (0, 0.95, -0.36)), 0.09, 0.08, "tongue", "head", blend=0.03)
    d.pair(lambda s, k: d.stick(d.p("snout_tip", (0, 0.95, -0.36)), d.p("snout_tip", side((-0.28, 1.4, -0.36), k)), 0.08, 0.035,
                                "tongue", "head", blend=0.03))
    d.eye(toward=(-0.62, 0.62, 0.48), radius=0.27, offset=(0, 0.05, 0))

    # Dark bands across its back; a pale belly, throat and chin.
    d.paint("band", both(part("body"), facing((0, 0, 1), 0.0), d.bands("pelvis", (0, 0.2, 0), (0, 1, 0), 1.0, 0.36)))
    d.paint("band", both(part("neck", "hood"), facing((0, -1, 0), 0.0), d.bands("withers", (0, 0, 0.3), (0, 0, 1), 0.9, 0.36)))
    d.paint("belly", both(part("body"), facing((0, 0, -1), 0.3)))
    d.paint("belly", both(part("neck", "hood"), facing((0, 1, 0), 0.3), d.near_middle(0.6)))
    d.paint("belly", both(part("jaw", "muzzle", "head"), d.below("chin", (0, 0, 0.1))))
    d.paint("mouth", both(d.mouth_line(0.1), d.ahead("skull", (0, 0.4, 0))))
    d.paint("tongue", part("tongue"))
    # On its card it rears up facing us, hood spread, its head tipped down so both eyes show (the old pose showed its chin).
    return d.toy(hero=card_pose(0.0, jaw=-0.45, turn=0.3, head=(-0.5, 0.3), clip="idle"))
