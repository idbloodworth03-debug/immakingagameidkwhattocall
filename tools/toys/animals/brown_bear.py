"""Brown Bear as a toy: a big round brown body on thick legs, a wide head
with a pale muzzle and a big dark nose, small round ears with pale insides,
a stub of a tail and pale claws.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "brown": "#8f5c3b",
    "pale": "#e2bd92",
    "dark": "#5e3a26",
    "claw": "#f1e3c8",
}


def make():
    d = Design("brown_bear", COLORS, "brown")
    d.put("ear_base", "skull", (-0.36, -0.04, 0.3))
    d.put("ear_tip", "skull", (-0.45, -0.04, 0.46))
    d.torso(rump=(0.4, 0.46, 0.4), chest=(0.42, 0.42, 0.44), rump_at=(0, 0.08, -0.1), chest_at=(0, -0.03, -0.1))
    d.neck(0.38, 0.36)
    d.head((0.46, 0.42, 0.4))
    d.muzzle(root=(0, 0.2, -0.1), base=0.24, end=0.17, tip=(0, -0.06, 0.08))
    d.nose("snout_tip", (0, 0.1, 0.13), (0.12, 0.08, 0.09))
    d.ears_round((0.15, 0.07, 0.15))
    d.legs(front=(0.2, 0.18, 0.165), hind=(0.21, 0.185, 0.165), paw=(0.19, 0.23, 0.13))
    d.tail((0.1, 0.09, 0.08, 0.06))
    d.eye(toward=(-0.5, 0.84, 0.16), radius=0.11)

    d.paint("pale", both(part("muzzle", "head"), d.ahead("skull", (0, 0.26, 0)), d.below("skull", (0, 0, 0.06))))
    d.paint("pale", both(part("ear"), facing((0, 1, 0), 0.55)))
    d.paint("dark", both(part("leg"), d.below("wrist.L", (0, 0, 0.12))))
    d.paint("claw", both(part("leg"), either(d.around("front_toe.L", (0, 0.1, -0.02), (0.2, 0.14, 0.08), mirrored=True),
                                             d.around("hind_toe.L", (0, 0.1, -0.02), (0.2, 0.14, 0.08), mirrored=True))))
    return d.toy()
