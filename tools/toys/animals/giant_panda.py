"""Giant Panda as a toy: a round white body with black legs joined over the
shoulders by a black band, a big white head with black eye patches and
round black ears, and a dark nose.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "white": "#fbfaf5",
    "black": "#2a272e",
}


def make():
    d = Design("giant_panda", COLORS, "white")
    d.put("ear_base", "skull", (-0.36, -0.04, 0.32))
    d.put("ear_tip", "skull", (-0.46, -0.04, 0.5))
    # Its short muzzle pokes out of the big round head.
    d.put("snout_tip", "skull", (0, 0.47, -0.2))
    d.torso(rump=(0.44, 0.48, 0.43), chest=(0.45, 0.44, 0.46), rump_at=(0, 0.08, -0.08), chest_at=(0, -0.03, -0.06))
    d.neck(0.4, 0.38)
    d.head((0.5, 0.44, 0.43))
    d.muzzle(root=(0, 0.2, -0.14), base=0.2, end=0.15, blend=0.1)
    d.nose("snout_tip", (0, 0.13, 0.07), (0.1, 0.06, 0.07))
    d.ears_round((0.17, 0.08, 0.17))
    d.legs(front=(0.21, 0.19, 0.175), hind=(0.22, 0.195, 0.175), paw=(0.2, 0.24, 0.13))
    d.tail((0.1, 0.09, 0.08, 0.06))
    d.eye(toward=(-0.45, 0.87, 0.12), radius=0.1)

    d.paint("black", part("leg", "ear"))
    # The band over its shoulders, joining the front legs.
    d.paint("black", both(part("torso"), d.ahead("withers", (0, -0.22, 0)), d.behind("withers", (0, 0.2, 0))))
    # Eye patches: slanted ovals round each eye.
    d.paint("black", both(part("head"), d.around("skull", (-0.21, 0.36, 0.02), (0.15, 0.2, 0.2), yaw=0.0, pitch=0.5, mirrored=True)))
    return d.toy()
