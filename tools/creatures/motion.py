"""Animations, written as poses for each frame.

A pose is {bone: (x, y, z) rotation in radians, "root": (x, y, z) offset in
meters}. Rotations are in each bone's own space, set up in scene.py so that
+X always swings a bone "forward/up": toes forward for legs, nose up for the
head, tail tip down for the tail. Y twists the bone, Z turns it sideways.

Every animation is a function (creature, t) -> pose, with t from 0 to 1.
Loops (idle, walk) must match at t=0 and t=1.
"""
import math

import numpy as np

TAU = 2 * math.pi
LEGS = ["fl.L", "fl.R", "hl.L", "hl.R"]


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def ease_out(x):
    x = min(max(x, 0.0), 1.0)
    return 1 - (1 - x) ** 3


def ease_in(x):
    x = min(max(x, 0.0), 1.0)
    return x ** 3


def keys(t, points):
    """Smoothly interpolates between (time, value) keys; value can be a tuple."""
    if t <= points[0][0]:
        return np.asarray(points[0][1], float)
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        if t <= t1:
            u = ease((t - t0) / max(t1 - t0, 1e-9))
            return np.asarray(v0, float) * (1 - u) + np.asarray(v1, float) * u
    return np.asarray(points[-1][1], float)


class Pose(dict):
    def rot(self, bone, x=0.0, y=0.0, z=0.0):
        cur = self.get(bone, (0.0, 0.0, 0.0))
        self[bone] = (cur[0] + x, cur[1] + y, cur[2] + z)

    def leg(self, leg, upper=0.0, lower=0.0, foot=0.0, splay=0.0):
        kind, side = leg.split(".")
        self.rot(f"{kind}_upper.{side}", upper, 0, splay)
        self.rot(f"{kind}_lower.{side}", lower)
        self.rot(f"{kind}_foot.{side}", foot)

    def move(self, x=0.0, y=0.0, z=0.0):
        cur = self.get("root_loc", (0.0, 0.0, 0.0))
        self["root_loc"] = (cur[0] + x, cur[1] + y, cur[2] + z)


# --- Quadruped -------------------------------------------------------------------

def _scale(c):
    """Motion sizes scale with the animal's leg length."""
    return c.joints["withers"][2]


def idle(c, t):
    if c.motion.get("body") == "bird":
        return bird_flap(c, t, power=c.motion.get("hover_power", 0.55))
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=breath * s * 0.006)
    p.rot("chest", x=breath * 0.01)
    # Look around a little: turn right, back, left, back.
    look = math.sin(t * TAU) * 0.18
    p.rot("neck", x=0.04 + math.sin(t * TAU * 2) * 0.03, z=look * 0.6)
    p.rot("head", z=look * 0.5, x=-0.03 * math.cos(t * TAU))
    p.rot("ear.L", z=0.08 * max(0, math.sin(t * TAU * 2)))
    p.rot("ear.R", z=-0.08 * max(0, math.sin(t * TAU * 2 + 1.5)))
    _tail(p, t, sway=0.18, droop=0.0)
    _trunk(p, z=math.sin(t * TAU) * 0.25, x=0.08 + 0.08 * math.sin(t * TAU * 2))
    return p


def _trunk(p, x=0.0, z=0.0):
    """Elephants: swing (z) and curl (x, positive lifts the tip forward)."""
    p.rot("trunk1", x=x * 0.5, z=z * 0.5)
    p.rot("trunk2", x=x * 0.8, z=z * 0.7)
    p.rot("trunk3", x=x * 1.0, z=z)


def _tail(p, t, sway=0.2, droop=0.0, speed=1):
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=droop / 3, z=math.sin(t * TAU * speed - i * 0.8) * sway * (0.6 + 0.3 * i))


GAITS = {
    # offsets per leg (front left, front right, hind left, hind right),
    # fraction of the cycle the foot is on the ground, bobs per cycle
    "trot": {"offsets": (0.0, 0.5, 0.5, 0.0), "stance": 0.55, "bobs": 2, "swing": 0.42, "lift": 0.9},
    "walk": {"offsets": (0.0, 0.5, 0.75, 0.25), "stance": 0.66, "bobs": 2, "swing": 0.32, "lift": 0.7},
    "gallop": {"offsets": (0.55, 0.65, 0.0, 0.1), "stance": 0.38, "bobs": 1, "swing": 0.62, "lift": 1.1},
}


