"""Asian Elephant as a toy: a big blue-grey body on four pillars, a great
round head with wide flat ears (pink inside), a trunk that swings, two
small white tusks, pale toenails and a thin tail with a tuft.
"""
from kit import Design, both, but, card_pose, either, facing, part, side

COLORS = {
    "grey": "#93a2b6",
    "inner": "#e9b3b8",
    "tusk": "#fff8e6",
    "nail": "#e9eef4",
    "dark": "#5d6a7c",
}


def make():
    d = Design("asian_elephant", COLORS, "grey", changes={
        # A smaller head than the old model's, sitting lower on its neck.
        "skull": (0, 1.08, 2.5), "head_base": (0, 0.9, 2.2), "snout_tip": (0, 1.5, 2.2), "jaw_hinge": (0, 1.12, 2.1),
        "chin": (0, 1.36, 1.98),
        "trunk_base": (0, 1.52, 2.28), "trunk_mid": (0, 1.78, 1.72), "trunk_end": (0, 1.84, 1.2), "trunk_tip": (0, 1.8, 0.9),
    })
    d.put("ear_base", "skull", (-0.3, -0.08, 0.16))
    d.put("ear_tip", "skull", (-0.62, -0.22, -0.3))
    d.torso(rump=(0.42, 0.5, 0.42), chest=(0.45, 0.46, 0.46), rump_at=(0, 0.08, -0.12), chest_at=(0, -0.03, -0.1))
    d.neck(0.36, 0.34)
    d.head((0.38, 0.36, 0.36))
    # The trunk, along its three bones.
    d.stick("trunk_base", "trunk_mid", 0.15, 0.11, "trunk", "trunk1", "trunk2", blend=0.12)
    d.stick("trunk_mid", "trunk_end", 0.11, 0.085, "trunk", "trunk2", "trunk3", blend=0.05)
    d.stick("trunk_end", "trunk_tip", 0.085, 0.075, "trunk", "trunk3", blend=0.04)
    d.stick(d.p("skull", (0, 0.2, -0.08)), "trunk_base", 0.2, 0.16, "trunk", "head", blend=0.14)
    # Ears: wide flat fans at the sides of its head.
    d.pair(lambda s, k: d.blob(d.p("skull", side((-0.5, -0.14, -0.06), k)), (0.3, 0.05, 0.34), "ear", "ear" + s, blend=0.06, yaw=-0.5 * k))
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.16, 0.24, -0.24), k)), d.p("skull", side((-0.22, 0.5, -0.36), k)), 0.05, 0.015,
                                "tusk", "head", blend=0.02))
    d.legs(front=(0.2, 0.19, 0.185), hind=(0.21, 0.195, 0.185), paw=(0.19, 0.2, 0.09))
    d.tail((0.04, 0.035, 0.03, 0.03))
    d.blob(d.p("tail_tip_end"), (0.06, 0.06, 0.08), "tuft", "tail3", blend=0.03)
    d.eye(toward=(-0.62, 0.76, 0.06), radius=0.075)

    d.paint("inner", both(part("ear"), facing((0, 1, 0), 0.35)))
    d.paint("tusk", part("tusk"))
    d.paint("dark", part("tuft"))
    d.paint("nail", both(part("leg"), either(d.around("front_toe.L", (0, 0.1, 0.0), (0.2, 0.1, 0.07), mirrored=True),
                                             d.around("hind_toe.L", (0, 0.1, 0.0), (0.2, 0.1, 0.07), mirrored=True))))
    # On its card it faces us with its trunk up and its head tipped down, so both big ears show.
    return d.toy(hero=card_pose(0.35, jaw=-0.3, turn=0.2, head=(-0.3, 0.0)))
