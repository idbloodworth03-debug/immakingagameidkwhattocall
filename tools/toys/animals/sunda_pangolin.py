"""Sunda Pangolin as a toy: a living pinecone. A chunky arched body
under rows of tan plates from its brow to the tip of its thick tail, a big head with a pale pointed snout, a pale belly, four
stubby legs and pale claws.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "hide": "#7a5631",
    "scale": "#b98a4f",
    "skin": "#eed6c2",
    "claw": "#f4e8d2",
}


def make():
    d = Design("sunda_pangolin", COLORS, "hide")
    # A toy pangolin is shorter than the real one: its head comes back and up toward its shoulders, and its tail's
    # joints come in toward its root and off the ground.
    d.move(["head_base", "skull", "snout_tip", "jaw_hinge", "chin"], (0, -0.25, 0.2))
    root = d.j("tail_base")
    for name, lift in (("tail_mid", 0.12), ("tail_end", 0.2), ("tail_tip_end", 0.24)):
        at = root + (d.j(name) - root) * 0.62
        d.c.joints[name] = (at[0], at[1], at[2] + lift * d.u)
    d.torso(rump=(0.6, 0.66, 0.6), chest=(0.56, 0.6, 0.56), rump_at=(0, 0.14, -0.14), chest_at=(0, -0.08, -0.1))
    d.blob(d.p("spine_mid", (0, 0, -0.12)), (0.62, 0.64, 0.64), "torso", "hips", blend=0.25)
    d.neck(0.44, 0.4)
    d.head((0.54, 0.54, 0.5))
    d.muzzle(root=(0, 0.26, -0.12), base=0.3, end=0.13)
    d.nose("snout_tip", (0, 0.09, 0.05), (0.09, 0.065, 0.065))
    d.legs(front=(0.25, 0.23, 0.21), hind=(0.26, 0.235, 0.21), paw=(0.23, 0.28, 0.12))
    d.tail((0.46, 0.38, 0.26, 0.12))
    d.eye(toward=(-0.6, 0.76, 0.24), radius=0.125)

    # Scales: rows of plates wrapped over its back like roof tiles, each a raised band leaning back onto the next,
    # and smaller ones down its tail.
    for where, at, reach, bone in (("pelvis", (0, -0.34, -0.14), 0.58, "hips"), ("pelvis", (0, 0.08, -0.14), 0.64, "hips"),
                                   ("spine_mid", (0, -0.22, -0.12), 0.68, "hips"), ("spine_mid", (0, 0.2, -0.12), 0.68, "chest"),
                                   ("withers", (0, -0.06, -0.1), 0.63, "chest"), ("withers", (0, 0.36, -0.08), 0.54, "chest")):
        d.blob(d.p(where, at), (reach, 0.25, reach), "scale", bone, blend=0.03, pitch=-0.22)
    for where, at, reach, bone in (("tail_base", (0, -0.1, 0), 0.5, "tail1"), ("tail_mid", (0, 0.16, 0.02), 0.44, "tail1"),
                                   ("tail_mid", (0, -0.2, 0), 0.36, "tail2"), ("tail_end", (0, 0.06, 0), 0.28, "tail2")):
        d.blob(d.p(where, at), (reach, 0.2, reach), "scale", bone, blend=0.03, pitch=-0.5)

    d.paint("scale", part("scale"))
    # The same plates over its brow and the back of its head.
    d.paint("scale", both(part("head"), d.above("skull", (0, 0, 0.16)), d.behind("skull", (0, 0.3, 0))))
    # Soft pale skin: its snout and the underside of its body and tail.
    d.paint("skin", both(part("head", "muzzle"), d.ahead("skull", (0, 0.2, 0)), d.below("skull", (0, 0, 0.14))))
    d.paint("skin", both(part("torso", "tail", "head", "muzzle"), facing((0, 0, -1), 0.4)))
    d.paint("claw", both(part("leg"), either(d.around("front_toe.L", (0, 0.14, -0.02), (0.24, 0.18, 0.09), mirrored=True),
                                             d.around("hind_toe.L", (0, 0.12, -0.02), (0.24, 0.15, 0.09), mirrored=True))))
    return d.toy()
