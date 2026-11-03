"""Birds from a few proportions, so each species file only says what makes
it that bird. Lays out bird() joints and sizes by scaling a big soaring
bird's layout (the condor's) and then stretching the parts that differ:

    J, R = birdkit.layout(span=1.0, neck=1.2, beak=(1.4, 1.0), hook=0.0, ...)
    c = bird("my_bird", J, R, paint=paint, tiles_long=1.4)

span: wingspan in meters. body, girth: body length and thickness. neck:
neck length. head: head size. beak: (length, depth); hook: 0 straight,
1 a raptor's hook. tail: (length, width). chord: wing width. fingers:
splayed primaries (0 for a pointed wing). legs: leg length (cranes trail
theirs).
"""
import numpy as np

from anatomy import Extra, bird
from sdf import cone, ellipsoid

BASE_J = {
    "pelvis": (0, -0.25, 0.0), "spine_mid": (0, 0.0, 0.01), "withers": (0, 0.2, 0.02),
    "neck_base": (0, 0.25, 0.03), "head_base": (0, 0.36, 0.05), "skull": (0, 0.395, 0.055),
    "beak_tip": (0, 0.49, 0.03), "jaw_hinge": (0, 0.415, 0.035), "chin": (0, 0.47, 0.022),
    "shoulder": (-0.09, 0.18, 0.04), "elbow": (-0.45, 0.15, 0.05), "wrist": (-0.85, 0.2, 0.05),
    "wing_tip": (-1.38, 0.08, 0.045), "hip": (-0.06, -0.12, -0.05), "foot": (-0.06, -0.3, -0.07),
    "tail_base": (0, -0.3, 0.0), "tail_end": (0, -0.62, 0.0),
}
BASE_R = {
    "body": (0.13, 0.32, 0.12), "body_drop": 0.01,
    "breast": (0.12, 0.15, 0.12), "breast_back": 0.05, "breast_drop": 0.03, "body_blend": 0.08,
    "neck": (0.055, 0.042), "neck_blend": 0.03,
    "skull": (0.052, 0.058, 0.048), "head_blend": 0.03,
    "beak_root": (0, 0.065, -0.014), "beak": (0.021, 0.011), "beak_blend": 0.012,
    "jaw": (0.014, 0.008),
    "chord": (0.34, 0.38, 0.37, 0.28), "wing_thick": 0.012, "wing_blend": 0.025,
    "feathers": 18, "fan": 0.6, "fingers": 5, "finger_length": 1.25, "feather_overlap": 1.7,
    "arm": (0.045, 0.032, 0.022),
    "leg": (0.02, 0.018), "leg_blend": 0.01,
    "tail_width": (0.08, 0.13), "tail_thick": 0.008, "tail_blend": 0.03,
}
BASE_SPAN = 2.76


def layout(span, body=1.0, girth=1.0, neck=1.0, head=1.0, beak=(1.0, 1.0), hook=1.0, tail=(1.0, 1.0),
           chord=1.0, fingers=5, legs=1.0, fan=0.6):
    k = span / BASE_SPAN
    J = {key: np.asarray(v, float) * k for key, v in BASE_J.items()}
    ratios = {"finger_length", "feather_overlap", "fan"}   # not sizes: these don't scale
    R = {key: (tuple(np.asarray(v, float) * k) if isinstance(v, tuple) else
               (v * k if isinstance(v, float) and key not in ratios else v))
         for key, v in BASE_R.items()}
    # Body length and girth.
    for key in ("pelvis", "tail_base", "tail_end", "hip", "foot"):
        J[key] = J[key] * np.array([1, body, 1])
    R["body"] = tuple(np.asarray(R["body"]) * np.array([girth, body, girth]))
    R["breast"] = tuple(np.asarray(R["breast"]) * girth)
    # Neck: the head and everything on it moves forward and up.
    shift = (J["head_base"] - J["neck_base"]) * (neck - 1.0)
    for key in ("head_base", "skull", "beak_tip", "jaw_hinge", "chin"):
        J[key] = J[key] + shift
    R["neck"] = tuple(np.asarray(R["neck"]) * girth ** 0.5)
    # Head size, then the beak from the skull.
    skull = J["skull"]
    for key in ("beak_tip", "jaw_hinge", "chin"):
        J[key] = skull + (J[key] - skull) * head
    R["skull"] = tuple(np.asarray(R["skull"]) * head)
    R["beak_root"] = tuple(np.asarray(R["beak_root"]) * head)
    for key in ("beak_tip", "chin"):
        J[key] = J["jaw_hinge"] + (J[key] - J["jaw_hinge"]) * beak[0]
    R["beak"] = tuple(np.asarray(R["beak"]) * head * beak[1])
    R["jaw"] = tuple(np.asarray(R["jaw"]) * head * beak[1])
    R["hook"] = hook
    # Tail.
    J["tail_end"] = J["tail_base"] + (J["tail_end"] - J["tail_base"]) * tail[0]
    R["tail_width"] = tuple(np.asarray(R["tail_width"]) * tail[1])
    # Wings and legs.
    R["chord"] = tuple(np.asarray(R["chord"]) * chord)
    R["fingers"] = fingers
    R["fan"] = fan
    J["foot"] = J["hip"] + (J["foot"] - J["hip"]) * legs
    return {key: tuple(float(x) for x in v) for key, v in J.items()}, R


def crest(c, base, tip, radius, region="crest", bone="head", blend=None):
    """A crest or plume: a tapering cone from `base` to `tip` on the head."""
    c.shapes.append(cone(np.asarray(base, float), np.asarray(tip, float), radius, radius * 0.25, region, bone,
                         blend=blend if blend is not None else radius))


def flying(c, size, flap=0.75, hover=0.5, attack="dive"):
    """The usual motion settings for a bird of wingspan `size` (meters)."""
    c.motion = {"body": "bird", "attack": attack, "altitude": 0.35 * size + 0.1, "flap": flap, "hover_power": hover,
                "cycle_tiles": 1.4}
    return c


def finish(c, R, iris="#1a0d06", eye_dir=(-0.75, 0.55, 0.3), eye=0.28, eye_line=None):
    """Eyes on the head's surface, a mesh fine enough for the wings, and a
    smooth, lightly glossy feather look."""
    from anatomy import add_face
    c.voxel = max(0.0011, R["wing_thick"] * 0.45)
    skull = R["skull"][0]
    add_face(c, eye_dir=eye_dir, eye_radius=skull * eye, eye_sink=skull * 0.1, nose_radius=0, iris=iris, pupil="round")
    c.fur = {"strands": False, "variation": 0.1, "sheen": 0.15, "bump": 0.15, "roughness": 0.65}
    if eye_line:
        c.palette = {"eye_line": eye_line, "eye_line_size": 1.45}
    return c


def masks(p, span):
    """Handy masks for painting a bird: up (facing the sky), down, and how far
    out along the wing a point is (0 at the body, 1 at the tip)."""
    up = p.smooth(p.n[:, 2], -0.1, 0.3)
    out = np.clip(np.abs(p.v[:, 0]) / (span / 2.0), 0.0, 1.0)
    return up, 1 - up, out
