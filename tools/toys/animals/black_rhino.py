"""Black Rhino as a toy: a heavy grey body with plates of hide marked by
dark folds, short pillar legs, a long low head with two cream horns, tubes
of ears with pink insides, and a thin tail with a dark tuft.
"""
from kit import Design, both, but, card_pose, either, facing, part, side

COLORS = {
    "grey": "#8e939b",
    "fold": "#646971",
    "horn": "#f2e8cf",
    "inner": "#e3aaa6",
    "toe": "#5a5e66",
}


def make():
    d = Design("black_rhino", COLORS, "grey", changes={
        # A shorter head than the old model's, held a little higher.
        "snout_tip": (0, 1.36, 0.74), "chin": (0, 1.24, 0.62),
        "ear_base": (-0.3, 0.88, 1.44), "ear_tip": (-0.42, 0.84, 1.74),
    })
    d.torso(rump=(0.44, 0.52, 0.43), chest=(0.46, 0.48, 0.47), rump_at=(0, 0.08, -0.1), chest_at=(0, -0.03, -0.1))
    d.neck(0.4, 0.37)
    d.head((0.36, 0.4, 0.34))
    d.muzzle(root=(0, 0.16, -0.12), base=0.3, end=0.27, blend=0.14)
    # Two horns: a big one on the nose, a small one behind it.
    d.stick(d.p("snout_tip", (0, -0.08, 0.14)), d.p("snout_tip", (0, 0.1, 0.78)), 0.17, 0.03, "horn", "head", blend=0.03)
    d.stick(d.p("snout_tip", (0, -0.2, 0.46)), d.p("snout_tip", (0, -0.17, 0.8)), 0.1, 0.025, "horn", "head", blend=0.03)
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.13, 0.2, -0.02), k), (0.04, 0.03, 0.05)))
    d.ears_pointed(width=0.22, thick=0.05, rounding=0.07, turn=0.6)
    d.legs(front=(0.2, 0.185, 0.18), hind=(0.21, 0.19, 0.18), paw=(0.19, 0.2, 0.1))
    d.tail((0.05, 0.04, 0.04, 0.04))
    d.blob(d.p("tail_tip_end"), (0.08, 0.08, 0.1), "tuft", "tail3", blend=0.03)
    d.eye(toward=(-0.7, 0.66, 0.2), radius=0.085)

    # Folds of hide: behind the shoulders and before the haunches.
    d.paint("fold", both(part("torso"), d.bands("withers", (0, -0.33, 0), (0, 1, 0), 0.78, 0.1)))
    d.paint("horn", part("horn"))
    d.paint("fold", part("tuft"))
    d.paint("inner", d.ear_fronts())
    d.paint("toe", both(part("leg"), d.below("front_toe.L", (0, 0, 0.1))))
    # On its card it stands side on, its horns and its face to us (the old pose, charging head down, hid them).
    return d.toy(hero=card_pose(0.12, jaw=-0.1, turn=-0.5, head=(0.3, 0.5)))