def walk(c, t):
    if c.motion.get("body") == "bird":
        return bird_flap(c, t, power=1.0)
    gait = GAITS[c.motion.get("gait", "trot")]
    p = Pose()
    s = _scale(c)
    amp = gait["swing"] * c.motion.get("stride", 1.0)
    for leg, offset in zip(LEGS, gait["offsets"]):
        q = (t + offset) % 1.0
        front = leg.startswith("fl")
        st = gait["stance"]
        if q < st:
            # On the ground: sweep from forward to back.
            u = q / st
            swing = amp * (1 - 2 * u)
            lift = 0.0
        else:
            # In the air: fold the leg and bring it forward.
            u = (q - st) / (1 - st)
            swing = amp * (-1 + 2 * ease(u))
            lift = math.sin(math.pi * u) * gait["lift"]
        if front:
            p.leg(leg, upper=swing * 0.8, lower=-lift * 0.75 + swing * 0.2, foot=-lift * 0.9)
        else:
            p.leg(leg, upper=swing * 0.7 + lift * 0.15, lower=-lift * 0.55 - swing * 0.15, foot=lift * 0.95 + swing * 0.1)
    bob = math.cos(t * TAU * gait["bobs"])
    p.move(z=-bob * s * 0.02)
    if gait is GAITS["gallop"]:
        # The spine coils and stretches with each bound.
        flex = math.sin(t * TAU)
        p.rot("hips", x=flex * 0.12)
        p.rot("chest", x=-flex * 0.1)
        p.rot("neck", x=-flex * 0.12)
        p.move(z=max(0.0, math.sin(t * TAU)) * s * 0.06)
    p.rot("neck", x=bob * 0.03)
    p.rot("head", x=-bob * 0.03)
    p.rot("ear.L", x=-0.15)
    p.rot("ear.R", x=-0.15)
    _tail(p, t, sway=0.12, droop=-0.1, speed=gait["bobs"] / 2)
    _trunk(p, z=math.sin(t * TAU) * 0.2, x=0.1)
    return p


def attack(c, t):
    style = c.motion.get("attack", "bite")
    return ATTACKS[style](c, t)


# The frame (0-1) where each attack lands; the game times hits to it.
HIT_AT = {"pounce_bite": 0.45, "bite": 0.42, "swipe": 0.48, "charge": 0.45, "stomp": 0.52, "throw": 0.5, "dive": 0.5}


def pounce_bite(c, t):
    """Crouch, spring forward with the front legs reaching, snap, settle back."""
    p = Pose()
    s = _scale(c)
    crouch = keys(t, [(0, 0), (0.25, 1), (0.38, 0), (0.75, 0)])
    reach = keys(t, [(0, 0), (0.25, 0), (0.42, 1), (0.55, 0.85), (0.9, 0)])
    jaw = keys(t, [(0, 0), (0.25, 0.1), (0.38, 1), (0.46, 0), (1, 0)])
    p.move(y=reach * s * 0.42, z=-crouch * s * 0.14 + float(reach) * s * 0.1)
    p.rot("hips", x=crouch * 0.12 - reach * 0.05)
    p.rot("chest", x=-crouch * 0.08 + reach * 0.1)
    for side in ("L", "R"):
        p.leg("hl." + side, upper=crouch * 0.35 - reach * 0.45, lower=-crouch * 0.7 + reach * 0.4, foot=crouch * 0.6 - reach * 0.3)
        p.leg("fl." + side, upper=-crouch * 0.25 + reach * 0.75, lower=-crouch * 0.4 - reach * 0.1, foot=reach * 0.3)
        p.rot("ear." + side, x=-crouch * 0.35 - reach * 0.2)
    p.rot("neck", x=-crouch * 0.25 + reach * 0.05)
    gape = c.motion.get("gape", 0.55)
    p.rot("head", x=-crouch * 0.1 - reach * 0.15 + jaw * 0.22 * gape)
    p.rot("jaw", x=-jaw * gape)
    _tail(p, 0.0, sway=0.0, droop=crouch * -0.3 + reach * 0.2)
    return p


