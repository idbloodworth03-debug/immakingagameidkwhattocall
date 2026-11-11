"""Wild Bactrian Camel as a toy: a sandy body on long thin legs with two
humps on its back, a long neck up to a small head with a drooping muzzle,
shaggy brown fur on its humps, its throat and the top of its head, split
dark feet, and a thin tail with a tuft.
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
    d.put("ear_base", "skull", (-0.2, -0.1, 0.13))
    d.torso(rump=(0.3, 0.36, 0.3), chest=(0.3, 0.34, 0.32), rump_at=(0, 0.06, -0.1), chest_at=(0, -0.06, -0.12))
    # Two humps: one over its shoulders, one over its hips.
    d.blob(d.p("withers", (0, -0.16, 0.3)), (0.17, 0.19, 0.36), "hump", "chest", blend=0.08)
    d.blob(d.p("pelvis", (0, 0.12, 0.34)), (0.17, 0.19, 0.36), "hump", "hips", blend=0.08)
    d.neck(0.2, 0.16)
    # Shaggy fur down its throat, and a tuft on its head.
    d.blob(d.p("neck_base", (0, 0.2, 0.08)), (0.15, 0.15, 0.24), "shag", "neck", blend=0.08, pitch=-0.5)
    d.head((0.24, 0.26, 0.22))
    d.blob(d.p("skull", (0, -0.06, 0.2)), (0.15, 0.15, 0.11), "shag", "head", blend=0.06)
    d.muzzle(root=(0, 0.14, -0.05), base=0.19, end=0.15)
    d.jaw(0.13, 0.12)
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.06, 0.11, 0.07), k), (0.025, 0.02, 0.035)))
    d.ears_round((0.07, 0.04, 0.09))
    d.legs(front=(0.12, 0.09, 0.075), hind=(0.13, 0.095, 0.075), paw=(0.11, 0.14, 0.07))
    d.tail((0.05, 0.04, 0.035, 0.03))
    d.blob(d.p("tail_tip_end"), (0.07, 0.07, 0.1), "tuft", "tail3", blend=0.03)
    d.eye(toward=(-0.62, 0.74, 0.25), radius=0.07)

    d.paint("shag", part("shag", "tuft"))
    d.paint("shag", both(part("hump"), d.above("withers", (0, 0, 0.36))))
    d.paint("pale", both(part("muzzle", "jaw"), d.ahead("snout_tip", (0, -0.16, 0))))
    d.paint("mouth", both(d.mouth_line(0.1), d.ahead("skull", (0, 0.1, 0))))
    d.paint("hoof", both(part("leg"), d.below("front_toe.L", (0, 0, 0.1))))
    return d.toy()
