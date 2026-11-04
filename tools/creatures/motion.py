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
    body = c.motion.get("body")
    if body == "bird":
        return bird_flap(c, t, power=c.motion.get("hover_power", 0.55))
    if body in BODY_IDLE:
        return BODY_IDLE[body](c, t)
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
    # Upright on two legs: each arm swings with the opposite leg.
    "biped": {"offsets": (0.5, 0.0, 0.0, 0.5), "stance": 0.6, "bobs": 2, "swing": 0.34, "lift": 0.45},
    # A sea turtle on the beach: both front flippers row together, then both
    # back ones push, and the body surges once per stroke.
    "flipper": {"offsets": (0.0, 0.0, 0.5, 0.5), "stance": 0.5, "bobs": 1, "swing": 0.55, "lift": 0.5},
}


def walk(c, t):
    body = c.motion.get("body")
    if body == "bird":
        return bird_flap(c, t, power=1.0)
    if body in BODY_WALK:
        return BODY_WALK[body](c, t)
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
    # Lizards: the spine bends side to side with each step.
    wiggle = c.motion.get("wiggle", 0.0)
    if wiggle:
        p.rot("chest", z=math.sin(t * TAU) * wiggle)
        p.rot("hips", z=-math.sin(t * TAU) * wiggle)
        p.rot("neck", z=-math.sin(t * TAU) * wiggle * 0.6)
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
# (Attacks for other bodies are further down; HIT_AT covers them all.)
HIT_AT = {"pounce_bite": 0.45, "bite": 0.42, "swipe": 0.48, "charge": 0.45, "stomp": 0.52, "throw": 0.5, "dive": 0.5,
          "spit": 0.5, "snap": 0.45, "flutter_dive": 0.5}


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


# --- Other bodies (bodies.py) -------------------------------------------------------

def _size(c):
    """A length to scale motions by, for bodies without legs to measure."""
    lo = np.min([np.asarray(v, float) for v in c.joints.values()], axis=0)
    hi = np.max([np.asarray(v, float) for v in c.joints.values()], axis=0)
    return float(max(hi - lo))


def _flutter(p, beat, amp, fore="wing_fore", hind="wing_hind"):
    """Butterfly wings: both pairs clap up and down, the hind pair a little behind."""
    for side, sign in (("L", 1), ("R", -1)):
        p.rot(f"{fore}.{side}", x=beat * amp, z=-sign * 0.1 * beat)
        p.rot(f"{hind}.{side}", x=beat * amp * 0.85)


def insect_idle(c, t):
    """Hovering: quick wingbeats (two a cycle) and a soft bob."""
    p = Pose()
    s = _size(c)
    beat = math.sin(t * TAU * 2)
    _flutter(p, beat, c.motion.get("flap", 0.9))
    p.move(z=-beat * s * 0.03)
    p.rot("tail1", x=0.1 + beat * 0.05)
    for side in ("L", "R"):
        p.rot("antenna." + side, x=0.05 * math.sin(t * TAU))
    return p


def insect_walk(c, t):
    """Flitting along: wider wingbeats, nose a little down, a looping drift."""
    p = insect_idle(c, t)
    s = _size(c)
    p.move(x=math.sin(t * TAU) * s * 0.04, z=math.sin(t * TAU) * s * 0.03)
    p["root_rot"] = (-0.12, 0.0, math.sin(t * TAU) * 0.15)
    return p


def flutter_dive(c, t):
    """A butterfly's attack: wings snap shut, it darts at the target and
    flutters back."""
    p = Pose()
    s = _size(c)
    dive = keys(t, [(0, 0), (0.3, -0.2), (0.5, 1), (0.65, 0.7), (1, 0)])
    beat = math.sin(t * TAU * 3)
    _flutter(p, beat * (1 - float(abs(dive))) + float(dive) * 0.9, c.motion.get("flap", 0.9))
    p.move(y=float(dive) * s * 0.6, z=-float(dive) * s * 0.5)
    p["root_rot"] = (-float(dive) * 0.5, 0.0, 0.0)
    return p


