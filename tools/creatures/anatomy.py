"""A creature: joints, bones, the shapes that make its body, small extra parts
(eyes, nose, claws...), its colors and how it moves.

Species files fill one of these in. Four-legged animals start from
`quadruped()`, which lays out the usual skeleton (spine, neck, head with a
jaw, ears, three-segment legs, tail) from a handful of joint positions.
"""
from dataclasses import dataclass, field

import numpy as np

from sdf import cone, ellipsoid, plate


@dataclass
class Bone:
    name: str
    head: str           # joint name
    tail: str           # joint name
    parent: str = None
    # Which way the bone's Z axis should point (wings use "up", so that a
    # positive X rotation raises either wing). None: the usual roll.
    up: tuple = None


@dataclass
class Extra:
    """A separate little mesh, like an eye or a claw, stuck to one bone."""
    kind: str           # "sphere", "cone" or "ellipsoid"
    material: str       # "eye", "nose", "claw", "horn", "tusk", "fur"...
    bone: str
    center: tuple = (0, 0, 0)
    radius: float = 0.01
    radii: tuple = None
    tip: tuple = None   # cone: the far end
    tip_radius: float = 0.0
    color: tuple = None
    rot: tuple = (0.0, 0.0, 0.0)
    # Sphere/ellipsoid: which way its +Z (the pupil) faces, in creature space.
    direction: tuple = None


@dataclass
class Creature:
    name: str
    joints: dict
    bones: list
    shapes: list
    extras: list = field(default_factory=list)
    # body part -> color, plus anything the species' paint() wants
    palette: dict = field(default_factory=dict)
    paint: object = None          # function(mesh, creature) -> N x 3 linear colors
    fur: dict = field(default_factory=dict)
    motion: dict = field(default_factory=dict)
    # How long the animal should look in battle, in tiles (nose to rump).
    tiles_long: float = 1.4
    voxel: float = 0.006
    # Small detailed pieces meshed on their own, finer grid and stuck to one
    # bone: {"shapes": [...], "voxel": 0.002, "bone": "ear.L"}
    parts: list = field(default_factory=list)
    eyes: list = field(default_factory=list)     # (center, radius), set by add_face
    nose: tuple = None

    def joint(self, name):
        return np.asarray(self.joints[name], float)


def add_face(creature, eye_dir, eye_radius, eye_sink, nose_radius, nose_sink=0.004, eye_material="eye",
             eye_squash=(1.0, 0.7, 0.75), iris="#c98a2a", pupil="slit"):
    """Puts eyes and a nose on the head's actual surface. `eye_dir` points
    from the skull center toward the left eye (x < 0); the right eye mirrors
    it. Eyes are slightly flattened balls turned to look outward, with an
    iris and pupil painted on (see scene.py)."""
    from sdf import surface_point
    skull = creature.joint("skull")
    creature.eyes = []
    for sign in (1, -1):
        d = np.array([eye_dir[0] * sign, eye_dir[1], eye_dir[2]])
        d /= np.linalg.norm(d)
        p = surface_point(creature.shapes, skull, d, sink=eye_sink)
        radii = tuple(eye_radius * k for k in eye_squash)
        creature.extras.append(Extra("ellipsoid", eye_material, "head", center=tuple(p), radii=radii,
                                     direction=tuple(d), color=iris, rot=(0.0, 0.0, 0.0)))
        creature.extras[-1].pupil = pupil
        creature.eyes.append((p, eye_radius))
    if nose_radius <= 0 or "snout_tip" not in creature.joints:
        return
    tip = creature.joint("snout_tip")
    toward = tip - skull
    nose = surface_point(creature.shapes, skull, toward, sink=nose_sink)
    creature.extras.append(Extra("ellipsoid", "nose", "head", center=tuple(nose),
                                 radii=(nose_radius * 1.15, nose_radius * 0.8, nose_radius * 0.75), direction=tuple(toward / np.linalg.norm(toward))))
    creature.nose = (nose, nose_radius)


def mirror(point):
    x, y, z = point
    return (-x, y, z)


