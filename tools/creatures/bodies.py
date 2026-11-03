"""Body plans beyond four legs and birds: butterflies, fish (and whales and
dolphins, with a flat tail), shrimp, bats, and wings added to a four-legged
body (Pegasus, Griffin, Dragon). Like anatomy.py, each builder lays out
joints, bones and shapes from a handful of joint positions; species files
fill in the numbers and colors.

Coordinates match the rest of the pipeline: the animal faces +Y, +Z is up,
and joint tables hold the LEFT side (x < 0) and the midline; the right side
is mirrored.
"""
import numpy as np

from anatomy import Bone, Creature, _wing_feathers, ear_part, mirror
from sdf import cone, ellipsoid, plate


def _layout(j, sided):
    joints = {}
    for key, value in j.items():
        if key in sided:
            joints[key + ".L"] = value
            joints[key + ".R"] = mirror(value)
        else:
            joints[key] = value
    return joints


def _root(joints, a, b):
    joints["root"] = (0.0, (joints[a][1] + joints[b][1]) / 2, 0.0)
    joints["root_tip"] = (0.0, joints["root"][1] + 0.1, 0.0)


# --- Butterflies ------------------------------------------------------------------

BUTTERFLY_SIDED = {"fore_root", "fore_tip", "fore_back", "hind_root", "hind_out", "hind_back", "antenna_base", "antenna_tip"}


def butterfly(name, j, r, **extra):
    """A butterfly in flight: thorax, a long abdomen, a round head with
    clubbed antennae and four big rounded wings. Joints: spine_mid, withers,
    neck_base, head_base, skull, snout_tip, tail_base, tail_end, and per side
    fore_root/fore_tip/fore_back (forewing: root, apex, rear corner),
    hind_root/hind_out/hind_back, antenna_base/antenna_tip."""
    joints = _layout(j, BUTTERFLY_SIDED)
    _root(joints, "tail_base", "withers")
    bones = [
        Bone("root", "root", "root_tip"),
        Bone("chest", "spine_mid", "withers", "root"),
        Bone("neck", "neck_base", "head_base", "chest"),
        Bone("head", "head_base", "snout_tip", "neck"),
        Bone("tail1", "tail_base", "tail_end", "chest"),
    ]
    for side in (".L", ".R"):
        bones += [
            Bone("wing_fore" + side, "fore_root" + side, "fore_tip" + side, "chest", up=(0, 0, 1)),
            Bone("wing_hind" + side, "hind_root" + side, "hind_out" + side, "chest", up=(0, 0, 1)),
            Bone("antenna" + side, "antenna_base" + side, "antenna_tip" + side, "head"),
        ]
    P = lambda key: np.asarray(joints[key], float)
    shapes = [
        ellipsoid(P("spine_mid") + (0, 0.004, 0), r["thorax"], "torso", "chest", blend=0.0),
        cone(P("tail_base"), P("tail_end"), r["abdomen"][0], r["abdomen"][1], "abdomen", "tail1", blend=r["blend"]),
        ellipsoid(P("skull"), r["skull"], "head", "head", blend=r["blend"]),
    ]
    t, rnd = r["wing_thick"], r["wing_round"]
    for side in (".L", ".R"):
        shapes.append(plate(P("fore_root" + side), P("fore_back" + side), P("fore_tip" + side), t, rnd[0],
                            "wing_fore", "wing_fore" + side, blend=r["wing_blend"]))
        shapes.append(plate(P("hind_root" + side), P("hind_back" + side), P("hind_out" + side), t, rnd[1],
                            "wing_hind", "wing_hind" + side, blend=r["wing_blend"]))
        shapes.append(cone(P("antenna_base" + side), P("antenna_tip" + side), r["antenna"], r["antenna"] * 0.8,
                           "antenna", "antenna" + side, blend=0.002))
        shapes.append(ellipsoid(P("antenna_tip" + side), (r["club"],) * 3, "antenna", "antenna" + side, blend=0.003))
    extra.setdefault("motion", {})
    c = Creature(name, joints, bones, shapes, **extra)
    c.motion.setdefault("body", "insect")
    return c


