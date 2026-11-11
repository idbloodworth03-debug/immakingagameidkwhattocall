"""Gray Squirrel as a toy: a small round grey body on four short thick
legs, a big head with fat white cheeks and tufted ears, a white belly, and
its great bushy tail curled up over its back, frosted white along its
edges.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "grey": "#9d9ca6",
    "white": "#f8f5ee",
    "inner": "#f2b9b0",
    "nose": "#5b4046",
}


def make():
    # (A small animal with a big head: its sizes are in tenths of a meter.)
    d = Design("gray_squirrel", COLORS, "grey", unit=0.1)
    # It spends its time sat up on its haunches, its whole body tipped nose-up: so its face is built tipped down, to
    # look at us when it sits up (its ears, cheeks, muzzle and eyes are all turned 38 degrees down round its skull).
    d.put("ear_base", "skull", (-0.33, 0.21, 0.34))
    d.put("ear_tip", "skull", (-0.44, 0.42, 0.64))
    d.put("snout_tip", "skull", (0, 0.2, -0.57))
    d.torso(rump=(0.44, 0.46, 0.46), chest=(0.4, 0.4, 0.42), rump_at=(0, 0.12, -0.08), chest_at=(0, -0.06, 0.0))
    d.neck(0.32, 0.3)
    d.head((0.6, 0.52, 0.52))
    d.pair(lambda s, k: d.blob(d.p("skull", side((-0.3, 0.0, -0.26), k)), (0.26, 0.24, 0.22), "head", "head", blend=0.1))
    d.muzzle(root=(0, 0.12, -0.24), base=0.22, end=0.13)
    d.nose("snout_tip", (0, 0.12, -0.01), (0.075, 0.055, 0.055))
    d.ears_pointed(width=0.26, thick=0.06, rounding=0.08)
    d.legs(front=(0.17, 0.16, 0.15), hind=(0.19, 0.17, 0.15), paw=(0.15, 0.2, 0.1))
    d.tail((0.24, 0.44, 0.42, 0.24), blend=0.12)
    d.eye(toward=(-0.56, 0.7, -0.4), radius=0.16)

    d.paint("white", both(part("torso"), facing((0, 0.3, -1), 0.2)))
    # Its white lower face: under its eyes and ahead of its cheeks, in the tipped-down face's own directions.
    d.paint("white", both(part("head", "muzzle"), d.beyond("skull", (0, -0.086, -0.11), (0, -0.616, -0.788)),
                          d.beyond("skull", (0, 0.047, -0.037), (0, 0.788, -0.616))))
    d.paint("white", both(part("tail"), d.off_middle(0.34)))
    d.paint("inner", d.ear_fronts())
    return d.toy()