def quadruped(name, j, r, **extra):
    """Standard four-legged body.

    `j` holds joint positions for the animal's LEFT side (x < 0) and the
    midline; the right side is mirrored. `r` holds radii. Required joints:
      pelvis, spine_mid, withers, neck_base, head_base, skull, snout_tip,
      jaw_hinge, chin, ear_base, ear_tip,
      shoulder, elbow, wrist, front_toe,
      hip, knee, hock, hind_toe,
      tail_base, tail_mid, tail_end
    """
    joints = {}
    for key, value in j.items():
        if key in SIDED:
            joints[key + ".L"] = value
            joints[key + ".R"] = mirror(value)
        else:
            joints[key] = value
    pelvis = np.asarray(j["pelvis"], float)
    joints["root"] = (0.0, (j["pelvis"][1] + j["withers"][1]) / 2, 0.0)
    joints["root_tip"] = (0.0, joints["root"][1] + 0.1, 0.0)
    joints["tail_tip_end"] = tuple(np.asarray(j["tail_end"]) + (np.asarray(j["tail_end"]) - np.asarray(j["tail_mid"])) * 0.3)

    bones = [
        Bone("root", "root", "root_tip"),
        Bone("hips", "pelvis", "spine_mid", "root"),
        Bone("chest", "spine_mid", "withers", "hips"),
        Bone("neck", "neck_base", "head_base", "chest"),
        Bone("head", "head_base", "snout_tip", "neck"),
        Bone("jaw", "jaw_hinge", "chin", "head"),
        Bone("tail1", "tail_base", "tail_mid", "hips"),
        Bone("tail2", "tail_mid", "tail_end", "tail1"),
        Bone("tail3", "tail_end", "tail_tip_end", "tail2"),
    ]
    for side in (".L", ".R"):
        bones += [
            Bone("ear" + side, "ear_base" + side, "ear_tip" + side, "head"),
            Bone("fl_upper" + side, "shoulder" + side, "elbow" + side, "chest"),
            Bone("fl_lower" + side, "elbow" + side, "wrist" + side, "fl_upper" + side),
            Bone("fl_foot" + side, "wrist" + side, "front_toe" + side, "fl_lower" + side),
            Bone("hl_upper" + side, "hip" + side, "knee" + side, "hips"),
            Bone("hl_lower" + side, "knee" + side, "hock" + side, "hl_upper" + side),
            Bone("hl_foot" + side, "hock" + side, "hind_toe" + side, "hl_lower" + side),
        ]

    P = lambda key: np.asarray(joints[key], float)
    shapes = []
    # Torso: rump, belly and chest, each a little deeper toward the front.
    shapes.append(ellipsoid(P("pelvis") + (0, -r["rump_back"], -r["rump_drop"]), r["rump"], "torso", "hips", blend=0.0))
    shapes.append(ellipsoid(P("spine_mid") + (0, 0, -r["belly_drop"]), r["belly"], "torso", "hips", blend=r["torso_blend"]))
    shapes.append(ellipsoid(P("withers") + (0, -r["chest_back"], -r["chest_drop"]), r["chest"], "torso", "chest", blend=r["torso_blend"]))
    # Neck and head.
    shapes.append(cone(P("neck_base"), P("head_base"), r["neck_base"], r["neck_top"], "neck", "neck", "head", blend=r["neck_blend"]))
    shapes.append(ellipsoid(P("skull"), r["skull"], "head", "head", blend=r["head_blend"], pitch=r.get("skull_pitch", 0.0)))
    snout_root = P("skull") + np.asarray(r["snout_root"])
    shapes.append(cone(snout_root, P("snout_tip"), r["snout_base"], r["snout_end"], "snout", "head", blend=r["snout_blend"]))
    shapes.append(cone(P("jaw_hinge"), P("chin"), r["jaw_base"], r["jaw_end"], "jaw", "jaw", blend=r["jaw_blend"]))
    for side, sx in ((".L", 1), (".R", -1)):
        # Legs: upper, lower and foot, thick at the top.
        shapes.append(ellipsoid(P("shoulder" + side) + (0, 0.0, r["scapula_up"]), r["scapula"], "shoulder", "fl_upper" + side,
                                blend=r["limb_blend"], pitch=r.get("scapula_pitch", 0.0)))
        shapes.append(cone(P("shoulder" + side), P("elbow" + side), r["upper_arm"][0], r["upper_arm"][1], "front_upper", "fl_upper" + side, blend=r["limb_blend"]))
        shapes.append(cone(P("elbow" + side), P("wrist" + side), r["forearm"][0], r["forearm"][1], "front_lower", "fl_lower" + side, blend=r["joint_blend"]))
        shapes.append(cone(P("wrist" + side), P("front_toe" + side), r["front_paw"][0], r["front_paw"][1], "front_paw", "fl_foot" + side, blend=r["joint_blend"]))
        shapes.append(ellipsoid(P("hip" + side) + (0, -0.01, -r["thigh_drop"]), r["thigh"], "thigh", "hl_upper" + side, blend=r["limb_blend"],
                                pitch=r.get("thigh_pitch", 0.0)))
        shapes.append(cone(P("hip" + side), P("knee" + side), r["upper_leg"][0], r["upper_leg"][1], "thigh", "hl_upper" + side, blend=r["limb_blend"]))
        shapes.append(cone(P("knee" + side), P("hock" + side), r["shin"][0], r["shin"][1], "hind_lower", "hl_lower" + side, blend=r["joint_blend"]))
        shapes.append(cone(P("hock" + side), P("hind_toe" + side), r["hind_paw"][0], r["hind_paw"][1], "hind_paw", "hl_foot" + side, blend=r["joint_blend"]))
    # Tail.
    shapes.append(cone(P("tail_base"), P("tail_mid"), r["tail"][0], r["tail"][1], "tail", "tail1", "tail2", blend=r["tail_blend"]))
    shapes.append(cone(P("tail_mid"), P("tail_end"), r["tail"][1], r["tail"][2], "tail", "tail2", "tail3", blend=r["tail_blend"]))
    if len(r["tail"]) > 3:
        shapes.append(cone(P("tail_end"), P("tail_tip_end"), r["tail"][2], r["tail"][3], "tail_tip", "tail3", blend=r["tail_blend"]))

    creature = Creature(name, joints, bones, shapes, **extra)
    for side in (".L", ".R"):
        creature.parts.append(ear_part(P("ear_base" + side), P("ear_tip" + side), r, side))
    return creature


