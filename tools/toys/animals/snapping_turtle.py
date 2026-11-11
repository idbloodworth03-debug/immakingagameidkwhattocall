"""Snapping Turtle as a toy: a domed olive shell with three ridges and a
pale rim, a pale underside, a big green head with a hooked beak and a jaw
that snaps open, short sprawled legs with pale claws, and a spiked tail.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "skin": "#7f9455",
    "shell": "#5b6b3a",
    "ridge": "#46532c",
    "rim": "#b9bf7c",
    "belly": "#e2d594",
    "mouth": "#c9506a",
    "claw": "#f1ecd2",
}


def make():
    # (Its legs stay sprawled out to its sides.)
    d = Design("snapping_turtle", COLORS, "skin", straight_legs=False, unit=0.2, changes={
        "chin": (0, 0.4, 0.125), "jaw_hinge": (0, 0.31, 0.15),
    })
    # The shell: a dome over the body, and the flat plate under it.
    d.blob(d.p("spine_mid", (0, 0, 0.06)), (1.02, 1.18, 0.62), "shell", "hips", blend=0.0)
    d.blob(d.p("spine_mid", (0, 0, -0.2)), (0.9, 1.05, 0.26), "plate", "hips", blend=0.05)
    for x in (-0.42, 0.0, 0.42):
        for y in (-0.55, 0.0, 0.55):
            lift = 0.62 * (1 - (x / 1.02) ** 2 - (y / 1.18) ** 2) ** 0.5
            d.blob(d.p("spine_mid", (x, y, 0.06 + lift)), (0.16, 0.22, 0.12), "ridge", "hips", blend=0.06)
    d.stick("neck_base", "head_base", 0.34, 0.32, "neck", "neck", "head", blend=0.1)
    d.head((0.5, 0.52, 0.42))
    d.muzzle(root=(0, 0.25, -0.02), base=0.34, end=0.2, blend=0.1)
    d.stick(d.p("snout_tip", (0, 0.0, 0.0)), d.p("snout_tip", (0, 0.06, -0.2)), 0.16, 0.05, "muzzle", "head", blend=0.04)
    d.jaw(0.26, 0.2)
    d.legs(front=(0.26, 0.22, 0.19), hind=(0.26, 0.22, 0.19), paw=(0.2, 0.24, 0.1))
    d.tail((0.24, 0.17, 0.1, 0.04))
    for at, bone in (("tail_base", "tail1"), ("tail_mid", "tail2")):
        d.flat(d.p(at, (0, 0.12, 0.08)), d.p(at, (0, -0.12, 0.08)), d.p(at, (0, -0.1, 0.34)), 0.05, 0.05, "spike", bone, blend=0.03)
    d.eye(toward=(-0.6, 0.72, 0.34), radius=0.15)

    d.paint("shell", part("shell", "ridge"))
    d.paint("rim", both(part("shell"), d.below("spine_mid", (0, 0, -0.08))))
    d.paint("ridge", part("ridge", "spike"))
    d.paint("belly", part("plate"))
    d.paint("mouth", both(d.mouth_line(0.12), d.ahead("jaw_hinge", (0, 0.1, 0))))
    d.paint("claw", both(part("leg"), either(d.around("front_toe.L", (0, 0.12, 0), (0.24, 0.16, 0.09), mirrored=True),
                                             d.around("hind_toe.L", (0, -0.12, 0), (0.24, 0.16, 0.09), mirrored=True))))
    return d.toy()
