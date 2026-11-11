"""Red Fox as a toy: a small orange bean of a body on four dark stick legs,
a big wedge of a head with cheek tufts and a short white muzzle, tall ears
with dark tips, button eyes, and a plume of a tail with a white tip (the
part of a fox you see from behind).

Meters; it faces +Y with +Z up; the left side is x < 0 (the right mirrors).
"""
import numpy as np

from anatomy import Creature, quadruped_skeleton
from sdf import cone, ellipsoid, plate
from toy import Eye, Piece, Toy

COLORS = {
    "orange": "#ee7b2b",
    "white": "#fff4e4",
    "dark": "#43302c",
    "inner": "#ffd3ad",
    "nose": "#2b2024",
    "eye_white": "#ffffff",
    "pupil": "#231d26",
}

# The skeleton's joints (tools/creatures anatomy.quadruped_skeleton).
J = {
    "pelvis": (0, -0.10, 0.25), "spine_mid": (0, 0.0, 0.255), "withers": (0, 0.10, 0.27),
    "neck_base": (0, 0.115, 0.285), "head_base": (0, 0.185, 0.35), "skull": (0, 0.235, 0.40),
    "snout_tip": (0, 0.44, 0.365), "jaw_hinge": (0, 0.26, 0.355), "chin": (0, 0.40, 0.34),
    "ear_base": (-0.083, 0.205, 0.467), "ear_tip": (-0.105, 0.2, 0.655),
    "shoulder": (-0.062, 0.10, 0.175), "elbow": (-0.062, 0.10, 0.115), "wrist": (-0.062, 0.103, 0.045),
    "front_toe": (-0.062, 0.14, 0.014),
    "hip": (-0.068, -0.105, 0.175), "knee": (-0.068, -0.10, 0.115), "hock": (-0.068, -0.108, 0.045),
    "hind_toe": (-0.068, -0.072, 0.014),
    "tail_base": (0, -0.14, 0.24), "tail_mid": (0, -0.29, 0.33), "tail_end": (0, -0.43, 0.39),
}

SKULL = (0, 0.235, 0.40)
EAR_INNER, EAR_OUTER, EAR_TIP = (-0.028, 0.225, 0.485), (-0.138, 0.185, 0.45), (-0.105, 0.2, 0.655)
TAIL = [np.array(J[k], float) for k in ("tail_base", "tail_mid", "tail_end")]
TAIL_TIP = TAIL[2] + (TAIL[2] - TAIL[1]) * 0.5


def _side(p, k):
    """A left-side point (x < 0) on the left (k = 1) or mirrored to the
    right (k = -1)."""
    return (p[0] * k, p[1], p[2])


def shapes():
    out = []
    A = out.append
    # Body: one bean, deeper at the chest.
    A(ellipsoid((0, -0.005, 0.22), (0.11, 0.158, 0.11), "torso", "hips", blend=0.0))
    A(ellipsoid((0, 0.12, 0.265), (0.095, 0.10, 0.10), "torso", "chest", blend=0.07))
    # Head: a wide soft wedge, cheek tufts, a short muzzle.
    A(ellipsoid(SKULL, (0.135, 0.12, 0.112), "head", "head", blend=0.035))
    for sx in (-1, 1):
        A(cone((sx * 0.07, 0.25, 0.365), (sx * 0.172, 0.215, 0.345), 0.055, 0.012, "cheek", "head", blend=0.035))
    A(cone((0, 0.31, 0.372), (0, 0.42, 0.362), 0.062, 0.03, "muzzle", "head", blend=0.04))
    for side, k in ((".L", 1), (".R", -1)):
        # Ears: tall rounded triangles.
        A(plate(_side(EAR_INNER, k), _side(EAR_OUTER, k), _side(EAR_TIP, k), 0.018, 0.026, "ear", "ear" + side, blend=0.02))
        # Legs: sticks, with a little paw.
        x = -k * 0.062
        A(cone((x, 0.10, 0.175), (x, 0.103, 0.045), 0.036, 0.031, "leg", "fl_upper" + side, "fl_lower" + side, blend=0.012))
        A(ellipsoid((x, 0.113, 0.03), (0.034, 0.043, 0.03), "leg", "fl_foot" + side, blend=0.012))
        x = -k * 0.068
        A(cone((x, -0.105, 0.175), (x, -0.108, 0.045), 0.038, 0.031, "leg", "hl_upper" + side, "hl_lower" + side, blend=0.012))
        A(ellipsoid((x, -0.098, 0.03), (0.034, 0.043, 0.03), "leg", "hl_foot" + side, blend=0.012))
    # Tail: a plume carried up and back.
    A(cone(TAIL[0], TAIL[1], 0.05, 0.098, "tail", "tail1", "tail2", blend=0.04))
    A(cone(TAIL[1], TAIL[2], 0.098, 0.072, "tail", "tail2", "tail3", blend=0.03))
    A(cone(TAIL[2], TAIL_TIP, 0.072, 0.02, "tail", "tail3", blend=0.03))
    return out


