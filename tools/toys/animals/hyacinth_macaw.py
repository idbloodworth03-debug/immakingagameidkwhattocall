"""Hyacinth Macaw as a toy: a round cobalt-blue body with a big head held
high, a bright yellow ring round each eye and a yellow patch beside its
great dark hooked beak, stubby wings with deeper blue flight feathers, a
long pointed tail, and grey feet dangling under it.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "blue": "#3158dc",
    "deep": "#2443ab",
    "yellow": "#ffd43f",
    "beak": "#33363e",
    "foot": "#4b4e57",
}


def make():
    # (A bird has no withers to measure by: its sizes are in units of 13 cm.)
    d = Design("hyacinth_macaw", COLORS, "blue", unit=0.13)
    d.bird_stance()
    d.shorten_wings(0.34)
    # A toy's tail is shorter than the bird's, and its beak sits on its face.
    d.put("tail_end", "tail_base", (0, -1.5, 0))
    d.put("beak_tip", "skull", (0, 1.06, -0.2))
    d.put("jaw_hinge", "skull", (0, 0.56, -0.4))
    d.put("chin", "skull", (0, 0.92, -0.5))
    d.torso(rump=(0.7, 0.8, 0.68), chest=(0.78, 0.72, 0.76), rump_at=(0, 0.35, 0), chest_at=(0, -0.15, 0.05), blend=0.2)
    d.neck(0.58, 0.58)
    d.head((0.94, 0.8, 0.88))
    # A parrot's beak: big, deep and strongly hooked.
    d.beak(root=(0, 0.5, -0.1), base=0.4, end=0.18, hook=0.4)
    d.jaw(0.22, 0.13)
    d.wings((1.2, 1.1, 0.85), thick=0.13)
    d.flat(d.p("tail_base", (-0.42, 0.5, 0)), d.p("tail_base", (0.42, 0.5, 0)), "tail_end", 0.11, 0.12, "tail", "tail1", blend=0.08)
    d.bird_legs(0.13, (0.2, 0.24, 0.12))
    d.eye(toward=(-0.52, 0.82, 0.16), radius=0.19)

    d.paint("deep", both(part("wing"), d.behind("spine_mid", (0, 0.2, 0))))
    d.paint("deep", both(part("tail"), d.behind("tail_base", (0, -0.5, 0))))
    d.paint("beak", part("beak", "jaw"))
    # Yellow: a ring round each eye, and a patch at the root of its lower beak.
    d.paint("yellow", both(part("head"), d.around("skull", (-0.5, 0.62, 0.14), (0.36, 0.36, 0.36), mirrored=True)))
    d.paint("yellow", both(part("head"), d.around("skull", (-0.34, 0.62, -0.48), (0.2, 0.3, 0.2), mirrored=True)))
    d.paint("foot", part("foot", "leg"))
    return d.toy()