def ear_part(base, tip, r, side):
    """A triangular ear with a cupped front, as its own finely meshed part.
    r["ear_width"]: base width, r["ear_thick"]: half thickness,
    r["ear_yaw"]: how far the opening turns outward (radians)."""
    width = r["ear_width"]
    sign = -1.0 if side == ".L" else 1.0          # outward
    yaw = r.get("ear_yaw", 0.35)
    across = np.array([np.cos(yaw), -np.sin(yaw) * sign, 0.0]) * sign   # inner -> outer along the base
    inner = base - across * width / 2
    outer = base + across * width / 2
    # Sink the base into the head so there is no gap.
    sink = np.array([0, 0, -r.get("ear_sink", 0.012)])
    thick = r["ear_thick"]
    rounding = r.get("ear_round", thick * 0.6)
    if rounding > thick:
        # Round ears: shrink the triangle toward its middle by the rounding
        # so the rounded shape keeps the intended size.
        mid = (inner + outer + tip) / 3
        pull = lambda q: mid + (q - mid) * max(0.2, 1 - rounding / max(np.linalg.norm(q - mid), 1e-6))
        inner, outer, tip = pull(inner), pull(outer), pull(tip)
    shapes = [plate(inner + sink, outer + sink, tip, thick, rounding, "ear", "ear" + side, blend=0.0)]
    # The cup: a smaller triangle pushed in from the front.
    center = (inner + outer + tip) / 3
    shrink = lambda q: center + (q - center) * 0.68
    facing = np.array([np.sin(yaw) * sign, np.cos(yaw), 0.0])
    cup_offset = facing * thick * 1.7 + np.array([0, 0, -0.1 * np.linalg.norm(tip - base)])
    shapes.append(plate(shrink(inner) + cup_offset, shrink(outer) + cup_offset, shrink(tip) + cup_offset + facing * thick * 0.4,
                        thick, thick * 0.3, "ear_inner", "ear" + side, blend=thick * 2.0, subtract=True))
    # Short fur on the ears, combed toward the tip.
    up = (tip - base) / np.linalg.norm(tip - base)
    ear_fur = {"lengths": {"ear": 1.0}, "length": r.get("ear_fur", 0.008), "comb": tuple(up * 0.8),
               "lift": 0.35, "density": 90000, "peak": 1.0}
    return {"shapes": shapes, "voxel": r.get("ear_voxel", 0.002), "bone": "ear" + side, "fur": ear_fur}


