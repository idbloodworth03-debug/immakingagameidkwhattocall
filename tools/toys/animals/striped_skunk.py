"""Striped Skunk as a toy: a chubby black body with its rump up on four
thick legs, a big round head with a white blaze up its face, a white cap
on its neck that splits into two stripes down its back, and a great black
plume of a tail with a white stripe up its middle, held high.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "black": "#2d2b32",
    "white": "#fbf8f1",
    "nose": "#e08a98",
}


def make():
    d = Design("striped_skunk", COLORS, "black")
    d.put("ear_base", "skull", (-0.4, -0.08, 0.36))
    d.put("ear_tip", "skull", (-0.5, -0.08, 0.5))
    d.torso(rump=(0.46, 0.5, 0.46), chest=(0.43, 0.45, 0.44), rump_at=(0, 0.14, -0.26), chest_at=(0, -0.06, -0.02))
    d.neck(0.38, 0.36)
    d.head((0.58, 0.48, 0.5))
    d.muzzle(root=(0, 0.26, -0.14), base=0.24, end=0.13, tip=(0, 0.0, 0.06))
    d.nose("snout_tip", (0, 0.11, 0.1), (0.09, 0.065, 0.065))
    d.ears_round((0.13, 0.07, 0.13))
    d.legs(front=(0.18, 0.17, 0.16), hind=(0.19, 0.175, 0.16), paw=(0.17, 0.21, 0.12))
    d.tail((0.26, 0.44, 0.42, 0.22))
    d.eye(toward=(-0.5, 0.84, 0.06), radius=0.15)

    # Two stripes down its back, joined in a cap on its neck; a blaze up its face.
    d.paint("white", both(part("torso"), facing((0, 0, 1), 0.3), d.off_middle(0.1), d.near_middle(0.36)))
    d.paint("white", both(part("head", "torso"), facing((0, 0, 1), 0.45), d.near_middle(0.34), d.behind("skull", (0, 0.0, 0)),
                          d.ahead("neck_base", (0, 0.1, 0))))
    d.paint("white", both(part("head", "muzzle"), d.near_middle(0.09), d.above("snout_tip", (0, 0, 0.14))))
    d.paint("white", both(part("tail"), d.near_middle(0.25)))
    return d.toy()