def insect_fall(c, t):
    p = Pose()
    fall = keys(t, [(0, 0), (0.8, 1), (1, 1)])
    p.move(z=-float(fall) * (c.motion.get("altitude", 0.3) - 0.01))
    p["root_rot"] = (0.0, float(fall) * 1.3, 0.0)
    _flutter(p, 1.0, float(fall) * 0.9)
    return p


def fish_idle(c, t):
    """Lying on its belly: gills pump, side fins flap, the tail swishes."""
    p = Pose()
    s = _size(c)
    breath = math.sin(t * TAU)
    p.move(z=abs(breath) * s * 0.01)
    p.rot("jaw", x=-0.06 * (1 + breath))
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("pect." + side, z=sign * 0.4 * math.sin(t * TAU * 2), x=0.2 * math.sin(t * TAU * 2 + 1))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=math.sin(t * TAU - i * 0.9) * (0.12 + 0.1 * i))
    p.rot("fin_dorsal", z=0.1 * math.sin(t * TAU + 0.5))
    return p


def fish_hop(c, t):
    """Flop and hop: curl the tail, spring forward in an arc with a flick,
    land with a squash and wiggle."""
    p = Pose()
    s = _size(c)
    curl = keys(t, [(0, 0.3), (0.2, 1), (0.35, -0.7), (0.6, 0), (0.85, 0.2), (1, 0.3)])
    air = max(0.0, math.sin(math.pi * min(max((t - 0.25) / 0.5, 0.0), 1.0)))
    p.move(y=air * s * 0.08, z=air * s * c.motion.get("hop", 0.28))
    p["root_rot"] = (air * 0.25 - 0.1 * float(curl), 0.0, 0.0)
    p.rot("hips", x=-float(curl) * 0.15)
    p.rot("chest", x=float(curl) * 0.1)
    p.rot("head", x=float(curl) * 0.1)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-float(curl) * (0.35 + 0.15 * i), z=math.sin(t * TAU * 2 - i) * 0.15)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("pect." + side, z=sign * (0.5 * air + 0.2))
    return p


def cetacean_idle(c, t):
    """A dolphin or whale resting on its belly: breathing, flippers paddling,
    the fluke rising and falling."""
    p = Pose()
    s = _size(c)
    wave = math.sin(t * TAU)
    p.move(z=abs(wave) * s * 0.006)
    p.rot("head", x=0.05 + wave * 0.04)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-math.sin(t * TAU - i * 0.8) * (0.08 + 0.06 * i) - 0.05)
    for side in ("L", "R"):
        p.rot("pect." + side, x=0.25 * math.sin(t * TAU * 2))
    return p


def cetacean_slide(c, t):
    """Belly-sliding: the body heaves in a wave from head to tail, flippers
    push, and it surges forward on each heave."""
    p = Pose()
    s = _size(c)
    wave = lambda k: math.sin(t * TAU * 2 - k)
    p.move(y=max(0.0, math.sin(t * TAU * 2)) * s * 0.06, z=max(0.0, wave(0)) * s * 0.07)
    p.rot("neck", x=wave(0) * 0.2)
    p.rot("head", x=wave(0.4) * 0.12)
    p.rot("chest", x=-wave(0.8) * 0.1)
    p.rot("hips", x=wave(1.2) * 0.1)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-wave(1.6 + i * 0.6) * (0.28 + 0.14 * i))
    for side in ("L", "R"):
        p.rot("pect." + side, x=0.55 * math.sin(t * TAU * 2 + 0.5))
    return p


def crustacean_idle(c, t):
    """A shrimp waiting: antennae wave, claws open and close a little, the
    tail fan flicks."""
    p = Pose()
    s = _size(c)
    w = math.sin(t * TAU)
    p.move(z=w * s * 0.006)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("antenna." + side, x=0.1 * math.sin(t * TAU + sign), z=sign * 0.08 * math.sin(t * TAU * 2))
        p.rot("claw_finger." + side, x=0.15 * (1 + math.sin(t * TAU * 2)))
        p.rot("claw_arm." + side, x=0.05 * w)
    p.rot("tail2", x=0.08 * w)
    p.rot("tail3", x=0.12 * w)
    return p