def bite(c, t):
    """Lunge the head forward and snap."""
    p = Pose()
    s = _scale(c)
    lean = keys(t, [(0, 0), (0.2, -0.3), (0.42, 1), (0.6, 0.7), (1, 0)])
    jaw = keys(t, [(0, 0), (0.25, 1), (0.42, 0), (1, 0)])
    p.move(y=lean * s * 0.12, z=-abs(lean) * s * 0.02)
    p.rot("chest", x=-lean * 0.06)
    p.rot("neck", x=-lean * 0.25)
    # "gape": how wide the jaws open, in radians (a hippo's are enormous).
    gape = c.motion.get("gape", 0.5)
    p.rot("head", x=-lean * 0.1 + jaw * 0.3 * gape)
    p.rot("jaw", x=-jaw * gape)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=lean * 0.25, lower=-lean * 0.1)
        p.leg("hl." + side, upper=-lean * 0.2, lower=lean * 0.1)
        p.rot("ear." + side, x=-0.3 * abs(lean))
    return p


def _rear(c, p, angle):
    """Tilts the whole body nose-up by `angle` (radians), pivoting on the
    hind feet so they stay on the ground."""
    hind_y = c.joints["hind_toe.L"][1] - c.joints["root"][1]
    p.move(y=hind_y * (1 - math.cos(angle)), z=-hind_y * math.sin(angle))
    rr = p.get("root_rot", (0.0, 0.0, 0.0))
    p["root_rot"] = (rr[0] + angle, rr[1], rr[2])


def swipe(c, t):
    """Rear up a little, raise a front paw and bring it down hard."""
    p = Pose()
    rise = keys(t, [(0, 0), (0.35, 1), (0.5, 0.55), (0.75, 0.2), (1, 0)])
    paw = keys(t, [(0, 0), (0.3, 1), (0.48, -0.6), (0.7, -0.2), (1, 0)])
    _rear(c, p, float(rise) * c.motion.get("rear", 0.28))
    p.leg("fl.R", upper=float(paw) * 0.9 + 0.3 * float(rise), lower=-abs(float(paw)) * 0.5 - 0.3 * float(rise), foot=-0.3 * float(rise))
    p.leg("fl.L", upper=0.25 * float(rise), lower=-0.45 * float(rise), foot=-0.2 * float(rise))
    p.leg("hl.L", upper=-0.25 * float(rise), lower=-0.25 * float(rise), foot=0.3 * float(rise))
    p.leg("hl.R", upper=-0.25 * float(rise), lower=-0.25 * float(rise), foot=0.3 * float(rise))
    jaw = keys(t, [(0, 0), (0.3, 0.8), (0.5, 0.3), (1, 0)])
    p.rot("neck", x=-float(rise) * 0.35 - 0.1 * float(jaw))
    p.rot("head", x=-float(rise) * 0.1)
    p.rot("jaw", x=-float(jaw) * 0.5)
    for side in ("L", "R"):
        p.rot("ear." + side, x=-0.3 * float(rise))
    return p


def charge(c, t):
    """Drop the head and drive forward, tossing the head up on impact."""
    p = Pose()
    s = _scale(c)
    drive = keys(t, [(0, 0), (0.2, -0.25), (0.42, 1), (0.55, 0.85), (1, 0)])
    duck = keys(t, [(0, 0), (0.2, 1), (0.4, 1), (0.5, -0.6), (0.7, 0), (1, 0)])
    p.move(y=float(drive) * s * c.motion.get("charge_reach", 0.35), z=-abs(float(duck)) * s * 0.03)
    p.rot("neck", x=-float(duck) * 0.35)
    p.rot("head", x=-float(duck) * 0.25)
    p.rot("chest", x=-float(duck) * 0.05)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=float(drive) * 0.35, lower=-abs(float(drive)) * 0.25)
        p.leg("hl." + side, upper=-float(drive) * 0.4, lower=float(drive) * 0.15, foot=float(drive) * 0.2)
        p.rot("ear." + side, x=-0.4 * abs(float(duck)))
    _tail(p, 0.0, sway=0.0, droop=-0.3 * abs(float(drive)))
    return p


