"""Lion as a toy: a tan body on big soft paws, and his mane: a great dark
ruff round his face and down his chest, his round ears poking out of it.
A cream muzzle and chin, a dark nose, and a thin tail with a dark tuft.
"""
import math

from kit import Design, both, but, either, facing, part, side

COLORS = {
    "tan": "#e3ab5c",
    "mane": "#9c4f1d",
    "cream": "#fff0d2",
    "dark": "#5a3018",
    "inner": "#c98458",
}


def make():
    d = Design("lion", COLORS, "tan")
    d.put("ear_base", "skull", (-0.43, 0.14, 0.4))
    d.put("ear_tip", "skull", (-0.52, 0.14, 0.56))
    d.torso(rump=(0.3, 0.4, 0.3), chest=(0.33, 0.36, 0.36), rump_at=(0, 0.08, -0.12), chest_at=(0, -0.03, -0.1))
    d.neck(0.3, 0.28)
    d.head((0.4, 0.38, 0.36))
    # The mane: a ruff behind the face, and down the chest.
    d.blob(d.p("skull", (0, -0.2, -0.04)), (0.74, 0.42, 0.76), "mane", "head", blend=0.06)
    d.blob(d.p("neck_base", (0, 0.1, -0.02)), (0.46, 0.38, 0.5), "mane", "neck", blend=0.12)
    # Tufts round its edge.
    for k in range(9):
        a = math.pi * (0.5 + (k - 4) * 0.19)
        d.blob(d.p("skull", (0.66 * math.cos(a), -0.2, -0.04 + 0.68 * math.sin(a))), (0.2, 0.22, 0.2), "mane", "head", blend=0.1)
    d.muzzle(root=(0, 0.2, -0.1), base=0.24, end=0.17)
    d.nose("snout_tip", (0, 0.07, 0.05), (0.12, 0.07, 0.08))
    d.ears_round((0.15, 0.07, 0.15))
    d.legs(front=(0.15, 0.135, 0.125), hind=(0.16, 0.14, 0.125), paw=(0.15, 0.19, 0.11))
    d.tail((0.07, 0.06, 0.05, 0.05))
    d.blob(d.p("tail_tip_end"), (0.13, 0.13, 0.15), "tuft", "tail3", blend=0.03)
    d.eye(toward=(-0.52, 0.82, 0.14), radius=0.12)

    d.paint("cream", both(part("torso"), facing((0, 0, -1), 0.4)))
    d.paint("cream", both(part("muzzle", "head"), d.below("snout_tip", (0, 0, 0.06)), d.ahead("skull", (0, 0.12, 0))))
    d.paint("mane", part("mane"))
    d.paint("dark", part("tuft"))
    d.paint("inner", both(part("ear"), facing((0, 1, 0), 0.5)))
    return d.toy()