def crustacean_scuttle(c, t):
    """Scuttling: the three pairs of legs step in waves, the body sways and
    the claws are held up ready."""
    p = crustacean_idle(c, t)
    s = _size(c)
    for n in (1, 2, 3):
        for side, phase in (("L", 0.0), ("R", 0.5)):
            q = (t * 2 + phase + n * 0.33) % 1.0
            swing = math.sin(q * TAU)
            lift = max(0.0, math.cos(q * TAU))
            p.rot(f"leg{n}_upper.{side}", x=swing * 0.5, z=0.0)
            p.rot(f"leg{n}_lower.{side}", x=-lift * 0.5)
    p.move(z=abs(math.sin(t * TAU * 2)) * s * 0.012)
    p["root_rot"] = (0.0, 0.0, math.sin(t * TAU * 2) * 0.06)
    for side in ("L", "R"):
        p.rot("claw_arm." + side, x=0.15)
    return p


def snap(c, t):
    """Pistol shrimp: the big claw rises and cocks open, then snaps shut with
    a jolt of the whole body."""
    p = crustacean_idle(c, 0.0)
    big = "." + c.motion.get("big_claw", "R").strip(".")
    raise_ = keys(t, [(0, 0), (0.3, 1), (0.45, 0.8), (0.7, 0.3), (1, 0)])
    open_ = keys(t, [(0, 0), (0.3, 1), (0.42, 1), (0.46, -0.1), (1, 0)])
    jolt = keys(t, [(0, 0), (0.44, 0), (0.48, 1), (0.6, 0), (1, 0)])
    p.rot("claw_arm" + big, x=float(raise_) * 0.6)
    p.rot("claw_hand" + big, x=float(raise_) * 0.2)
    p.rot("claw_finger" + big, x=float(open_) * 0.9)
    p.move(y=-float(jolt) * _size(c) * 0.05)
    p.rot("chest", x=float(raise_) * 0.06)
    return p


def spit(c, t):
    """Shoot from the mouth (spit, squirt, a water jet, a sonar call): rear
    the head back with the mouth shut, then thrust it forward, mouth open,
    with a little recoil."""
    p = Pose()
    s = _size(c) if "withers" not in c.joints else c.joints["withers"][2] + _size(c) * 0.1
    rear = keys(t, [(0, 0), (0.3, 1), (0.48, -0.6), (0.65, -0.3), (1, 0)])
    jaw = keys(t, [(0, 0), (0.42, 0), (0.5, 1), (0.7, 0.6), (1, 0)])
    p.rot("neck", x=float(rear) * 0.3)
    p.rot("head", x=float(rear) * 0.25 + float(jaw) * 0.1)
    p.rot("jaw", x=-float(jaw) * c.motion.get("gape", 0.45))
    p.rot("chest", x=float(rear) * 0.06)
    p.move(y=-max(0.0, -float(rear)) * s * 0.06)
    for side in ("L", "R"):
        p.rot("ear." + side, x=-0.3 * abs(float(rear)))
        p.rot("pect." + side, x=0.3 * float(rear))
    if c.motion.get("body") in ("fish", "cetacean"):
        for i, bone in enumerate(("tail1", "tail2", "tail3")):
            p.rot(bone, x=float(rear) * (0.15 + 0.08 * i))
    return p


def winged_flap(c, t, power=1.0):
    """A four-legged animal with wings in flight: wingbeats like a bird's,
    front legs tucked, hind legs trailing, and a gentle paddle."""
    p = bird_flap(c, t, power)
    paddle = math.sin(t * TAU)
    for side, k in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.7 + 0.15 * paddle * k, lower=-1.2, foot=-0.6)
        p.leg("hl." + side, upper=-0.6 - 0.1 * paddle * k, lower=0.3, foot=0.4)
    _tail(p, t, sway=0.1, droop=-0.3)
    p.rot("neck", x=0.1)
    return p