def bird(name, j, r, **extra):
    """A bird in flight, wings spread. `j` holds the LEFT side (x < 0) and
    midline joints: pelvis, spine_mid, withers, neck_base, head_base, skull,
    beak_tip, jaw_hinge, chin, shoulder, elbow, wrist, wing_tip, hip, foot,
    tail_base, tail_end. `r` holds sizes; wing chords say how wide the wing
    is (front to back) at the shoulder, elbow, wrist and tip."""
    joints = {}
    for key, value in j.items():
        if key in BIRD_SIDED:
            joints[key + ".L"] = value
            joints[key + ".R"] = mirror(value)
        else:
            joints[key] = value
    joints["root"] = (0.0, (j["pelvis"][1] + j["withers"][1]) / 2, 0.0)
    joints["root_tip"] = (0.0, joints["root"][1] + 0.1, 0.0)
    bones = [
        Bone("root", "root", "root_tip"),
        Bone("hips", "pelvis", "spine_mid", "root"),
        Bone("chest", "spine_mid", "withers", "hips"),
        Bone("neck", "neck_base", "head_base", "chest"),
        Bone("head", "head_base", "beak_tip", "neck"),
        Bone("jaw", "jaw_hinge", "chin", "head"),
        Bone("tail1", "tail_base", "tail_end", "hips"),
    ]
    for side in (".L", ".R"):
        bones += [
            Bone("wing_upper" + side, "shoulder" + side, "elbow" + side, "chest", up=(0, 0, 1)),
            Bone("wing_lower" + side, "elbow" + side, "wrist" + side, "wing_upper" + side, up=(0, 0, 1)),
            Bone("wing_hand" + side, "wrist" + side, "wing_tip" + side, "wing_lower" + side, up=(0, 0, 1)),
            Bone("leg" + side, "hip" + side, "foot" + side, "hips"),
        ]
    P = lambda key: np.asarray(joints[key], float)
    shapes = [
        ellipsoid((P("pelvis") + P("withers")) / 2 + (0, 0, -r["body_drop"]), r["body"], "torso", "hips", blend=0.0,
                  pitch=r.get("body_pitch", 0.0)),
        ellipsoid(P("withers") + (0, -r["breast_back"], -r["breast_drop"]), r["breast"], "breast", "chest", blend=r["body_blend"]),
        cone(P("neck_base"), P("head_base"), r["neck"][0], r["neck"][1], "neck", "neck", "head", blend=r["neck_blend"]),
        ellipsoid(P("skull"), r["skull"], "head", "head", blend=r["head_blend"]),
        cone(P("skull") + np.asarray(r["beak_root"]), P("beak_tip"), r["beak"][0], r["beak"][1], "beak", "head", blend=r["beak_blend"]),
        cone(P("jaw_hinge"), P("chin"), r["jaw"][0], r["jaw"][1], "beak", "jaw", blend=r["beak_blend"] * 0.5),
    ]
    # Hooked tip of the beak.
    hook = P("beak_tip") + np.array([0, -r["beak"][1] * 0.6, -r["beak"][1] * 2.6])
    shapes.append(cone(P("beak_tip"), hook, r["beak"][1], r["beak"][1] * 0.4, "beak", "head", blend=0.002))
    for side, sx in ((".L", 1), (".R", -1)):
        lead = [P("shoulder" + side), P("elbow" + side), P("wrist" + side), P("wing_tip" + side)]
        names = ["wing_upper" + side, "wing_lower" + side, "wing_hand" + side]
        shapes += _wing_feathers(lead, names, r, sx)
        # The arm inside the leading edge.
        shapes.append(cone(lead[0], lead[1], r["arm"][0], r["arm"][1], "wing", names[0], names[1], blend=r["wing_blend"]))
        shapes.append(cone(lead[1], lead[2], r["arm"][1], r["arm"][2], "wing", names[1], names[2], blend=r["wing_blend"]))
        shapes.append(cone(lead[2], lead[3], r["arm"][2], r["arm"][2] * 0.4, "wing", names[2], blend=r["wing_blend"]))
        # Tucked legs and feet.
        shapes.append(cone(P("hip" + side), P("foot" + side), r["leg"][0], r["leg"][1], "leg", "leg" + side, blend=r["leg_blend"]))
    # Tail fan.
    tb, te = P("tail_base"), P("tail_end")
    half = r["tail_width"]
    left_base, right_base = tb + (-half[0], 0, 0), tb + (half[0], 0, 0)
    left_end, right_end = te + (-half[1], 0, 0), te + (half[1], 0, 0)
    tt = r["tail_thick"]
    shapes.append(plate(left_base, right_base, right_end, tt, tt, "tail", "tail1", blend=r["tail_blend"]))
    shapes.append(plate(left_base, right_end, left_end, tt, tt, "tail", "tail1", blend=r["tail_blend"]))
    extra.setdefault("motion", {})
    creature = Creature(name, joints, bones, shapes, **extra)
    creature.motion.setdefault("body", "bird")
    return creature