def stomp(c, t):
    """Rear the front up, then slam the front feet down."""
    p = Pose()
    s = _scale(c)
    rise = keys(t, [(0, 0), (0.38, 1), (0.52, -0.08), (0.7, 0), (1, 0)])
    _rear(c, p, float(rise) * c.motion.get("rear", 0.22))
    for side in ("L", "R"):
        p.leg("fl." + side, upper=0.45 * float(rise), lower=-0.6 * max(float(rise), 0), foot=-0.3 * max(float(rise), 0))
        p.leg("hl." + side, upper=-0.15 * float(rise), lower=-0.1 * float(rise))
        p.rot("ear." + side, z=(0.35 if side == "L" else -0.35) * max(float(rise), 0))
    p.rot("neck", x=float(rise) * 0.25)
    p.rot("head", x=float(rise) * 0.2)
    p.move(z=-max(-float(rise), 0) * s * 0.05)
    # The trunk curls up high, then lashes down with the stomp.
    _trunk(p, x=max(float(rise), 0) * 1.1 - max(-float(rise), 0) * 0.5)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.4 * max(float(rise), 0))
    return p


def throw(c, t):
    """Sit up on the haunches, wind a front paw back and fling."""
    p = Pose()
    sit = keys(t, [(0, 0), (0.25, 1), (0.75, 1), (1, 0)])
    arm = keys(t, [(0, 0), (0.3, -1), (0.48, 1), (0.65, 0.4), (1, 0)])
    _rear(c, p, float(sit) * c.motion.get("rear", 0.75))
    for side in ("L", "R"):
        p.leg("hl." + side, upper=-0.6 * float(sit), lower=-0.5 * float(sit), foot=0.9 * float(sit))
    p.leg("fl.R", upper=float(arm) * 1.0 + 0.4 * float(sit), lower=-0.6 * float(sit))
    p.leg("fl.L", upper=0.5 * float(sit), lower=-0.9 * float(sit))
    p.rot("neck", x=-float(sit) * 0.55)
    p.rot("head", x=-float(sit) * 0.2)
    _tail(p, 0.0, sway=0.0, droop=-0.4 * float(sit))
    return p


# --- Birds ------------------------------------------------------------------------

def _wings(p, upper, lower, hand, sweep=0.0, twist=0.0):
    """Positive raises the wing (both sides). `sweep` pulls the wing back."""
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("wing_upper." + side, x=upper, z=-sweep * sign, y=twist * sign)
        p.rot("wing_lower." + side, x=lower, z=-sweep * 0.6 * sign)
        p.rot("wing_hand." + side, x=hand, z=-sweep * 0.4 * sign)


def bird_flap(c, t, power=1.0):
    """One wingbeat: a strong downstroke, then the wing folds a little and
    comes back up. The body bobs against the wings."""
    p = Pose()
    a = TAU * t
    amp = c.motion.get("flap", 0.75) * power
    up = math.sin(a)
    _wings(p, upper=up * amp, lower=math.sin(a - 0.5) * amp * 0.55, hand=math.sin(a - 1.0) * amp * 0.45,
           sweep=max(0.0, math.cos(a)) * 0.25 * power)
    s = c.motion.get("altitude", 0.5)
    p.move(z=-up * s * 0.05 * power)
    p.rot("neck", x=up * 0.05)
    p.rot("head", x=-up * 0.05)
    p.rot("tail1", x=math.sin(a + 1.0) * 0.08)
    for side in ("L", "R"):
        p.rot("leg." + side, x=-0.9)
    return p