def winged_dive(c, t):
    """Swoops onto the target: wings sweep back, front hooves or talons
    reach forward, then it beats back up."""
    p = bird_strike(c, t)
    reach = keys(t, [(0, 0), (0.35, 0.2), (0.5, 1), (0.65, 0.5), (1, 0)])
    for side in ("L", "R"):
        p.leg("fl." + side, upper=0.7 + float(reach) * 0.8, lower=-1.2 + float(reach) * 1.0, foot=-0.6)
        p.leg("hl." + side, upper=-0.6, lower=0.3, foot=0.4)
    return p


def serpent_idle(c, t):
    """A raised snake swaying, hood spread, the tail curling a little."""
    p = Pose()
    sway = math.sin(t * TAU)
    p.rot("neck", z=sway * 0.12)
    p.rot("neck2", z=-sway * 0.08, x=0.04 * math.sin(t * TAU * 2))
    p.rot("head", z=-sway * 0.05)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=math.sin(t * TAU - i) * 0.06)
    return p


def slither(c, t):
    """Slithering: waves run down the body from head to tail, side to side,
    and the raised front sways with them."""
    p = Pose()
    s = _size(c)
    wave = lambda k: math.sin(t * TAU - k)
    p.rot("hips", z=wave(0.0) * 0.25)
    p.rot("chest", z=-wave(0.8) * 0.22)
    p.rot("neck", z=wave(1.6) * 0.12)
    p.rot("neck2", z=-wave(2.2) * 0.08)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=wave(-0.9 * (i + 1)) * (0.3 + 0.08 * i))
    p.move(x=wave(0.0) * s * 0.02)
    return p


def frog_idle(c, t):
    """A sitting frog breathing: its throat and body swell and settle."""
    p = Pose()
    s = _scale(c)
    breath = max(0.0, math.sin(t * TAU * 2))
    p.move(z=breath * s * 0.01)
    p.rot("jaw", x=-0.04 * breath)
    p.rot("head", x=0.02 * breath)
    return p


def frog_hop(c, t):
    """Hopping: crouch, the long back legs fling it forward in an arc with the
    front legs reaching, then it lands and folds up again."""
    p = Pose()
    s = _scale(c)
    crouch = keys(t, [(0, 0.4), (0.15, 1), (0.3, -0.4), (0.6, -0.2), (0.8, 0.6), (1, 0.4)])
    air = max(0.0, math.sin(math.pi * min(max((t - 0.2) / 0.55, 0.0), 1.0)))
    p.move(y=air * s * 0.4, z=air * s * c.motion.get("hop", 0.6))
    p["root_rot"] = (air * 0.25 - float(crouch) * 0.08, 0.0, 0.0)
    for side in ("L", "R"):
        k = float(crouch)
        p.leg("hl." + side, upper=k * 0.5 - (1 - k) * 0.6 * air, lower=-k * 0.9 + air * 0.8, foot=k * 0.9 - air * 0.5)
        p.leg("fl." + side, upper=air * 0.7 - k * 0.2, lower=-air * 0.3)
    return p


def pinniped_idle(c, t):
    """A seal resting on its belly: breathing, looking around, the back
    flippers waving."""
    p = Pose()
    s = _size(c)
    wave = math.sin(t * TAU)
    p.move(z=max(0.0, math.sin(t * TAU * 2)) * s * 0.004)
    p.rot("neck", x=0.05 * wave)
    p.rot("head", z=0.15 * wave, x=-0.04 * math.sin(t * TAU * 2))
    for i, side in enumerate(("L", "R")):
        p.leg("hl." + side, foot=0.25 * math.sin(t * TAU * 2 + i * math.pi))
        p.leg("fl." + side, upper=0.06 * math.sin(t * TAU * 2 + i))
    return p