def _wing_feathers(lead, names, r, sx):
    """A wing as a row of long feather blades along its leading edge. Near
    the body they point straight back; toward the tip they fan outward, and
    the last few (the primaries) can splay apart like fingers."""
    lengths = np.concatenate([[0], np.cumsum([np.linalg.norm(lead[i + 1] - lead[i]) for i in range(3)])])
    total = lengths[-1]
    count = int(r.get("feathers", 16))
    chord = r["chord"]
    shapes = []
    for k in range(count):
        u = (k + 0.5) / count
        along = u * total
        seg = min(int(np.searchsorted(lengths, along, side="right") - 1), 2)
        local = (along - lengths[seg]) / max(lengths[seg + 1] - lengths[seg], 1e-9)
        base = lead[seg] + (lead[seg + 1] - lead[seg]) * local
        span_dir = (lead[seg + 1] - lead[seg]) / np.linalg.norm(lead[seg + 1] - lead[seg])
        length = float(np.interp(along, lengths, chord))
        # Fan outward toward the tip.
        fan = r.get("fan", 0.9) * max(0.0, u - 0.45) / 0.55
        direction = np.array([0, -1.0, 0]) * (1 - fan) + span_dir * fan
        direction /= np.linalg.norm(direction)
        primaries = r.get("fingers", 0)
        if primaries and k >= count - primaries:
            length *= r.get("finger_length", 1.4)
        width = total / count * r.get("feather_overlap", 1.9)
        half = span_dir * width / 2
        tip = base + direction * length + np.array([0, 0, -0.002])
        thick = r["wing_thick"] * (1 - 0.35 * u)
        rounding = width * (0.35 if primaries and k >= count - primaries else 0.2)
        shapes.append(plate(base - half, base + half, tip, thick, rounding, "wing", names[seg], blend=r["wing_blend"]))
    return shapes


BIRD_SIDED = {"shoulder", "elbow", "wrist", "wing_tip", "hip", "foot"}

SIDED = {"ear_base", "ear_tip", "shoulder", "elbow", "wrist", "front_toe", "hip", "knee", "hock", "hind_toe", "eye"}
