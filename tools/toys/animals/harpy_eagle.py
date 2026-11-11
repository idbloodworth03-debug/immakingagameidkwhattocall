"""Harpy Eagle as a toy: a heavy round dark body with a big pale grey head
held high and a double crest standing up behind it, a white belly under a
dark chest, broad stubby wings with fingered tips, a big hooked beak, grey
bands across its tail, and huge yellow feet dangling under it.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "dark": "#3d4453",
    "grey": "#bdc4cd",
    "white": "#f8f6f1",
    "yellow": "#f4c43d",
    "beak": "#30343c",
}


def make():
    # (A bird has no withers to measure by: its sizes are in units of 22 cm.)
    d = Design("harpy_eagle", COLORS, "dark", unit=0.22)
    d.bird_stance(foot=(-0.34, 0.05, -1.0))
    d.shorten_wings(0.36)
    d.put("beak_tip", "skull", (0, 1.04, -0.24))
    d.put("jaw_hinge", "skull", (0, 0.6, -0.36))
    d.put("chin", "skull", (0, 0.94, -0.42))
    d.torso(rump=(0.74, 0.82, 0.7), chest=(0.84, 0.76, 0.8), rump_at=(0, 0.35, 0), chest_at=(0, -0.15, 0.05), blend=0.2)
    d.neck(0.6, 0.6)
    d.head((0.94, 0.78, 0.88))
    # The crest: two tufts standing up and back from its crown.
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.3, -0.2, 0.76), k)), d.p("skull", side((-0.6, -0.56, 1.4), k)), 0.24, 0.07,
                                "crest", "head", blend=0.08))
    d.beak(root=(0, 0.56, -0.18), base=0.26, end=0.12, hook=0.22)
    d.jaw(0.14, 0.07)
    d.wings((1.3, 1.2, 0.95), thick=0.13)
    d.wing_fingers(3, 0.5, 0.17)
    d.tail_fan(1.35, root=0.5)
    d.bird_legs(0.17, (0.3, 0.34, 0.16))
    d.eye(toward=(-0.5, 0.84, 0.14), radius=0.2)

    d.paint("grey", part("head", "crest"))
    d.paint("dark", both(part("crest"), d.above("skull", (0, 0, 1.12))))
    # White underneath, behind its dark chest; white legs; grey bands across its tail.
    d.paint("white", both(part("torso"), facing((0, 0, -1), 0.1), d.behind("withers", (0, -0.3, 0))))
    d.paint("white", both(part("wing"), facing((0, 0, -1), 0.3)))
    d.paint("white", part("leg"))
    d.paint("grey", both(part("tail"), d.bands("tail_end", (0, 0.14, 0), (0, 1, 0), 0.56, 0.4)))
    d.paint("beak", part("beak", "jaw"))
    d.paint("yellow", both(part("beak"), d.behind("skull", (0, 0.88, 0))))
    d.paint("yellow", part("foot"))
    return d.toy()