def bird_strike(c, t):
    """Stoop: wings sweep back, the bird drops forward onto its target with
    talons out, then beats back up."""
    p = Pose()
    s = c.motion.get("altitude", 0.5)
    dive = keys(t, [(0, 0), (0.25, 0.4), (0.48, 1), (0.6, 0.8), (1, 0)])
    talons = keys(t, [(0, 0), (0.35, 0), (0.48, 1), (0.65, 0.6), (1, 0)])
    beat = keys(t, [(0, 0), (0.55, 0), (0.7, 1), (0.85, -0.6), (1, 0)])
    p.move(y=float(dive) * s * 0.5, z=-float(dive) * s * 0.55)
    p["root_rot"] = (-float(dive) * 0.45, 0.0, 0.0)
    _wings(p, upper=float(dive) * 0.5 + float(beat) * 0.7, lower=-float(dive) * 0.2 + float(beat) * 0.4,
           hand=-float(dive) * 0.3, sweep=float(dive) * 0.55)
    for side in ("L", "R"):
        p.rot("leg." + side, x=-0.9 + float(talons) * 1.7)
    p.rot("neck", x=float(dive) * 0.3)
    p.rot("jaw", x=-float(talons) * 0.4)
    return p


def bird_fall(c, t):
    """Wings crumple and it tumbles to the ground."""
    p = Pose()
    s = c.motion.get("altitude", 0.5)
    fall = keys(t, [(0, 0), (0.8, 1), (1, 1)])
    p.move(z=-float(fall) * (s - 0.02))
    p["root_rot"] = (-float(fall) * 0.2, float(fall) * 0.45, 0.0)
    _wings(p, upper=0.6 * float(fall), lower=-0.8 * float(fall), hand=-0.6 * float(fall), sweep=0.3 * float(fall))
    return p


ATTACKS = {"dive": bird_strike, "pounce_bite": pounce_bite, "bite": bite, "swipe": swipe, "charge": charge, "stomp": stomp, "throw": throw}


def death(c, t):
    """Topple onto the side; legs go limp. The roll pivots under the spine, so
    the body swings out sideways: shift it back over the spot where it stood.
    rest_on_ground then lifts it onto the ground."""
    if c.motion.get("body") == "bird":
        return bird_fall(c, t)
    p = Pose()
    s = _scale(c)
    fall = keys(t, [(0, 0), (0.7, 1), (1, 1)])
    p.move(x=-fall * s * 0.55)
    p["root_rot"] = (0.0, float(fall) * 1.45, 0.0)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=fall * 0.4, lower=-fall * 0.5, splay=sign * fall * 0.2)
        p.leg("hl." + side, upper=-fall * 0.3, lower=-fall * 0.4, splay=sign * fall * 0.2)
    p.rot("neck", x=-fall * 0.3)
    p.rot("jaw", x=-fall * 0.2)
    return p


ANIMATIONS = {
    # name: (function, frames, frames per second, loops)
    "idle": (idle, 8, 6, True),
    "walk": (walk, 8, 12, True),
    "attack": (attack, 10, 16, False),
    "death": (death, 6, 10, False),
}


# --- Applying poses in Blender --------------------------------------------------------

def apply(arm, pose):
    """Poses the armature. Root offsets and the death roll move the armature
    object itself, which sits inside the "facing" empty, so they stay in the
    animal's own frame whichever way it faces."""
    for pb in arm.pose.bones:
        pb.rotation_euler = pose.get(pb.name, (0.0, 0.0, 0.0))
        pb.location = (0, 0, 0)
    rest = arm.get("rest_offset", (0.0, 0.0, 0.0))
    loc = pose.get("root_loc", (0.0, 0.0, 0.0))
    arm.location = (rest[0] + loc[0], rest[1] + loc[1], rest[2] + loc[2])
    arm.rotation_euler = pose.get("root_rot", (0.0, 0.0, 0.0))


def rest_on_ground(arm, body):
    """Lifts the armature until no part of the posed body is under the
    ground, which would hide it (the shadow catcher is solid to the camera)."""
    import bpy
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    me = evaluated.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    evaluated.to_mesh_clear()
    m = np.array(body.matrix_world)
    lowest = float((co.reshape(-1, 3) @ m[2, :3] + m[2, 3]).min())
    if lowest < 0:
        arm.location.z -= lowest


def preview_pose(arm, creature, spec):
    """spec like 'walk:0.25' or 'attack:0.4'."""
    name, _, when = spec.partition(":")
    fn = ANIMATIONS[name][0]
    apply(arm, fn(creature, float(when or 0)))
