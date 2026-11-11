"""Wild Bactrian Camel as a toy: a chubby sandy body on four thick legs
with two tall humps on its back, a short neck up to a big head with a
great soft muzzle, shaggy brown fur on its humps, its throat and the top
of its head, dark feet, and a thin tail with a tuft.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "sand": "#d6aa6a",
    "shag": "#8e6034",
    "pale": "#f0dbb2",
    "hoof": "#5c4431",
    "mouth": "#7b3d3d",
}


def make():
    d = Design("wild_bactrian_camel", COLORS, "sand")
    # Its head held a little higher, clear of its chest.
    d.move(["head_base", "skull", "snout_tip", "jaw_hinge", "chin"], (0, 0.06, 0.22))
    d.put("ear_base", "skull", (-0.37, -0.12, 0.26))
    d.torso(rump=(0.42, 0.46, 0.42), chest=(0.42, 0.44, 0.45), rump_at=(0, 0.08, -0.12), chest_at=(0, -0.05, -0.14))
    # Two humps: one over its shoulders, one over its hips.
    d.blob(d.p("withers", (0, -0.2, 0.36)), (0.23, 0.23, 0.36), "hump", "chest", blend=0.08)
    d.blob(d.p("pelvis", (0, 0.16, 0.4)), (0.23, 0.23, 0.36), "hump", "hips", blend=0.08)
    d.neck(0.3, 0.27)
    # Shaggy fur down its throat, and a tuft on its head.
    d.blob(d.p("neck_base", (0, 0.3, 0.2)), (0.2, 0.18, 0.3), "shag", "neck", blend=0.08, pitch=-0.5)
    d.head((0.44, 0.44, 0.4))
    d.blob(d.p("skull", (0, -0.08, 0.38)), (0.21, 0.21, 0.14), "shag", "head", blend=0.06)
    d.muzzle(root=(0, 0.2, -0.1), base=0.3, end=0.24, tip=(0, 0.22, -0.1))
    d.jaw(0.2, 0.18, tip=(0, 0.2, -0.1))
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.08, 0.4, 0.02), k), (0.03, 0.025, 0.04)))
    d.ears_round((0.1, 0.05, 0.12))
    d.legs(front=(0.19, 0.17, 0.155), hind=(0.2, 0.175, 0.155), paw=(0.18, 0.22, 0.12))
    d.tail((0.07, 0.06, 0.05, 0.04))
    d.blob(d.p("tail_tip_end"), (0.1, 0.1, 0.13), "tuft", "tail3", blend=0.03)
    d.eye(toward=(-0.56, 0.8, 0.18), radius=0.115)

    d.paint("shag", part("shag", "tuft"))
    d.paint("shag", both(part("hump"), d.above("withers", (0, 0, 0.44))))
    d.paint("pale", both(part("muzzle", "jaw"), d.ahead("snout_tip", (0, 0.0, 0))))
    d.paint("mouth", both(d.mouth_line(0.08), d.ahead("skull", (0, 0.3, 0))))
    d.paint("hoof", both(part("leg"), d.below("front_toe.L", (0, 0, 0.16))))
    return d.toy()