def galumph(c, t):
    """Galumphing on land: the chest heaves up on the front flippers, then
    the hips hump up and slide in behind, like a big caterpillar."""
    p = Pose()
    s = _size(c)
    lift = math.sin(t * TAU)
    hump = math.sin(t * TAU - 1.4)
    p.move(y=max(0.0, lift) * s * 0.03, z=max(0.0, lift) * s * 0.05 + max(0.0, hump) * s * 0.02)
    p.rot("chest", x=-lift * 0.16)
    p.rot("hips", x=hump * 0.2)
    p.rot("neck", x=lift * 0.18)
    p.rot("head", x=-lift * 0.12)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=-lift * 0.5, lower=lift * 0.25, foot=lift * 0.2)
        p.leg("hl." + side, upper=hump * 0.15, foot=-hump * 0.35)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-hump * (0.08 + 0.04 * i))
    return p


BODY_IDLE = {"insect": insect_idle, "fish": fish_idle, "cetacean": cetacean_idle, "crustacean": crustacean_idle,
             "serpent": serpent_idle, "frog": frog_idle, "pinniped": pinniped_idle,
             "winged": lambda c, t: winged_flap(c, t, power=c.motion.get("hover_power", 0.55))}
BODY_WALK = {"insect": insect_walk, "fish": fish_hop, "cetacean": cetacean_slide, "crustacean": crustacean_scuttle,
             "serpent": slither, "frog": frog_hop, "pinniped": galumph,
             "winged": winged_flap}


ATTACKS = {"dive": bird_strike, "pounce_bite": pounce_bite, "bite": bite, "swipe": swipe, "charge": charge, "stomp": stomp, "throw": throw,
           "spit": spit, "snap": snap, "flutter_dive": flutter_dive, "winged_dive": winged_dive}


# --- Personality and celebrations ----------------------------------------------------

def _pivot(c):
    """Roughly the middle of the body (armature space), to spin around."""
    zs = [j[2] for j in c.joints.values()]
    return np.array([0.0, c.joints["root"][1], (min(zs) + max(zs)) / 2])


def _spin(c, p, x=0.0, z=0.0):
    """Turns the whole animal (x: nose up, z: to its left) about the middle
    of its body rather than its feet, so a flip or a twirl stays in place."""
    rr = p.get("root_rot", (0.0, 0.0, 0.0))
    rx, rz = rr[0] + x, rr[2] + z
    cx, sx, cz, sz = math.cos(rx), math.sin(rx), math.cos(rz), math.sin(rz)
    rot_x = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    rot_z = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    pivot = _pivot(c)
    shift = pivot - rot_z @ rot_x @ pivot
    p["root_rot"] = (rx, rr[1], rz)
    p.move(*shift)


def fidget(c, t):
    """A moment of personality while it stands about (the game plays it now
    and then): a look one way and the other, a head shake with the ears
    flapping, a tail wag. Fliers turn a somersault in the air. Starts and
    ends on the idle pose, so it slips in and out of the idle."""
    body = c.motion.get("body")
    if body in ("bird", "winged"):
        return _air_fidget(c, t)
    if body is not None:
        # Bodies without four legs: their idle, a little livelier.
        return idle(c, (t * 2.0) % 1.0)
    p = idle(c, 0.0)
    look = float(keys(t, [(0, 0), (0.16, 1), (0.34, 1), (0.48, -1), (0.6, -1), (0.7, 0), (1, 0)]))
    shake_env = float(keys(t, [(0, 0), (0.66, 0), (0.74, 1), (0.9, 0.35), (1, 0)]))
    shake = math.sin(t * TAU * 8) * shake_env
    p.rot("neck", x=0.12 * abs(look), z=look * 0.4)
    p.rot("head", x=-0.06 * abs(look), y=shake * 0.5, z=look * 0.3 + shake * 0.12)
    p.rot("chest", y=shake * 0.12, z=shake * 0.08)
    p.rot("hips", z=-shake * 0.06)
    for side, sign in (("L", 1), ("R", -1)):
        # Ears perk up to look, then flop about in the shake.
        p.rot("ear." + side, x=-0.25 * abs(look), z=sign * shake * 0.6)
    wag = math.sin(t * TAU * 4) * math.sin(math.pi * t)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.25 * math.sin(math.pi * t), z=wag * (0.3 + 0.15 * i))
    _trunk(p, x=0.4 * abs(look), z=look * 0.4 + shake * 0.3)
    return p