# --- Fish, dolphins and whales -----------------------------------------------------

FISH_SIDED = {"pect_base", "pect_tip", "pect_back"}


def fish(name, j, r, fluke=False, **extra):
    """A fish lying belly-down, as a cartoon fish on land would: a deep body
    in two parts, a head with a jaw, a tail stalk and a forked tail fin
    (upright, or flat for a dolphin's or whale's fluke), a dorsal fin, an
    anal fin and two side fins. Joints: pelvis, spine_mid, withers,
    head_base, skull, snout_tip, jaw_hinge, chin, tail_base, tail_mid,
    tail_end, caudal_a and caudal_b (the two tips of the tail fin: top and
    bottom, or left and right for a fluke), dorsal_front, dorsal_back,
    dorsal_tip, and optional anal_front, anal_back, anal_tip; per side
    pect_base, pect_back, pect_tip."""
    joints = _layout(j, FISH_SIDED)
    _root(joints, "pelvis", "withers")
    joints["tail_tip_end"] = tuple((np.asarray(j["caudal_a"]) + np.asarray(j["caudal_b"])) / 2)
    bones = [
        Bone("root", "root", "root_tip"),
        Bone("hips", "pelvis", "spine_mid", "root"),
        Bone("chest", "spine_mid", "withers", "hips"),
        Bone("neck", "withers", "head_base", "chest"),
        Bone("head", "head_base", "snout_tip", "neck"),
        Bone("jaw", "jaw_hinge", "chin", "head"),
        Bone("tail1", "tail_base", "tail_mid", "hips"),
        Bone("tail2", "tail_mid", "tail_end", "tail1"),
        Bone("tail3", "tail_end", "tail_tip_end", "tail2"),
        Bone("fin_dorsal", "dorsal_front", "dorsal_tip", "chest"),
    ]
    if "anal_front" in j:
        bones.append(Bone("fin_anal", "anal_front", "anal_tip", "hips"))
    for side in (".L", ".R"):
        bones.append(Bone("pect" + side, "pect_base" + side, "pect_tip" + side, "chest"))
    P = lambda key: np.asarray(joints[key], float)
    b = r["blend"]
    shapes = [
        ellipsoid(P("spine_mid") + (0, 0, r.get("belly_drop", 0.0)), r["body"], "torso", "hips", blend=0.0),
        ellipsoid(P("withers"), r["front"], "torso", "chest", blend=b),
        ellipsoid(P("skull"), r["skull"], "head", "head", blend=b, pitch=r.get("skull_pitch", 0.0)),
        cone(P("skull") + np.asarray(r["snout_root"]), P("snout_tip"), r["snout"][0], r["snout"][1], "snout", "head", blend=r["snout_blend"]),
        cone(P("jaw_hinge"), P("chin"), r["jaw"][0], r["jaw"][1], "jaw", "jaw", blend=r["snout_blend"] * 0.6),
        cone(P("tail_base"), P("tail_mid"), r["tail"][0], r["tail"][1], "tail", "tail1", "tail2", blend=b),
        cone(P("tail_mid"), P("tail_end"), r["tail"][1], r["tail"][2], "tail", "tail2", "tail3", blend=b * 0.6),
    ]
    t, rnd, fb = r["fin_thick"], r["fin_round"], r["fin_blend"]
    end = P("tail_end")
    # The tail fin: two lobes from the end of the tail stalk.
    across = np.array([1.0, 0, 0]) if fluke else np.array([0, 0, 1.0])
    half = across * r["fin_root"]
    for tip in ("caudal_a", "caudal_b"):
        shapes.append(plate(end + half, end - half, P(tip), t, rnd, "fin", "tail3", blend=fb))
    shapes.append(plate(P("dorsal_front"), P("dorsal_back"), P("dorsal_tip"), t, rnd, "fin", "fin_dorsal", blend=fb))
    if "anal_front" in j:
        shapes.append(plate(P("anal_front"), P("anal_back"), P("anal_tip"), t, rnd, "fin", "fin_anal", blend=fb))
    for side in (".L", ".R"):
        shapes.append(plate(P("pect_base" + side), P("pect_back" + side), P("pect_tip" + side), t * r.get("pect_thick", 1.0), rnd,
                            "flipper" if fluke else "fin", "pect" + side, blend=fb))
    extra.setdefault("motion", {})
    c = Creature(name, joints, bones, shapes, **extra)
    c.motion.setdefault("body", "cetacean" if fluke else "fish")
    return c


