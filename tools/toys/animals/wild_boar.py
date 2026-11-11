"""Wild Boar as a toy: a brown barrel with high shoulders on short dark
legs, a big head with a long snout ending in a flat pink disc, two white
tusks curving up, pointed ears, a ridge of dark bristles down its neck and
back, and a thin tail with a tuft.
"""
import numpy as np

from kit import Design, both, but, either, facing, part, side

COLORS = {
    "brown": "#7d5b45",
    "dark": "#45342d",
    "belly": "#9d7c62",
    "snout": "#e0a195",
    "tusk": "#fff6df",
    "inner": "#c98f84",
}


def make():
    d = Design("wild_boar", COLORS, "brown", changes={
        # A shorter snout than the old model's, held a little higher.
        "snout_tip": (0, 0.97, 0.56), "chin": (0, 0.86, 0.5),
        "ear_base": (-0.21, 0.62, 1.02), "ear_tip": (-0.3, 0.58, 1.2),
    })
    d.torso(rump=(0.36, 0.42, 0.36), chest=(0.4, 0.4, 0.43), rump_at=(0, 0.08, -0.1), chest_at=(0, -0.03, -0.08))
    d.neck(0.36, 0.33)
    d.head((0.4, 0.4, 0.36))
    d.muzzle(root=(0, 0.2, -0.12), base=0.27, end=0.19)
    # The disc of its nose, and its nostrils.
    aim = d.j("snout_tip") - d.p("skull", (0, 0.2, -0.12))
    pitch = float(np.arctan2(aim[2], aim[1]))
    d.blob(d.p("snout_tip", (0, 0.02, 0)), (0.21, 0.07, 0.18), "disc", "head", blend=0.03, pitch=pitch)
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.075, 0.085, 0.0), k), (0.035, 0.03, 0.05)))
    # Tusks, from the sides of its lower snout.
    d.pair(lambda s, k: d.stick(d.p("snout_tip", side((-0.2, -0.16, -0.1), k)), d.p("snout_tip", side((-0.3, -0.1, 0.2), k)), 0.055, 0.015,
                                "tusk", "head", blend=0.02))
    d.ears_pointed(width=0.26, turn=0.5)
    # A ridge of bristles from its brow to the middle of its back.
    for at, bone, lift, tall in (("skull", "head", 0.3, 0.13), ("head_base", "neck", 0.36, 0.16), ("withers", "chest", 0.36, 0.17),
                                 ("spine_mid", "hips", 0.33, 0.13)):
        d.blob(d.p(at, (0, 0, lift)), (0.07, 0.26, tall), "mane", bone, blend=0.03)
    d.legs(front=(0.14, 0.12, 0.105), hind=(0.15, 0.125, 0.105), paw=(0.11, 0.13, 0.09))
    d.tail((0.05, 0.04, 0.04, 0.04))
    d.blob(d.p("tail_tip_end"), (0.09, 0.09, 0.11), "tuft", "tail3", blend=0.03)
    d.eye(toward=(-0.62, 0.74, 0.2), radius=0.1)

    d.paint("belly", both(part("torso"), facing((0, 0, -1), 0.45)))
    d.paint("snout", part("disc"))
    d.paint("tusk", part("tusk"))
    d.paint("dark", part("mane", "tuft", "leg"))
    d.paint("inner", d.ear_fronts())
    return d.toy()
