"""Electric Eel as a toy: a fat grey-green sausage of a fish lying in
bends on the ground, orange along its underside and all over its chin, a
big blunt head with a wide mouth and big eyes, a little fin behind each
cheek, and a row of yellow sparks down its back.
"""
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "body": "#5f6a5b",
    "belly": "#f6a03f",
    "spark": "#ffe55e",
    "fin": "#454d44",
    "mouth": "#7b333a",
}

SPARKS = ("tail_mid", "tail_base", "pelvis", "spine_mid", "withers", "head_base")


def make():
    # (No withers to measure by: its sizes are in tenths of a meter. A toy eel is fat: its joints sit a little
    # higher, so its thicker body still rests on the ground.)
    d = Design("electric_eel", COLORS, "body", unit=0.1, changes={
        "tail_end": (0.1, -0.38, 0.018), "tail_mid": (-0.13, -0.3, 0.036), "tail_base": (0.11, -0.17, 0.05),
        "pelvis": (-0.09, -0.04, 0.058), "spine_mid": (0.06, 0.07, 0.06), "withers": (-0.03, 0.15, 0.06),
        "neck_base": (0, 0.2, 0.06), "head_base": (0, 0.24, 0.06), "skull": (0, 0.3, 0.072), "snout_tip": (0, 0.4, 0.056),
        "jaw_hinge": (0, 0.3, 0.03), "chin": (0, 0.39, 0.022),
    })
    # Its body: one rope from the tip of its tail to its head, curving through its bends.
    d.rope(("tail_end", "tail_mid", "tail_base", "pelvis", "spine_mid", "withers", "neck_base", "head_base"),
           (0.16, 0.36, 0.5, 0.58, 0.6, 0.6, 0.6, 0.58), ("tail3", "tail2", "tail1", "hips", "chest", "neck", "neck2", "head"), "body")
    d.head((0.84, 0.88, 0.62))
    d.muzzle(root=(0, 0.4, -0.04), base=0.62, end=0.46)
    d.jaw(0.46, 0.38)
    # A little fin behind each cheek.
    d.pair(lambda s, k: d.blob(d.p("head_base", side((-0.74, -0.1, -0.12), k)), (0.38, 0.28, 0.09), "fin", "neck2", blend=0.05))
    d.eye(toward=(-0.5, 0.66, 0.56), radius=0.2)

    whole = part("body", "head", "muzzle")
    d.paint("belly", both(whole, facing((0, 0, -1), 0.1)))
    d.paint("belly", part("jaw"))
    d.paint("spark", both(part("body"), facing((0, 0, 1), 0.3), either(*[d.around(j, (0, 0, 0.45), (0.26, 0.26, 0.4)) for j in SPARKS])))
    d.paint("fin", part("fin"))
    d.paint("mouth", both(d.mouth_line(0.08), d.ahead("skull", (0, 0.4, 0))))
    return d.toy()