# --- Shrimp ----------------------------------------------------------------------

SHRIMP_SIDED = {"claw_shoulder", "claw_elbow", "claw_wrist", "claw_tip", "antenna_base", "antenna_tip",
                "leg1_hip", "leg1_knee", "leg1_foot", "leg2_hip", "leg2_knee", "leg2_foot", "leg3_hip", "leg3_knee", "leg3_foot",
                "fan"}


def shrimp(name, j, r, big_claw=".R", **extra):
    """A shrimp standing on its walking legs: a smooth shell over the front
    half, a three-part tail that curls down to a tail fan, a head with a
    pointed beak and long antennae swept back, two claws (one of them huge,
    like a pistol shrimp's) and three pairs of legs. Joints: spine_mid,
    withers, head_base, skull, snout_tip, tail_base, tail_mid, tail_end,
    tail_fan; per side claw_shoulder/claw_elbow/claw_wrist/claw_tip,
    antenna_base/antenna_tip, legN_hip/legN_knee/legN_foot (N = 1-3), fan."""
    joints = _layout(j, SHRIMP_SIDED)
    _root(joints, "tail_base", "withers")
    bones = [
        Bone("root", "root", "root_tip"),
        Bone("chest", "spine_mid", "withers", "root"),
        Bone("neck", "withers", "head_base", "chest"),
        Bone("head", "head_base", "snout_tip", "neck"),
        Bone("tail1", "tail_base", "tail_mid", "chest"),
        Bone("tail2", "tail_mid", "tail_end", "tail1"),
        Bone("tail3", "tail_end", "tail_fan", "tail2"),
    ]
    for side in (".L", ".R"):
        bones += [
            Bone("antenna" + side, "antenna_base" + side, "antenna_tip" + side, "head"),
            Bone("claw_arm" + side, "claw_shoulder" + side, "claw_elbow" + side, "chest"),
            Bone("claw_hand" + side, "claw_elbow" + side, "claw_wrist" + side, "claw_arm" + side),
            Bone("claw_finger" + side, "claw_wrist" + side, "claw_tip" + side, "claw_hand" + side),
        ]
        for n in (1, 2, 3):
            bones += [
                Bone(f"leg{n}_upper{side}", f"leg{n}_hip{side}", f"leg{n}_knee{side}", "chest"),
                Bone(f"leg{n}_lower{side}", f"leg{n}_knee{side}", f"leg{n}_foot{side}", f"leg{n}_upper{side}"),
            ]
    P = lambda key: np.asarray(joints[key], float)
    b = r["blend"]
    shapes = [
        ellipsoid(P("spine_mid"), r["shell"], "torso", "chest", blend=0.0, pitch=r.get("shell_pitch", 0.0)),
        ellipsoid(P("skull"), r["skull"], "head", "head", blend=b),
        cone(P("skull") + np.asarray(r["snout_root"]), P("snout_tip"), r["snout"][0], r["snout"][1], "snout", "head", blend=b * 0.5),
    ]
    # Tail segments, smaller toward the fan.
    for i, (a_, b_, bone) in enumerate((("tail_base", "tail_mid", "tail1"), ("tail_mid", "tail_end", "tail2"), ("tail_end", "tail_fan", "tail3"))):
        mid = (P(a_) + P(b_)) / 2
        shapes.append(ellipsoid(mid, r["segments"][i], "tail", bone, blend=b, pitch=r.get("segment_pitch", (0, 0, 0))[i]))
    # The tail fan: a middle blade and one either side.
    fan_root = P("tail_fan")
    t = r["fin_thick"]
    for side in (".L", ".R"):
        shapes.append(plate(fan_root + (0, 0.01, 0), fan_root + (0, -0.005, 0), P("fan" + side), t, r["fin_round"], "fin", "tail3", blend=r["fin_blend"]))
    for side, sx in ((".L", -1), (".R", 1)):
        shapes.append(cone(P("antenna_base" + side), P("antenna_tip" + side), r["antenna"][0], r["antenna"][1], "antenna", "antenna" + side, blend=0.002))
        big = side == big_claw
        k = 1.0 if big else r["small_claw"]
        shapes.append(cone(P("claw_shoulder" + side), P("claw_elbow" + side), r["arm"] * k, r["arm"] * k * 0.9, "claw", "claw_arm" + side, blend=b * 0.5))
        palm = P("claw_elbow" + side) * 0.35 + P("claw_wrist" + side) * 0.65
        shapes.append(ellipsoid(palm, tuple(x * k for x in r["palm"]), "claw", "claw_hand" + side, blend=b * 0.6))
        shapes.append(cone(P("claw_wrist" + side) + np.asarray(r["finger_root"]) * k, P("claw_tip" + side), r["finger"][0] * k, r["finger"][1] * k,
                           "claw", "claw_finger" + side, blend=b * 0.3))
        # The fixed lower jaw of the claw, under the moving finger.
        shapes.append(cone(P("claw_wrist" + side) - np.asarray(r["finger_root"]) * k, P("claw_tip" + side) + np.array([0, -0.01, -0.012]) * k,
                           r["finger"][0] * k, r["finger"][1] * k, "claw", "claw_hand" + side, blend=b * 0.3))
        for n in (1, 2, 3):
            shapes.append(cone(P(f"leg{n}_hip{side}"), P(f"leg{n}_knee{side}"), r["leg"][0], r["leg"][1], "leg", f"leg{n}_upper{side}", blend=0.003))
            shapes.append(cone(P(f"leg{n}_knee{side}"), P(f"leg{n}_foot{side}"), r["leg"][1], r["leg"][2], "leg", f"leg{n}_lower{side}", blend=0.003))
    extra.setdefault("motion", {})
    c = Creature(name, joints, bones, shapes, **extra)
    c.motion.setdefault("body", "crustacean")
    return c


