"""Dragon as a toy: a friendly little dragon. A chubby emerald body on
four stubby legs, a short neck up to a big round head with two cream
horns, a golden belly and throat, orange spikes down its neck, back and
tail, a spade on the tip of its tail, and small bat wings of pale green
skin stretched over dark fingers.
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
    # A toy dragon's neck and tail are short and its wings small: its head comes down toward its shoulders, its
    # tail's joints come in toward its root, and its wings' toward their shoulders.
    d.move(["head_base", "skull", "snout_tip", "jaw_hinge", "chin"], (0, -0.05, -0.5))
    root = d.j("tail_base")
    for name in ("tail_mid", "tail_end", "tail_tip_end"):
        d.c.joints[name] = tuple(root + (d.j(name) - root) * 0.7)
    d.shorten_wings(0.45, joints=WING)
    d.torso(rump=(0.5, 0.54, 0.5), chest=(0.48, 0.48, 0.5), rump_at=(0, 0.08, -0.06), chest_at=(0, -0.04, -0.06))
    d.neck(0.35, 0.31)
    d.head((0.58, 0.56, 0.52))
    d.muzzle(root=(0, 0.26, -0.12), base=0.36, end=0.27, tip=(0, 0.14, -0.04))
    d.jaw(0.26, 0.21, tip=(0, 0.14, -0.04))
    d.pair(lambda s, k: d.nose("snout_tip", side((-0.11, 0.26, 0.17), k), (0.045, 0.035, 0.035)))
    # Two horns, sweeping back from its brow.
    d.pair(lambda s, k: d.stick(d.p("skull", side((-0.28, -0.12, 0.4), k)), d.p("skull", side((-0.5, -0.52, 0.94), k)), 0.13, 0.035,
                                "horn", "head", blend=0.03))
    d.legs(front=(0.21, 0.19, 0.17), hind=(0.23, 0.2, 0.17), paw=(0.2, 0.24, 0.12))
    d.tail((0.3, 0.21, 0.13, 0.08))
    # The spade on the tip of its tail.
    end, tip = d.j("tail_end"), d.j("tail_tip_end")
    along = (tip - end) / np.linalg.norm(tip - end)
    d.flat(d.p(tip, (-0.26, 0, 0)), d.p(tip, (0.26, 0, 0)), tip + along * 0.5 * d.u, 0.06, 0.07, "spade", "tail3", blend=0.04)

    # Spikes: down the back of its neck, along its back and down its tail.
    def spike(at, bone, up=(0, -0.06, 0.3), radius=0.11):
        d.stick(at, d.p(at, up), radius, 0.025, "spike", bone, blend=0.03)
    top, low = d.j("head_base"), d.j("neck_base")
    for t in (0.25, 0.7):
        spike(d.p(top + (low - top) * t, (0, -0.33 + 0.04 * t, 0.06)), "neck", up=(0, -0.24, 0.18))
    spike(d.p("withers", (0, -0.1, 0.42)), "chest")
    spike(d.p("spine_mid", (0, 0.0, 0.5)), "chest")
    spike(d.p("pelvis", (0, 0.05, 0.42)), "hips")
    spike(d.p("tail_base", (0, -0.12, 0.26)), "tail1", radius=0.095)
    spike(d.p("tail_mid", (0, 0.0, 0.2)), "tail2", radius=0.08)

    # Wings: skin stretched from each arm and its fingers back to its hip.
    def wing(s, k):
        j = {n: d.j("w_" + n + s) for n in ("shoulder", "elbow", "wrist", "wing_tip", "finger2", "finger3", "anchor")}
        for a, b, c, bone in ((j["shoulder"], j["elbow"], j["anchor"], "wing_upper"), (j["elbow"], j["finger3"], j["anchor"], "wing_upper"),
                              (j["elbow"], j["wrist"], j["finger3"], "wing_lower"), (j["wrist"], j["finger2"], j["finger3"], "wing_hand"),
                              (j["wrist"], j["wing_tip"], j["finger2"], "wing_hand")):
            d.flat(a, b, c, 0.045, 0.06, "skin", bone + s, blend=0.03)
        d.stick(j["shoulder"], j["elbow"], 0.11, 0.09, "arm", "wing_upper" + s, blend=0.03)
        d.stick(j["elbow"], j["wrist"], 0.09, 0.075, "arm", "wing_lower" + s, blend=0.03)
        for end in ("wing_tip", "finger2", "finger3"):
            d.stick(j["wrist"], j[end], 0.075, 0.045, "arm", "wing_hand" + s, blend=0.03)
    d.pair(wing)
    d.eye(toward=(-0.52, 0.82, 0.18), radius=0.16)

    # A golden belly, chest and throat.
    d.paint("gold", both(part("torso"), facing((0, 0.6, -0.8), 0.45)))
    d.paint("gold", both(part("jaw", "muzzle"), d.below("chin", (0, 0, 0.14))))
    d.paint("skin", part("skin"))
    d.paint("dark", part("arm"))
    d.paint("spike", part("spike", "spade"))
    d.paint("horn", part("horn"))
    d.paint("horn", both(part("leg"), either(d.around("front_toe.L", (0, 0.12, -0.02), (0.22, 0.15, 0.08), mirrored=True),
                                             d.around("hind_toe.L", (0, 0.12, -0.02), (0.22, 0.15, 0.08), mirrored=True))))
    return d.toy()