def _air_fidget(c, t):
    """A somersault in the air with the wings tucked, then a flap."""
    hover = c.motion.get("hover_power", 0.55)
    flip = float(keys(t, [(0, 0), (0.15, 0), (0.7, 1), (1, 1)]))
    tuck = math.sin(math.pi * min(1.0, max(0.0, (t - 0.1) / 0.65)))
    p = winged_flap(c, t, power=hover) if c.motion.get("body") == "winged" else bird_flap(c, t, power=hover)
    # Fold the wings in for the flip (undoing the flap as they tuck).
    _wings(p, upper=-0.3 * tuck, lower=-0.6 * tuck, hand=-0.5 * tuck, sweep=0.5 * tuck)
    s = c.motion.get("altitude", 0.5)
    p.move(z=math.sin(math.pi * t) * s * 0.25)
    _spin(c, p, x=-flip * TAU)
    p.rot("neck", x=0.2 * tuck)
    return p


def victory(c, t):
    """A short goofy celebration, looping: bears and others that rear rise up
    on their hind legs waving their paws and roaring; others bounce on the
    spot with their head up and mouth open. Fliers twirl as they flap."""
    body = c.motion.get("body")
    if body in ("bird", "winged"):
        p = winged_flap(c, (t * 2) % 1, power=1.2) if body == "winged" else bird_flap(c, (t * 2) % 1, power=1.2)
        s = c.motion.get("altitude", 0.5)
        p.move(z=math.sin(t * TAU) * s * 0.12)
        _spin(c, p, z=t * TAU)
        p.rot("neck", x=0.25)
        p.rot("head", x=0.2)
        p.rot("jaw", x=-0.3 * max(0.0, math.sin(t * TAU * 2)))
        return p
    if body is not None:
        return idle(c, (t * 3.0) % 1.0)
    p = idle(c, 0.0)
    s = _scale(c)
    cheer = 0.5 - 0.5 * math.cos(t * TAU)
    if c.motion.get("victory", "rear" if c.motion.get("rear", 0.0) >= 0.3 else "hop") == "rear":
        # Up on the hind legs, waving the front paws in turn, roaring.
        _rear(c, p, c.motion.get("victory_rear", 0.75) * float(keys(t, [(0, 0.15), (0.25, 1), (0.75, 1), (1, 0.15)])))
        wave = math.sin(t * TAU * 2)
        for side, sign in (("L", 1), ("R", -1)):
            p.leg("fl." + side, upper=0.7 + 0.45 * wave * sign, lower=-0.7 - 0.3 * wave * sign, foot=-0.3)
            p.leg("hl." + side, upper=-0.3, lower=-0.2, foot=0.35)
        p.rot("neck", x=-0.25)
        p.rot("head", x=0.35)
        p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.4 + 0.6 * cheer))
    else:
        # A happy bounce: crouch, spring up with the legs tucked, land.
        hop = max(0.0, math.sin(t * TAU))
        crouch = max(0.0, -math.sin(t * TAU))
        p.move(z=hop * s * 0.35 - crouch * s * 0.08)
        for side in ("L", "R"):
            p.leg("fl." + side, upper=hop * 0.5 - crouch * 0.2, lower=-hop * 0.7 - crouch * 0.4, foot=-hop * 0.3)
            p.leg("hl." + side, upper=-hop * 0.4 + crouch * 0.3, lower=-hop * 0.3 - crouch * 0.5, foot=hop * 0.4 + crouch * 0.5)
        p.rot("neck", x=-0.1 - 0.2 * hop)
        p.rot("head", x=0.25 * hop)
        p.rot("jaw", x=-c.motion.get("gape", 0.5) * 0.7 * hop)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, x=-0.2, z=sign * 0.2 * cheer)
    wag = math.sin(t * TAU * 3)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.35, z=wag * (0.3 + 0.15 * i))
    _trunk(p, x=1.0 * cheer, z=0.2 * wag)
    return p