# --- Bats --------------------------------------------------------------------------

BAT_SIDED = {"shoulder", "elbow", "wrist", "wing_tip", "finger2", "finger3", "hip", "foot", "ear_base", "ear_tip"}


def bat(name, j, r, **extra):
    """A bat in flight: a furry body and a fox-like head with ears, and wings
    of skin stretched between long fingers, arm and leg. Joints like
    bird() plus snout_tip, ear_base/ear_tip and, per side, finger2 and
    finger3 (the fingers behind the wing tip, which hold the trailing
    edge)."""
    joints = _layout(j, BAT_SIDED)
    _root(joints, "pelvis", "withers")
    bones = [
        Bone("root", "root", "root_tip"),
        Bone("hips", "pelvis", "spine_mid", "root"),
        Bone("chest", "spine_mid", "withers", "hips"),
        Bone("neck", "neck_base", "head_base", "chest"),
        Bone("head", "head_base", "snout_tip", "neck"),
        Bone("jaw", "jaw_hinge", "chin", "head"),
    ]
    for side in (".L", ".R"):
        bones += [
            Bone("wing_upper" + side, "shoulder" + side, "elbow" + side, "chest", up=(0, 0, 1)),
            Bone("wing_lower" + side, "elbow" + side, "wrist" + side, "wing_upper" + side, up=(0, 0, 1)),
            Bone("wing_hand" + side, "wrist" + side, "wing_tip" + side, "wing_lower" + side, up=(0, 0, 1)),
            Bone("leg" + side, "hip" + side, "foot" + side, "hips"),
            Bone("ear" + side, "ear_base" + side, "ear_tip" + side, "head"),
        ]
    P = lambda key: np.asarray(joints[key], float)
    b = r["blend"]
    shapes = [
        ellipsoid((P("pelvis") + P("withers")) / 2, r["body"], "torso", "hips", blend=0.0),
        ellipsoid(P("withers") + (0, -0.01, 0.0), r["chest"], "torso", "chest", blend=b),
        cone(P("neck_base"), P("head_base"), r["neck"][0], r["neck"][1], "neck", "neck", "head", blend=b),
        ellipsoid(P("skull"), r["skull"], "head", "head", blend=b),
        cone(P("skull") + np.asarray(r["snout_root"]), P("snout_tip"), r["snout"][0], r["snout"][1], "snout", "head", blend=r["snout_blend"]),
        cone(P("jaw_hinge"), P("chin"), r["jaw"][0], r["jaw"][1], "jaw", "jaw", blend=r["snout_blend"] * 0.5),
    ]
    t = r["wing_thick"]
    for side in (".L", ".R"):
        sh, el, wr, tip = P("shoulder" + side), P("elbow" + side), P("wrist" + side), P("wing_tip" + side)
        f2, f3, hip = P("finger2" + side), P("finger3" + side), P("hip" + side)
        # The skin: a fan of thin triangles between arm, fingers and leg.
        for a_, b_, c_, bone in ((sh, el, hip, "wing_upper"), (el, f3, hip, "wing_lower"), (el, wr, f3, "wing_lower"),
                                 (wr, f2, f3, "wing_hand"), (wr, tip, f2, "wing_hand")):
            shapes.append(plate(a_, b_, c_, t, r["wing_round"], "wing", bone + side, blend=r["wing_blend"]))
        # Arm and finger bones along the edges.
        shapes.append(cone(sh, el, r["arm"][0], r["arm"][1], "wing_bone", "wing_upper" + side, "wing_lower" + side, blend=r["wing_blend"]))
        shapes.append(cone(el, wr, r["arm"][1], r["arm"][2], "wing_bone", "wing_lower" + side, "wing_hand" + side, blend=r["wing_blend"]))
        for f in (tip, f2, f3):
            shapes.append(cone(wr, f, r["arm"][2], r["arm"][2] * 0.4, "wing_bone", "wing_hand" + side, blend=r["wing_blend"]))
        shapes.append(cone(hip, P("foot" + side), r["leg"][0], r["leg"][1], "leg", "leg" + side, blend=b * 0.5))
    extra.setdefault("motion", {})
    c = Creature(name, joints, bones, shapes, **extra)
    for side in (".L", ".R"):
        c.parts.append(ear_part(P("ear_base" + side), P("ear_tip" + side), r, side))
    c.motion.setdefault("body", "bird")
    return c