def _triangle(s, a, b, c):
    """How far inside the triangle a-b-c each point is, seen square on to
    it (meters; below 0 outside)."""
    a, b, c = (np.asarray(p, float) for p in (a, b, c))
    n = np.cross(b - a, c - a)
    n /= np.linalg.norm(n)
    inside = np.full(len(s.v), np.inf)
    for p, q, r in ((a, b, c), (b, c, a), (c, a, b)):
        edge = np.cross(n, q - p)
        edge /= np.linalg.norm(edge)
        if (r - p) @ edge < 0:
            edge = -edge
        inside = np.minimum(inside, (s.v - p) @ edge)
    return inside


def bib(s):
    """White chest and belly."""
    return np.minimum(s.within((0, 0.13, 0.19), (0.085, 0.165, 0.135)), 0.5 - s.part("leg"))


def mask(s):
    """White lower face: the cheeks, the sides of the muzzle and the chin."""
    v = s.v
    line = 0.372 - 0.10 * np.clip(np.abs(v[:, 0]) - 0.03, 0, 1) + 0.18 * np.clip(v[:, 1] - 0.34, 0, 1)
    return np.minimum(s.part("head", "cheek", "muzzle") - 0.5, line - v[:, 2])


def tail_tip(s):
    along = TAIL[2] - TAIL[0]
    return np.minimum(s.part("tail") - 0.5, s.beyond(TAIL[0] + along * 0.66, along))


def legs(s):
    return s.part("leg") - 0.5


def _ear_side(s, k):
    """How far in front of the middle of an ear's plate each point is
    (meters; below 0 behind it), and how far inside its triangle."""
    a, b, c = _side(EAR_INNER, k), _side(EAR_OUTER, k), _side(EAR_TIP, k)
    facing = np.cross(np.subtract(b, a), np.subtract(c, a))
    facing = facing / np.linalg.norm(facing) * (1.0 if facing[1] > 0 else -1.0)
    return (s.v - np.asarray(a, float)) @ facing, _triangle(s, a, b, c)


def ear_inner(s):
    """The pale inside of each ear: its front, a smaller triangle."""
    out = np.full(len(s.v), -1.0)
    for k in (1, -1):
        front, inside = _ear_side(s, k)
        out = np.maximum(out, np.minimum(np.minimum(s.part("ear") - 0.5, front - 0.004), inside + 0.004))
    return out


def ear_backs(s):
    """Dark backs of the ears (what shows from behind)."""
    out = np.full(len(s.v), -1.0)
    for k in (1, -1):
        front, inside = _ear_side(s, k)
        near = 0.09 - np.abs(s.v[:, 0] - _side(EAR_TIP, k)[0] * 0.8)
        out = np.maximum(out, np.minimum(np.minimum(s.part("ear") - 0.5, -front - 0.002), near))
    return out


def ear_tips(s):
    return np.minimum(s.part("ear") - 0.5, s.v[:, 2] - 0.6)


def make():
    joints, bones = quadruped_skeleton(J)
    c = Creature("red_fox", joints, bones, shapes(), tiles_long=1.68)
    # It moves as the game's Red Fox does (tools/creatures motion: its trot,
    # its pounce and bite, the fox persona's idle, fidget and victory).
    c.motion = {"gait": "trot", "attack": "pounce_bite", "attack2": "bite", "weight": 0.3, "persona": "fox"}
    patches = [("white", bib), ("white", mask), ("white", tail_tip), ("dark", legs), ("inner", ear_inner), ("dark", ear_backs),
               ("dark", ear_tips)]
    eyes = [Eye(origin=SKULL, toward=(-0.6, 0.76, 0.13), radius=0.043)]
    pieces = [Piece(center=(0, 0.447, 0.368), radii=(0.027, 0.02, 0.021), color="nose")]
    return Toy("Fox", c, COLORS, "orange", patches, eyes, pieces)