def slam(c, t):
    """A big slow body slam: rear right up with both front paws high, hang
    there a moment, then crash down on the target."""
    p = Pose()
    s = _scale(c)
    rise = float(keys(t, [(0, 0), (0.3, 1), (0.42, 1.05), (0.55, -0.12), (0.72, 0), (1, 0)]))
    _rear(c, p, rise * c.motion.get("rear", 0.3) * 1.7)
    drive = float(keys(t, [(0, 0), (0.42, 0), (0.55, 1), (0.72, 0.6), (1, 0)]))
    p.move(y=drive * s * 0.25, z=-max(-rise, 0.0) * s * 0.06)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=0.9 * max(rise, 0.0) + 0.3 * drive, lower=-0.8 * max(rise, 0.0), foot=-0.3 * max(rise, 0.0))
        p.leg("hl." + side, upper=-0.3 * max(rise, 0.0), lower=-0.25 * max(rise, 0.0), foot=0.35 * max(rise, 0.0))
        p.rot("ear." + side, x=-0.4 * abs(rise))
    p.rot("neck", x=-0.3 * max(rise, 0.0) - 0.3 * drive)
    p.rot("head", x=-0.15 * drive)
    p.rot("jaw", x=-0.4 * c.motion.get("gape", 0.5) * max(rise, 0.0))
    _trunk(p, x=1.1 * max(rise, 0.0) - 0.5 * drive)
    return p


def rake(c, t):
    """A bird's talon rake: brake in the air with the wings flared, swing the
    feet forward, claws out, then beat back."""
    p = bird_flap(c, 0.0, power=c.motion.get("hover_power", 0.55))
    flare = float(keys(t, [(0, 0), (0.3, 1), (0.55, 1), (0.8, 0.3), (1, 0)]))
    claws = float(keys(t, [(0, 0), (0.3, 0.2), (0.5, 1), (0.7, 0.4), (1, 0)]))
    s = c.motion.get("altitude", 0.5)
    p.move(y=claws * s * 0.35, z=-claws * s * 0.3)
    p["root_rot"] = (flare * 0.55, 0.0, 0.0)
    _wings(p, upper=flare * 0.9, lower=flare * 0.3, hand=flare * 0.2, sweep=-flare * 0.2)
    for side in ("L", "R"):
        p.rot("leg." + side, x=claws * 1.9)
    p.rot("neck", x=-flare * 0.3)
    p.rot("jaw", x=-claws * 0.35)
    return p


def attack2(c, t):
    """The second attack (common animals alternate two)."""
    return ATTACKS[c.motion["attack2"]](c, t)


ATTACKS.update({"slam": slam, "rake": rake})
HIT_AT.update({"slam": 0.55, "rake": 0.5})


def death(c, t):
    """Topple onto the side; legs go limp. The roll pivots under the spine, so
    the body swings out sideways: shift it back over the spot where it stood.
    rest_on_ground then lifts it onto the ground."""
    if c.motion.get("body") in ("bird", "winged"):
        return bird_fall(c, t)
    if c.motion.get("body") == "insect":
        return insect_fall(c, t)
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
    "fidget": (fidget, 10, 10, False),
    "victory": (victory, 10, 10, True),
    # Only for animals with a second attack (motion["attack2"]).
    "attack2": (attack2, 10, 16, False),
}


def animations_for(c):
    """The animations this creature has: attack2 only with a second attack."""
    return {name: spec for name, spec in ANIMATIONS.items() if name != "attack2" or c.motion.get("attack2")}


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
