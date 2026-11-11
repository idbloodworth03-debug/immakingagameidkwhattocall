"""Striped Skunk as a toy: a black body with its rump up, a small pointed
head with a thin white blaze, a white cap on its neck that splits into two
stripes down its back, and a great black plume of a tail with a white
stripe up its middle, held high.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "black": "#2d2b32",
    "white": "#fbf8f1",
    "nose": "#e08a98",
}


def make():
    d = Design("striped_skunk", COLORS, "black")
    d.put("ear_base", "skull", (-0.33, -0.06, 0.24))
    d.put("ear_tip", "skull", (-0.42, -0.06, 0.36))
    d.torso(rump=(0.48, 0.54, 0.48), chest=(0.43, 0.46, 0.44), rump_at=(0, 0.14, -0.26), chest_at=(0, -0.08, -0.04))
    d.neck(0.34, 0.32)
    d.head((0.44, 0.4, 0.36))
    d.muzzle(root=(0, 0.2, -0.1), base=0.2, end=0.11, tip=(0, -0.04, 0.08))
    d.nose("snout_tip", (0, 0.06, 0.1), (0.075, 0.055, 0.055))
    d.ears_round((0.11, 0.06, 0.11))
    d.legs(front=(0.14, 0.13, 0.12), hind=(0.15, 0.135, 0.12), paw=(0.14, 0.18, 0.1))
    d.tail((0.24, 0.42, 0.4, 0.2))
    d.eye(toward=(-0.52, 0.82, 0.1), radius=0.11)

    # Two stripes down its back, joined in a cap on its neck; a thin blaze up its face.
    d.paint("white", both(part("torso"), facing((0, 0, 1), 0.3), d.off_middle(0.09), d.near_middle(0.34)))
    d.paint("white", both(part("head", "torso"), facing((0, 0, 1), 0.45), d.near_middle(0.3), d.behind("skull", (0, 0.0, 0)),
                          d.ahead("neck_base", (0, 0.1, 0))))
    d.paint("white", both(part("head", "muzzle"), d.near_middle(0.065), d.above("snout_tip", (0, 0, 0.12))))
    d.paint("white", both(part("tail"), d.near_middle(0.24)))
    return d.toy()
