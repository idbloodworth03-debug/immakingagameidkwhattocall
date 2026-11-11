"""Cerberus as a toy: a charcoal hound with three heads side by side, each
on its own neck with a red collar, fiery yellow eyes, upright ears with red
insides, a paler muzzle, and a thin tail ending in a red arrowhead.
"""
import numpy as np

from kit import Design, both, but, either, facing, part, side

COLORS = {
    "coal": "#40384a",
    "muzzle": "#75656f",
    "red": "#de3b3b",
    "inner": "#c24a52",
    "fire": "#ffd23f",
}

# Where each side head's skull is from the middle one's (the left's; the
# right mirrors), and how far it turns outward.
SIDE_HEAD = (-0.52, -0.1, -0.06)
TURN = 0.42


def make():
    d = Design("cerberus", COLORS, "coal", changes={
        "ear_base": (-0.085, 0.36, 0.835), "ear_tip": (-0.12, 0.35, 0.97),
        "tail_mid": (0, -0.53, 0.42), "tail_end": (0, -0.62, 0.33), "tail_tip_end": (0, -0.66, 0.3),
    })
    d.torso(rump=(0.32, 0.4, 0.31), chest=(0.47, 0.36, 0.38), rump_at=(0, 0.08, -0.12), chest_at=(0, -0.03, -0.1))

    def head(center, yaw, bone, name):
        """One head: its neck, collar, skull, muzzle, nose and ears, turned
        `yaw` outward (to the animal's left when above 0)."""
        turn = np.array([[np.cos(yaw), -np.sin(yaw), 0], [np.sin(yaw), np.cos(yaw), 0], [0, 0, 1]])
        at = lambda off: center + (turn @ np.asarray(off, float)) * d.u
        base = d.p("neck_base", (center[0] - d.j("skull")[0], 0, 0)) * np.array([0.55, 1, 1]) + np.array([0, 0, 0.02 * d.u])
        d.stick(base, at((0, -0.12, -0.12)), 0.26, 0.22, "torso", "neck" if bone == "neck" else "neck", blend=0.14)
        top = at((0, -0.12, -0.12))
        d.stick(base + (top - base) * 0.62, base + (top - base) * 0.8, 0.3, 0.29, "collar", "neck", blend=0.0)
        d.blob(at((0, 0, 0)), (0.3, 0.29, 0.27), name, bone, blend=0.08, yaw=yaw)
        d.stick(at((0, 0.16, -0.07)), at((0, 0.46, -0.11)), 0.17, 0.11, name + "_muzzle", bone, blend=0.1)
        d.nose(at((0, 0.52, -0.09)), (0, 0, 0), (0.075, 0.055, 0.055), bone=bone)
        for k in (1, -1):
            a, b, tip = at((-0.2 * k, 0.0, 0.2)), at((-0.05 * k, 0.03, 0.26)), at((-0.17 * k, -0.02, 0.5))
            d.flat(a, b, tip, 0.045, 0.06, name + "_ear", bone if bone == "neck" else "ear" + (".L" if k == 1 else ".R"), blend=0.05)
            d._ears.append((a, b, tip))

    skull = d.j("skull")
    head(skull, 0.0, "head", "head")
    for k in (1, -1):
        head(skull + side(SIDE_HEAD, k) * d.u, TURN * k, "neck", "side")
    d.legs(front=(0.15, 0.135, 0.12), hind=(0.16, 0.14, 0.12), paw=(0.14, 0.17, 0.105))
    d.tail((0.08, 0.065, 0.055, 0.05))
    end = d.j("tail_tip_end")
    d.flat(end + np.array([-0.1, 0.02, 0]) * d.u, end + np.array([0.1, 0.02, 0]) * d.u, end + np.array([0, -0.26, -0.1]) * d.u,
           0.035, 0.04, "arrow", "tail3", blend=0.02)
    # Fiery eyes: the middle head's, then each side head's outer and inner eye.
    d.eye(toward=(-0.5, 0.84, 0.16), radius=0.085, white="fire")
    left = skull + side(SIDE_HEAD, 1) * d.u
    for toward in ((-0.78, 0.6, 0.16), (0.12, 0.98, 0.16)):
        d.eye(toward=toward, radius=0.085, origin=left, white="fire", bone="neck")

    d.paint("muzzle", part("head_muzzle", "side_muzzle"))
    d.paint("muzzle", both(part("torso"), facing((0, 0, -1), 0.45)))
    d.paint("red", part("collar", "arrow"))
    d.paint("inner", d.ear_fronts(part_name="head_ear"))
    d.paint("inner", d.ear_fronts(part_name="side_ear"))
    return d.toy()
