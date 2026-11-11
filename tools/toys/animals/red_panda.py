"""Red Panda as a toy: a chubby rust-red body on four thick black legs, a
big wide head with white cheek tufts, a white muzzle and white brows, big
pointed ears with white rims, and its bushy ringed tail carried up behind.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "rust": "#bf4a1c",
    "deep": "#7f2d12",
    "black": "#261a17",
    "white": "#f8f1e4",
    "buff": "#e9ad68",
}


def make():
    d = Design("red_panda", COLORS, "rust", changes={
        # Its ringed tail is carried up behind it (the part of a red panda you see from behind).
        "tail_base": (0, -0.15, 0.2), "tail_mid": (0, -0.205, 0.3), "tail_end": (0, -0.225, 0.42),
        "tail_tip_end": (0, -0.222, 0.48),
    })
    d.put("ear_base", "skull", (-0.42, -0.06, 0.34))
    d.put("ear_tip", "skull", (-0.66, -0.08, 0.76))
    d.torso(rump=(0.46, 0.5, 0.45), chest=(0.43, 0.45, 0.44), rump_at=(0, 0.12, -0.04), chest_at=(0, -0.06, -0.02))
    d.neck(0.38, 0.36)
    d.head((0.62, 0.48, 0.5))
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.36, 0.06, -0.14), k)), d.p("skull", side((-0.76, -0.02, -0.24), k)), 0.23, 0.05,
                                "cheek", "head", blend=0.12))
    d.muzzle(root=(0, 0.26, -0.14), base=0.23, end=0.14, tip=(0, -0.02, 0.06))
    d.nose("snout_tip", (0, 0.1, 0.1), (0.09, 0.062, 0.062))
    d.ears_pointed(width=0.42, thick=0.06, rounding=0.12, turn=0.3)
    d.legs(front=(0.18, 0.17, 0.16), hind=(0.19, 0.175, 0.16), paw=(0.17, 0.21, 0.12))
    d.tail((0.21, 0.32, 0.3, 0.14))
    d.eye(toward=(-0.5, 0.84, 0.06), radius=0.15)

    d.paint("black", part("leg"))
    d.paint("black", both(part("torso"), facing((0, 0, -1), 0.35)))
    # Its face: a white muzzle, white cheek tufts and a white brow over each eye.
    d.paint("white", part("muzzle", "cheek"))
    d.paint("white", both(part("head"), d.around("skull", (-0.3, 0.42, 0.3), (0.16, 0.22, 0.09), mirrored=True)))
    # Buff rings round its tail, and a dark tip.
    along = d.j("tail_end") - d.j("tail_base")
    d.paint("buff", both(part("tail"), d.bands("tail_tip_end", (0, 0, 0), along, 0.46, 0.5)))
    d.paint("deep", both(part("tail"), d.beyond("tail_tip_end", (0, 0, -0.08), along)))
    d.paint("white", part("ear"))
    d.paint("deep", d.ear_fronts(inset=0.05))
    return d.toy()