# --- Wings for four-legged animals ------------------------------------------------------

def add_wings(c, j, r, feathers=True):
    """Gives a four-legged creature (from anatomy.quadruped) a pair of wings
    on its back: `j` holds the LEFT wing's shoulder, elbow, wrist and
    wing_tip; `r` the bird-style wing sizes (chord, wing_thick, arm,
    feathers, fan, ...). The wings use the same bones as a bird's, so the
    flying motions work on them. feathers=False makes skin wings like a
    bat's (a dragon's): `j` then also needs finger2, finger3 and anchor (where
    the trailing edge meets the body)."""
    keys = ("shoulder", "elbow", "wrist", "wing_tip") + (() if feathers else ("finger2", "finger3", "anchor"))
    for key in keys:
        c.joints["w_" + key + ".L"] = j[key]
        c.joints["w_" + key + ".R"] = mirror(j[key])
    P = lambda key: np.asarray(c.joints[key], float)
    for side, sx in ((".L", 1), (".R", -1)):
        c.bones += [
            Bone("wing_upper" + side, "w_shoulder" + side, "w_elbow" + side, "chest", up=(0, 0, 1)),
            Bone("wing_lower" + side, "w_elbow" + side, "w_wrist" + side, "wing_upper" + side, up=(0, 0, 1)),
            Bone("wing_hand" + side, "w_wrist" + side, "w_wing_tip" + side, "wing_lower" + side, up=(0, 0, 1)),
        ]
        lead = [P("w_shoulder" + side), P("w_elbow" + side), P("w_wrist" + side), P("w_wing_tip" + side)]
        names = ["wing_upper" + side, "wing_lower" + side, "wing_hand" + side]
        if feathers:
            c.shapes += _wing_feathers(lead, names, r, sx)
        else:
            sh, el, wr, tip = lead
            f2, f3, body = P("w_finger2" + side), P("w_finger3" + side), P("w_anchor" + side)
            for a_, b_, c_, bone in ((sh, el, body, names[0]), (el, f3, body, names[1]), (el, wr, f3, names[1]),
                                     (wr, f2, f3, names[2]), (wr, tip, f2, names[2])):
                c.shapes.append(plate(a_, b_, c_, r["wing_thick"], r.get("wing_round", r["wing_thick"] * 2), "wing", bone, blend=r["wing_blend"]))
            for f in (f2, f3):
                c.shapes.append(cone(wr, f, r["arm"][2], r["arm"][2] * 0.4, "wing_bone", names[2], blend=r["wing_blend"]))
        c.shapes.append(cone(lead[0], lead[1], r["arm"][0], r["arm"][1], "wing", names[0], names[1], blend=r["wing_blend"]))
        c.shapes.append(cone(lead[1], lead[2], r["arm"][1], r["arm"][2], "wing", names[1], names[2], blend=r["wing_blend"]))
        c.shapes.append(cone(lead[2], lead[3], r["arm"][2], r["arm"][2] * 0.4, "wing", names[2], blend=r["wing_blend"]))
    c.motion["body"] = "winged"
    return c


