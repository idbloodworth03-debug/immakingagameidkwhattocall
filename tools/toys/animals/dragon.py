"""Dragon as a toy: a friendly little dragon. An emerald bean of a body on
four stubby legs, a long neck up to a big round head with two cream horns,
a golden belly and throat, orange spikes down its neck, back and tail, a
spade on the tip of its tail, and bat wings of pale green skin stretched
over dark fingers.
"""
import numpy as np
from kit import Design, both, but, either, facing, part, side

COLORS = {
    "green": "#2fa868",
    "dark": "#1f7a4a",
    "gold": "#f4d67c",
    "spike": "#f28c3b",
    "skin": "#93dfb2",
    "horn": "#fbeecb",
    "nose": "#195238",
}

WING = ("w_shoulder", "w_elbow", "w_wrist", "w_wing_tip", "w_finger2", "w_finger3")


def make():
    d = Design("dragon", COLORS, "green")
    d.shorten_wings(0.6, joints=WING)
    d.torso(rump=(0.45, 0.5, 0.45), chest=(0.45, 0.46, 0.47), rump_at=(0, 0.06, -0.06), chest_at=(0, -0.04, -0.08))
    d.neck(0.31, 0.25)
    d.head((0.48, 0.48, 0.43))
    d.muzzle(root=(0, 0.22, -0.1), base=0.3, end=0.22)
    d.jaw(0.22, 0.18)
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.09, 0.08, 0.15), k), (0.035, 0.03, 0.03)))
    # Two horns, sweeping back from its brow.
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.23, -0.1, 0.32), k)), d.p("skull", side((-0.4, -0.44, 0.74), k)), 0.11, 0.03,
                                "horn", "head", blend=0.03))
    d.legs(front=(0.18, 0.16, 0.14), hind=(0.2, 0.17, 0.14), paw=(0.18, 0.22, 0.11))
    d.tail((0.25, 0.17, 0.1, 0.06))
    # The spade on the tip of its tail.
    end, tip = d.j("tail_end"), d.j("tail_tip_end")
    along = (tip - end) / np.linalg.norm(tip - end)
    d.flat(d.p(tip, (-0.2, 0, 0)), d.p(tip, (0.2, 0, 0)), tip + along * 0.42 * d.u, 0.05, 0.06, "spade", "tail3", blend=0.04)
    # Spikes: down the back of its neck, along its back and down its tail.
    def spike(at, bone, up=(0, -0.05, 0.24), radius=0.085):
        d.stick(at, d.p(at, up), radius, 0.02, "spike", bone, blend=0.03)
    top, low = d.j("head_base"), d.j("neck_base")
    for t in (0.2, 0.5, 0.8):
        spike(d.p(top + (low - top) * t, (0, -0.24 + 0.03 * t, 0.07)), "neck", up=(0, -0.2, 0.14))
    spike(d.p("withers", (0, -0.1, 0.34)), "chest")
    spike(d.p("spine_mid", (0, 0.0, 0.42)), "chest")
    spike(d.p("pelvis", (0, 0.05, 0.38)), "hips")
    spike(d.p("tail_base", (0, -0.1, 0.22)), "tail1", radius=0.075)
    spike(d.p("tail_mid", (0, 0.0, 0.17)), "tail2", radius=0.065)
    # Wings: skin stretched from each arm and its fingers back to its hip.
    def wing(s, k):
        j = {n: d.j("w_" + n + s) for n in ("shoulder", "elbow", "wrist", "wing_tip", "finger2", "finger3", "anchor")}
        for a, b, c, bone in ((j["shoulder"], j["elbow"], j["anchor"], "wing_upper"), (j["elbow"], j["finger3"], j["anchor"], "wing_upper"),
                              (j["elbow"], j["wrist"], j["finger3"], "wing_lower"), (j["wrist"], j["finger2"], j["finger3"], "wing_hand"),
                              (j["wrist"], j["wing_tip"], j["finger2"], "wing_hand")):
            d.flat(a, b, c, 0.035, 0.05, "skin", bone + s, blend=0.03)
        d.stick(j["shoulder"], j["elbow"], 0.09, 0.075, "arm", "wing_upper" + s, blend=0.03)
        d.stick(j["elbow"], j["wrist"], 0.075, 0.06, "arm", "wing_lower" + s, blend=0.03)
        for end in ("wing_tip", "finger2", "finger3"):
            d.stick(j["wrist"], j[end], 0.06, 0.035, "arm", "wing_hand" + s, blend=0.03)
    d.pair(wing)
    d.eye(toward=(-0.55, 0.8, 0.2), radius=0.14)

    # A golden belly, chest and throat.
    d.paint("gold", both(part("torso"), facing((0, 0.6, -0.8), 0.45)))
    d.paint("gold", both(part("jaw", "muzzle"), d.below("chin", (0, 0, 0.12))))
    d.paint("skin", part("skin"))
    d.paint("dark", part("arm"))
    d.paint("spike", part("spike", "spade"))
    d.paint("horn", part("horn"))
    d.paint("horn", both(part("leg"), either(d.around("front_toe.L", (0, 0.1, -0.02), (0.18, 0.13, 0.07), mirrored=True),
                                             d.around("hind_toe.L", (0, 0.1, -0.02), (0.18, 0.13, 0.07), mirrored=True))))
    return d.toy()