# --- Snakes ------------------------------------------------------------------------

def snake(name, j, r, **extra):
    """A snake: a body lying in curves on the ground from the tail tip to the
    middle, then (for a cobra) rising up to a spread hood and a head held
    level. Joints: tail_end, tail_mid, tail_base, pelvis, spine_mid,
    withers, neck_base, head_base, skull, snout_tip, jaw_hinge, chin.
    r["body"]: the body's radius at each of the first eight joints (tail tip
    to head); r["hood"]: the hood's size (0 for none)."""
    joints = dict(j)
    _root(joints, "pelvis", "spine_mid")
    bones = [
        Bone("root", "root", "root_tip"),
        Bone("hips", "pelvis", "spine_mid", "root"),
        Bone("chest", "spine_mid", "withers", "hips"),
        Bone("neck", "withers", "neck_base", "chest"),
        Bone("neck2", "neck_base", "head_base", "neck"),
        Bone("head", "head_base", "snout_tip", "neck2"),
        Bone("jaw", "jaw_hinge", "chin", "head"),
        Bone("tail1", "pelvis", "tail_base", "hips"),
        Bone("tail2", "tail_base", "tail_mid", "tail1"),
        Bone("tail3", "tail_mid", "tail_end", "tail2"),
    ]
    P = lambda key: np.asarray(joints[key], float)
    chain = ["tail_end", "tail_mid", "tail_base", "pelvis", "spine_mid", "withers", "neck_base", "head_base"]
    owners = ["tail3", "tail2", "tail1", "hips", "chest", "neck", "neck2"]
    radii = r["body"]
    b = r["blend"]
    shapes = []
    for i in range(len(chain) - 1):
        shapes.append(cone(P(chain[i]), P(chain[i + 1]), radii[i], radii[i + 1], "torso" if i >= 3 else "tail", owners[i], blend=b))
    if r.get("hood"):
        mid = (P("neck_base") + P("head_base")) / 2 + np.array([0, -r["hood"][1] * 0.6, 0])
        shapes.append(ellipsoid(tuple(mid), r["hood"], "hood", "neck2", blend=b))
    shapes += [
        ellipsoid(P("skull"), r["skull"], "head", "head", blend=b * 0.6),
        cone(P("skull") + np.asarray(r["snout_root"]), P("snout_tip"), r["snout"][0], r["snout"][1], "snout", "head", blend=b * 0.5),
        cone(P("jaw_hinge"), P("chin"), r["jaw"][0], r["jaw"][1], "jaw", "jaw", blend=b * 0.3),
    ]
    extra.setdefault("motion", {})
    c = Creature(name, joints, bones, shapes, **extra)
    c.motion.setdefault("body", "serpent")
    return c
