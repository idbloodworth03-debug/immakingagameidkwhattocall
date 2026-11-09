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
    persona = PERSONAS.get(c.motion.get("persona"), {})
    if "idle" in persona:
        return persona["idle"](c, t)
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
    persona = PERSONAS.get(c.motion.get("persona"), {})
    if "fidget" in persona:
        return persona["fidget"](c, t)
    body = c.motion.get("body")
    if body in ("bird", "winged", "insect"):
        return _air_fidget(c, t)
    if body in BODY_FIDGET:
        return BODY_FIDGET[body](c, t)
    p = idle(c, 0.0)
    if c.motion.get("gait") == "biped":
        # Upright animals scratch their head with a hand as they look about.
        scratch = float(keys(t, [(0, 0), (0.2, 1), (0.75, 1), (0.9, 0), (1, 0)]))
        rub = math.sin(t * TAU * 6) * scratch
        p.leg("fl.R", upper=1.9 * scratch, lower=-1.6 * scratch - 0.25 * rub, foot=-0.4 * scratch)
        p.rot("head", z=-0.2 * scratch, x=0.1 * scratch)
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
    if c.motion.get("body") == "insect":
        p = insect_idle(c, t)
        _spin(c, p, x=-flip * TAU)
        return p
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
    persona = PERSONAS.get(c.motion.get("persona"), {})
    if "victory" in persona:
        return persona["victory"](c, t)
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


def _fish_fidget(c, t):
    """A fish out of water: two big flops on the spot."""
    p = fish_hop(c, (t * 2.0) % 1.0)
    p.move(y=-p.get("root_loc", (0.0, 0.0, 0.0))[1])
    return p


def _cetacean_fidget(c, t):
    """A whale or dolphin lifts its tail high and waves it, flippers flapping."""
    p = cetacean_idle(c, 0.0)
    lift = math.sin(math.pi * t)
    wave = math.sin(t * TAU * 3) * lift
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-lift * (0.25 + 0.15 * i), z=wave * (0.15 + 0.1 * i))
    for side in ("L", "R"):
        p.rot("pect." + side, x=0.6 * wave)
    p.rot("head", x=0.2 * lift)
    return p


def _crustacean_fidget(c, t):
    """A shrimp waves both claws over its head and clicks them."""
    p = crustacean_idle(c, 0.0)
    up = math.sin(math.pi * t)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("claw_arm." + side, x=0.7 * up, z=sign * 0.25 * math.sin(t * TAU * 3) * up)
        p.rot("claw_finger." + side, x=0.5 * max(0.0, math.sin(t * TAU * 4)))
    return p


def _serpent_fidget(c, t):
    """A snake looks one way and the other, flicking its tongue."""
    p = serpent_idle(c, 0.0)
    look = float(keys(t, [(0, 0), (0.2, 1), (0.45, 1), (0.6, -1), (0.85, -1), (1, 0)]))
    p.rot("neck", z=look * 0.35)
    p.rot("head", z=look * 0.25)
    p.rot("jaw", x=-0.25 * max(0.0, math.sin(t * TAU * 5)))
    return p


def _frog_fidget(c, t):
    """A frog hops on the spot."""
    p = frog_hop(c, t)
    p.move(y=-p.get("root_loc", (0.0, 0.0, 0.0))[1])
    return p


def _pinniped_fidget(c, t):
    """A seal tosses its head back and claps its front flippers."""
    p = pinniped_idle(c, 0.0)
    toss = math.sin(math.pi * t)
    clap = max(0.0, math.sin(t * TAU * 3)) * toss
    p.rot("neck", x=0.35 * toss)
    p.rot("head", x=0.3 * toss)
    p.rot("jaw", x=-0.3 * clap)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.5 * toss, splay=-sign * 0.5 * clap)
    return p


BODY_FIDGET = {"fish": _fish_fidget, "cetacean": _cetacean_fidget, "crustacean": _crustacean_fidget,
               "serpent": _serpent_fidget, "frog": _frog_fidget, "pinniped": _pinniped_fidget}


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


def lob(c, t):
    """Sit up and throw with both front paws from over the head."""
    p = Pose()
    sit = float(keys(t, [(0, 0), (0.25, 1), (0.75, 1), (1, 0)]))
    arm = float(keys(t, [(0, 0), (0.32, -1), (0.5, 1), (0.66, 0.5), (1, 0)]))
    _rear(c, p, sit * c.motion.get("rear", 0.6))
    for side in ("L", "R"):
        p.leg("hl." + side, upper=-0.5 * sit, lower=-0.4 * sit, foot=0.8 * sit)
        p.leg("fl." + side, upper=0.5 * sit + 1.1 * max(-arm, 0.0) + 0.6 * max(arm, 0.0), lower=-0.8 * sit + 0.5 * max(arm, 0.0))
    p.rot("neck", x=-0.4 * sit + 0.2 * max(-arm, 0.0))
    p.rot("head", x=0.15 * max(-arm, 0.0) - 0.15 * max(arm, 0.0))
    _tail(p, 0.0, sway=0.0, droop=-0.4 * sit)
    return p


def handstand(c, t):
    """Up onto the front paws, tail high, back end aimed at the target (a
    skunk's warning)."""
    p = Pose()
    up = float(keys(t, [(0, 0), (0.35, 1), (0.6, 1), (1, 0)]))
    toe_y = c.joints["front_toe.L"][1] - c.joints["root"][1]
    angle = -up * 0.6
    p.move(y=toe_y * (1 - math.cos(angle)), z=-toe_y * math.sin(angle))
    rr = p.get("root_rot", (0.0, 0.0, 0.0))
    p["root_rot"] = (rr[0] + angle, rr[1], rr[2])
    puff = float(keys(t, [(0, 0), (0.45, 0), (0.5, 1), (0.7, 0.4), (1, 0)]))
    for side in ("L", "R"):
        p.leg("hl." + side, upper=0.4 * up, lower=0.3 * up)
        p.leg("fl." + side, upper=-0.2 * up)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-(0.5 + 0.3 * puff) * up, z=0.15 * puff * math.sin(t * TAU * 4 + i))
    p.rot("neck", x=0.35 * up)
    return p


def leap(c, t):
    """A frog's pounce: crouch, spring onto the target and land."""
    p = frog_hop(c, t)
    s = _size(c)
    reach = float(keys(t, [(0, 0), (0.25, 0), (0.5, 1), (0.7, 0.6), (1, 0)]))
    p.move(y=reach * s * 0.25 - p.get("root_loc", (0.0, 0.0, 0.0))[1])
    p.rot("jaw", x=-0.4 * reach)
    return p


def tail_slap(c, t):
    """Fish, whales and dolphins: curl the tail up and slap it down on the target."""
    p = BODY_IDLE.get(c.motion.get("body"), idle)(c, 0.0)
    curl = float(keys(t, [(0, 0), (0.35, 1), (0.5, -0.8), (0.7, -0.2), (1, 0)]))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-curl * (0.35 + 0.2 * i))
    p.rot("chest", x=0.1 * curl)
    p.rot("head", x=0.15 * curl)
    p.move(z=max(curl, 0.0) * _size(c) * 0.04)
    return p


def ram(c, t):
    """Any body: draw back, then lunge headfirst into the target."""
    idle_fn = BODY_IDLE.get(c.motion.get("body"), idle)
    p = idle_fn(c, 0.0)
    s = _size(c)
    drive = float(keys(t, [(0, 0), (0.3, -0.35), (0.45, 1), (0.6, 0.8), (1, 0)]))
    p.move(y=drive * s * 0.18)
    p.rot("neck", x=-0.3 * max(drive, 0.0) + 0.2 * max(-drive, 0.0))
    p.rot("head", x=-0.2 * max(drive, 0.0))
    p.rot("jaw", x=-0.35 * max(drive, 0.0))
    return p


def special(c, t):
    """A Stun animal's big wind-up before the blow that stuns: primates beat
    their chest and roar, snakes rear up and hiss with the tail rattling,
    others rear and roar. The blow lands late (HIT_AT "special")."""
    body = c.motion.get("body")
    strike = float(keys(t, [(0, 0), (0.62, 0), (0.72, 1), (0.85, 0.5), (1, 0)]))
    show = float(keys(t, [(0, 0), (0.12, 1), (0.6, 1), (0.72, 0), (1, 0)]))
    if body == "serpent":
        p = serpent_idle(c, 0.0)
        p.rot("neck", x=0.5 * show - 0.6 * strike, z=0.15 * show * math.sin(t * TAU * 3))
        p.rot("head", x=-0.2 * show + 0.1 * strike)
        p.rot("jaw", x=-0.6 * max(show, strike))
        for i, bone in enumerate(("tail1", "tail2", "tail3")):
            p.rot(bone, x=-0.4 * show, z=0.25 * show * math.sin(t * TAU * 10 + i))
        p.move(y=strike * _size(c) * 0.12)
        return p
    if body is not None:
        return ram(c, t)
    p = idle(c, 0.0)
    if c.motion.get("gait") == "biped":
        beat = math.sin(t * TAU * 5) * show
        for side, sign in (("L", 1), ("R", -1)):
            # Fists pound the chest in turn, then both swing down on the target.
            p.leg("fl." + side, upper=1.1 * show + 0.35 * sign * beat + 0.9 * strike, lower=-1.5 * show + 0.6 * strike, foot=-0.3 * show)
        p.rot("chest", x=-0.1 * show, y=0.08 * beat)
    else:
        _rear(c, p, 0.25 * show)
        for side in ("L", "R"):
            p.leg("fl." + side, upper=0.3 * show + 0.5 * strike, lower=-0.4 * show)
    p.rot("neck", x=-0.3 * show)
    p.rot("head", x=0.35 * show - 0.2 * strike)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.9 * show + 0.4 * strike))
    p.move(y=strike * _scale(c) * 0.2)
    return p


def attack2(c, t):
    """The second attack (common animals alternate two)."""
    return ATTACKS[c.motion["attack2"]](c, t)


# --- Personality (the movie look, docs/ART_DIRECTION.md): an animal's own
# idle, fidget and victory, and attacks built for it. Animation principles:
# anticipation (a clear wind-up, held a beat), timing and weight (a big
# animal moves slowly into things and fast out of them), follow-through
# (the head and arms carry on past the stop and settle), arcs, controlled
# squash and stretch. movie.json "motion" picks these (persona, attack).

def pound(c, t):
    """The Yeti's ground pound (upright). Anticipation: it rocks back onto
    its heels and hauls both fists up over its head, slowing as they reach
    the top (a beat of hang time, roaring). Then it drops: the whole body
    pitches forward and down, knees bending, and both fists slam the ground
    together (HIT_AT), squashing low. Follow-through: the head and shoulders
    carry on down and bounce back, the fists lift off the ground a little,
    and it settles upright."""
    p = Pose()
    s = _scale(c)
    rise = float(keys(t, [(0, 0), (0.3, 0.8), (0.5, 1.0), (0.6, -0.3), (0.72, -0.14), (0.86, 0.03), (1, 0)]))
    up = max(rise, 0.0)
    crouch = max(-rise, 0.0) / 0.3
    # After the slam: the head and arms overshoot and come back.
    settle = float(keys(t, [(0, 0), (0.6, 0), (0.68, 1), (0.8, -0.35), (0.92, 0.1), (1, 0)]))
    # Rock back onto the heels, then pitch forward over the fists.
    _rear(c, p, 0.14 * up - 0.3 * crouch)
    p.move(z=s * (0.05 * up - 0.3 * crouch), y=s * 0.1 * crouch)
    for side in ("L", "R"):
        # Arms: straight down at rest; overhead (elbows a little bent, fists
        # curled) at the top; forward and down onto the ground on the slam.
        p.leg("fl." + side, upper=3.0 * up + 0.85 * crouch + 0.35 * settle, lower=-0.45 * up - 0.1 * crouch,
              foot=-0.5 * up + 0.3 * crouch)
        # Legs straighten up onto the toes, then bend to take the landing.
        p.leg("hl." + side, upper=-0.08 * up + 0.5 * crouch, lower=0.05 * up - 0.65 * crouch, foot=0.4 * crouch)
    p.rot("chest", x=0.12 * up - 0.4 * crouch - 0.08 * settle)
    p.rot("hips", x=-0.15 * crouch)
    p.rot("neck", x=0.1 * up - 0.15 * crouch)
    # Looks up roaring at the top; the head drives down with the slam and
    # overshoots.
    p.rot("head", x=0.3 * up - 0.3 * crouch - 0.25 * settle)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.8 * up + 0.5 * crouch))
    return p


def yeti_idle(c, t):
    """Big and heavy: slow deep breaths that lift the shoulders, a slow sway
    from foot to foot with the long arms swinging a little late, a slow look
    about, a huff at the end of each breath."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    sway = math.sin(t * TAU + 0.6)
    p.move(z=s * 0.009 * breath)
    p.rot("chest", x=0.035 * breath, z=0.04 * sway)
    p.rot("hips", z=-0.02 * sway)
    for side, sign in (("L", 1), ("R", -1)):
        # The shoulders rise with the breath; the arms hang and swing a
        # little behind the sway (overlap), elbows soft.
        p.leg("fl." + side, upper=0.05 * breath + 0.03 * math.sin(t * TAU - 0.8), lower=-0.12, foot=-0.1,
              splay=sign * 0.03 * sway)
    look = math.sin(t * TAU) * 0.14
    p.rot("neck", x=0.03 + 0.02 * math.cos(t * TAU * 2), z=look * 0.5)
    p.rot("head", z=look * 0.4, x=-0.03 * breath)
    p.rot("jaw", x=-0.06 * max(0.0, -breath))
    return p


def yeti_fidget(c, t):
    """Shakes the snow off (a quick shiver with the arms held out, head
    flopping), then a huge slow stretch and yawn, arms up, back arched,
    up on the toes, and settles back into the idle."""
    p = yeti_idle(c, 0.0)
    s = _scale(c)
    shiver_env = float(keys(t, [(0, 0), (0.07, 1), (0.28, 1), (0.36, 0), (1, 0)]))
    shiver = math.sin(t * TAU * 7) * shiver_env
    stretch = float(keys(t, [(0, 0), (0.36, 0), (0.55, 1), (0.74, 1), (0.92, 0), (1, 0)]))
    p.rot("chest", y=0.12 * shiver, z=0.08 * shiver, x=0.14 * stretch)
    p.rot("hips", z=-0.06 * shiver)
    p.rot("neck", y=0.1 * shiver, x=0.12 * stretch)
    p.rot("head", y=0.25 * shiver, z=0.1 * shiver, x=0.3 * stretch)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.35 * shiver_env + 2.5 * stretch, lower=-0.6 * shiver_env - 0.45 * stretch,
              foot=-0.3 * stretch, splay=sign * 0.4 * shiver_env)
        p.leg("hl." + side, upper=-0.08 * stretch, lower=0.05 * stretch)
    p.move(z=s * 0.045 * stretch)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.2 * shiver_env + 0.9 * stretch))
    return p


def yeti_victory(c, t):
    """Proud and goofy, looping: it beats its chest with alternating fists,
    then flings both arms up with a roar and a little hop, lands, and starts
    again."""
    p = yeti_idle(c, 0.0)
    s = _scale(c)
    beat = math.sin(t * TAU * 4)
    beating = float(keys(t, [(0, 1), (0.42, 1), (0.52, 0), (1, 0)]))
    up = float(keys(t, [(0, 0), (0.44, 0), (0.58, 1), (0.86, 1), (1, 0)]))
    hop = max(0.0, math.sin(max(0.0, (t - 0.5)) * TAU)) if t >= 0.5 else 0.0
    for side, sign in (("L", 1), ("R", -1)):
        chest = 1.15 + 0.4 * beat * sign
        p.leg("fl." + side, upper=chest * beating + 2.75 * up, lower=-1.5 * beating - 0.4 * up, foot=-0.3,
              splay=sign * 0.25 * up)
        p.leg("hl." + side, upper=-0.3 * hop, lower=-0.35 * hop, foot=0.4 * hop)
    p.rot("chest", x=-0.06 * beating + 0.1 * up, y=0.06 * beat * beating)
    p.rot("neck", x=-0.1 * beating + 0.05 * up)
    p.rot("head", x=0.25 * beating + 0.4 * up, y=0.05 * beat * beating)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.45 * beating + 0.95 * up))
    p.move(z=s * 0.32 * hop)
    return p



# --- The Tanks' personas (docs/ART_DIRECTION.md, animation) ----------------------------

def bear_idle(c, t):
    """Big and unhurried: slow deep breaths, the head hung low and swinging
    from side to side the way a bear's does, a sniff up at the air at the
    top of each swing, the weight rolling from paw to paw."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    swing = math.sin(t * TAU + 0.5)
    p.move(z=s * 0.008 * breath)
    p.rot("chest", x=0.03 * breath, z=0.035 * swing)
    p.rot("hips", z=-0.02 * swing)
    # The head hangs low and swings wide; it lifts to sniff as it passes the middle.
    sniff = max(0.0, math.cos(t * TAU * 2)) ** 3
    p.rot("neck", x=-0.12 + 0.08 * sniff, z=0.22 * swing)
    p.rot("head", x=-0.05 + 0.22 * sniff, z=0.15 * swing)
    p.rot("jaw", x=-0.05 * sniff)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.03 * sign * swing, lower=-0.02 * sign * swing)
        p.rot("ear." + side, z=sign * 0.1 * max(0.0, math.sin(t * TAU * 2 + sign)))
    _tail(p, t, sway=0.1)
    return p


def bear_fidget(c, t):
    """Sits back on its haunches, scratches its belly with a front paw in
    big lazy circles while it looks about, then rocks forward back onto
    all fours with a shake."""
    p = bear_idle(c, 0.0)
    s = _scale(c)
    sit = float(keys(t, [(0, 0), (0.18, 1), (0.74, 1), (0.9, 0), (1, 0)]))
    scratch = float(keys(t, [(0, 0), (0.25, 1), (0.68, 1), (0.8, 0), (1, 0)]))
    rub = math.sin(t * TAU * 5) * scratch
    shake = math.sin(t * TAU * 9) * float(keys(t, [(0, 0), (0.84, 0), (0.9, 1), (0.98, 0), (1, 0)]))
    _rear(c, p, 0.55 * sit)
    p.move(z=-s * 0.22 * sit)
    for side, sign in (("L", 1), ("R", -1)):
        # Hind legs fold under it; the left paw rests, the right one scratches.
        p.leg("hl." + side, upper=0.9 * sit, lower=-1.3 * sit, foot=0.6 * sit)
        if side == "R":
            p.leg("fl.R", upper=1.1 * sit + 0.15 * rub, lower=-1.5 * sit - 0.25 * rub, foot=-0.3 * sit, splay=-0.25 * sit)
        else:
            p.leg("fl.L", upper=0.5 * sit, lower=-0.6 * sit, foot=-0.2 * sit, splay=0.2 * sit)
    look = math.sin(t * TAU * 1.5) * scratch
    p.rot("chest", x=0.1 * sit, y=0.1 * shake)
    p.rot("neck", x=0.2 * sit, z=0.3 * look)
    p.rot("head", x=0.15 * sit, z=0.2 * look, y=0.3 * shake)
    p.rot("jaw", x=-0.12 * scratch * max(0.0, math.sin(t * TAU * 2.5)))
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.5 * shake)
    return p


def bear_victory(c, t):
    """Rears up to its full height roaring, boxing the air with alternating
    paws, then drops back down onto all fours with a thump that bounces it,
    and rises again."""
    p = bear_idle(c, 0.0)
    s = _scale(c)
    up = float(keys(t, [(0, 0), (0.18, 1), (0.6, 1), (0.72, 0), (0.78, 0.08), (0.86, 0), (1, 0)]))
    box = math.sin(t * TAU * 3) * float(keys(t, [(0, 0), (0.2, 1), (0.6, 1), (0.7, 0), (1, 0)]))
    thump = float(keys(t, [(0, 0), (0.68, 0), (0.74, 1), (0.82, -0.3), (0.9, 0), (1, 0)]))
    _rear(c, p, c.motion.get("victory_rear", 0.95) * up)
    p.move(z=-s * 0.08 * max(thump, 0.0))
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=1.0 * up + 0.5 * box * sign, lower=-0.9 * up - 0.4 * box * sign, foot=-0.35 * up,
              splay=sign * 0.15 * up)
        p.leg("hl." + side, upper=-0.25 * up + 0.3 * max(thump, 0.0), lower=-0.2 * up - 0.4 * max(thump, 0.0), foot=0.35 * up)
    p.rot("chest", x=-0.08 * up - 0.15 * max(thump, 0.0))
    p.rot("neck", x=-0.2 * up + 0.1 * thump)
    p.rot("head", x=0.45 * up - 0.2 * thump, y=0.08 * box)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.9 * up))
    return p


def panda_idle(c, t):
    """Lazy and round: a slow tummy breath that rocks it back a little, the
    head tipping from side to side as if it's dozing off, ears wiggling, a
    slow blink-and-chew at the bottom of each breath."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    tip = math.sin(t * TAU * 0.5 + 1.0) if t < 1.0 else math.sin(1.0)
    tip = math.sin(t * TAU + 1.0)
    p.move(z=s * 0.006 * breath)
    p.rot("chest", x=0.05 * breath)
    p.rot("hips", x=-0.02 * breath)
    p.rot("neck", x=0.05 - 0.04 * breath, z=0.08 * tip)
    p.rot("head", z=0.18 * tip, x=-0.08 * max(0.0, -breath))
    chew = max(0.0, math.sin(t * TAU * 3)) * max(0.0, -breath)
    p.rot("jaw", x=-0.12 * chew)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.12 * max(0.0, math.sin(t * TAU * 2 + sign * 0.7)))
        p.leg("fl." + side, upper=0.02 * breath)
    _tail(p, t, sway=0.05)
    return p


def panda_fidget(c, t):
    """Plops down onto its bottom, rubs its tummy with both paws, rolls
    back onto its back with its legs in the air kicking, then rolls forward
    and heaves itself back up."""
    p = panda_idle(c, 0.0)
    s = _scale(c)
    sit = float(keys(t, [(0, 0), (0.14, 1.1), (0.2, 1), (0.8, 1), (0.92, 0), (1, 0)]))
    roll = float(keys(t, [(0, 0), (0.4, 0), (0.52, 1), (0.68, 1), (0.8, 0), (1, 0)]))
    rub = math.sin(t * TAU * 4) * float(keys(t, [(0, 0), (0.2, 1), (0.42, 1), (0.5, 0), (1, 0)]))
    kick = math.sin(t * TAU * 6) * roll
    # Leaning right back on its rump for the roll (a full roll would stand
    # the barrel on end).
    _rear(c, p, 0.55 * sit + 0.35 * roll)
    p.move(z=-s * 0.3 * sit)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.9 * sit - 0.3 * roll + 0.3 * kick * sign, lower=-1.2 * sit + 0.4 * roll, foot=0.5 * sit)
        p.leg("fl." + side, upper=1.1 * sit + 0.2 * rub * sign + 0.6 * roll, lower=-1.6 * sit + 0.3 * roll - 0.2 * rub * sign,
              foot=-0.3 * sit, splay=sign * (0.15 * sit + 0.3 * roll))
    p.rot("chest", x=0.1 * sit)
    p.rot("neck", x=0.25 * sit - 0.2 * roll)
    p.rot("head", x=0.2 * sit + 0.1 * kick, z=0.1 * rub)
    p.rot("jaw", x=-0.25 * roll * max(0.0, math.sin(t * TAU * 2)))
    return p


def panda_victory(c, t):
    """Sits up and claps its front paws together over its head, bouncing on
    its bottom with its head wobbling and its mouth open, happy."""
    p = panda_idle(c, 0.0)
    s = _scale(c)
    sit = float(keys(t, [(0, 0.85), (0.1, 1), (0.9, 1), (1, 0.85)]))
    clap = math.sin(t * TAU * 3)
    bounce = max(0.0, math.sin(t * TAU * 3))
    _rear(c, p, 0.7 * sit)
    p.move(z=-s * 0.26 * sit + s * 0.07 * bounce)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.95 * sit, lower=-1.25 * sit, foot=0.55 * sit)
        # Paws up overhead, meeting and parting.
        p.leg("fl." + side, upper=2.4 * sit, lower=-0.5 * sit - 0.2 * bounce, foot=-0.3,
              splay=sign * (0.45 - 0.4 * (0.5 + 0.5 * clap)) * sit)
    p.rot("chest", x=0.05 * sit, z=0.05 * clap)
    p.rot("neck", x=0.2 * sit)
    p.rot("head", x=0.2 * sit, z=0.2 * clap)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.5 + 0.3 * bounce))
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.25 * bounce)
    return p


def hippo_idle(c, t):
    """Heavy and placid: a slow deep breath that lifts the whole barrel, the
    tiny ears flicking, the tail flicking, the jaw working as if chewing,
    the head drifting low from side to side."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    drift = math.sin(t * TAU + 0.8)
    p.move(z=s * 0.012 * breath)
    p.rot("chest", x=0.025 * breath)
    p.rot("neck", x=-0.04 + 0.02 * breath, z=0.1 * drift)
    p.rot("head", x=0.02 * breath, z=0.08 * drift)
    chew = max(0.0, math.sin(t * TAU * 2 + 0.4))
    p.rot("jaw", x=-0.1 * chew)
    for side, sign in (("L", 1), ("R", -1)):
        flick = max(0.0, math.sin(t * TAU * 3 + sign * 1.2)) ** 4
        p.rot("ear." + side, z=sign * 0.5 * flick, x=-0.2 * flick)
    _tail(p, t, sway=0.3, speed=2)
    return p


def hippo_fidget(c, t):
    """The famous yawn: the head lifts and the jaw swings open wider and
    wider, holds there a long beat, then snaps shut with a head shake that
    flaps the ears."""
    p = hippo_idle(c, 0.0)
    gape = c.motion.get("gape", 1.1)
    yawn = float(keys(t, [(0, 0), (0.12, 0.35), (0.34, 1), (0.66, 1), (0.76, 0), (1, 0)]))
    lift = float(keys(t, [(0, 0), (0.3, 1), (0.66, 1), (0.8, 0), (1, 0)]))
    shake = math.sin(t * TAU * 10) * float(keys(t, [(0, 0), (0.74, 0), (0.8, 1), (0.94, 0), (1, 0)]))
    p.rot("neck", x=0.25 * lift)
    p.rot("head", x=0.3 * lift, y=0.25 * shake, z=0.1 * shake)
    p.rot("jaw", x=-gape * yawn)
    p.rot("chest", x=0.05 * lift, y=0.05 * shake)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * (0.3 * lift + 0.6 * shake), x=-0.3 * lift)
        p.leg("fl." + side, upper=-0.08 * lift, lower=0.06 * lift)
    return p


def hippo_victory(c, t):
    """Stamps its front feet in turn with its mouth gaping in a roar, its
    bottom wiggling and its stubby tail whirring."""
    p = hippo_idle(c, 0.0)
    s = _scale(c)
    gape = c.motion.get("gape", 1.1)
    stamp = math.sin(t * TAU * 2)
    wiggle = math.sin(t * TAU * 4)
    p.move(z=s * 0.03 * abs(stamp))
    for side, sign in (("L", 1), ("R", -1)):
        lift = max(0.0, stamp * sign)
        p.leg("fl." + side, upper=0.6 * lift, lower=-0.7 * lift, foot=-0.2 * lift)
        p.rot("ear." + side, z=sign * 0.4 * abs(wiggle), x=-0.3)
    p.rot("hips", z=0.08 * wiggle, y=0.04 * wiggle)
    p.rot("chest", x=0.06, z=-0.04 * wiggle)
    p.rot("neck", x=0.3)
    p.rot("head", x=0.25, z=0.05 * stamp)
    p.rot("jaw", x=-gape * (0.75 + 0.25 * math.sin(t * TAU * 2)))
    _tail(p, t, sway=0.5, speed=6)
    return p


def elephant_idle(c, t):
    """Stately: a slow weight shift from side to side, the great ears
    flapping slowly to keep cool, the trunk swinging and curling, the head
    nodding a little with each step of the sway."""
    p = Pose()
    s = _scale(c)
    sway = math.sin(t * TAU)
    breath = math.sin(t * TAU * 2)
    p.move(z=s * 0.004 * breath)
    p.rot("chest", z=0.025 * sway, x=0.012 * breath)
    p.rot("hips", z=-0.015 * sway)
    p.rot("neck", x=0.02 * breath, z=0.05 * sway)
    p.rot("head", x=-0.04 * sway * sway, z=0.04 * sway)
    for side, sign in (("L", 1), ("R", -1)):
        flap = 0.5 + 0.5 * math.sin(t * TAU + sign * 0.6)
        p.rot("ear." + side, z=sign * 0.35 * flap, x=-0.1 * flap)
        p.leg("fl." + side, upper=0.02 * sign * sway)
    _trunk(p, x=0.25 + 0.3 * math.sin(t * TAU * 2 + 1.0), z=0.35 * math.sin(t * TAU))
    _tail(p, t, sway=0.25, speed=2)
    return p


def elephant_fidget(c, t):
    """Trumpets: the head comes up, the ears flare wide, the trunk reaches
    up and curls back over the forehead, and a front foot lifts and stamps
    down as the call ends."""
    p = elephant_idle(c, 0.0)
    s = _scale(c)
    up = float(keys(t, [(0, 0), (0.25, 1), (0.62, 1), (0.8, 0), (1, 0)]))
    stamp = float(keys(t, [(0, 0), (0.3, 0), (0.45, 1), (0.6, 1), (0.66, -0.15), (0.72, 0), (1, 0)]))
    p.rot("neck", x=0.3 * up)
    p.rot("head", x=0.35 * up)
    p.rot("chest", x=0.06 * up)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.9 * up, x=-0.35 * up)
    p.leg("fl.R", upper=0.8 * max(stamp, 0.0), lower=-0.9 * max(stamp, 0.0), foot=-0.3 * max(stamp, 0.0))
    p.move(z=-s * 0.03 * max(-stamp, 0.0) * 4.0)
    _trunk(p, x=2.2 * up, z=0.15 * math.sin(t * TAU * 4) * up)
    p.rot("jaw", x=-0.35 * up)
    return p


def elephant_victory(c, t):
    """Rears up a little with the trunk straight up in the air, ears flared,
    trumpeting, then comes down with a stamp and a bounce, and up again."""
    p = elephant_idle(c, 0.0)
    s = _scale(c)
    up = float(keys(t, [(0, 0), (0.22, 1), (0.58, 1), (0.7, 0), (0.76, 0.06), (0.84, 0), (1, 0)]))
    land = float(keys(t, [(0, 0), (0.66, 0), (0.72, 1), (0.8, -0.2), (0.88, 0), (1, 0)]))
    _rear(c, p, c.motion.get("victory_rear", 0.4) * up)
    p.move(z=-s * 0.06 * max(land, 0.0))
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.7 * up + 0.2 * math.sin(t * TAU * 3) * sign * up, lower=-0.6 * up, foot=-0.2 * up)
        p.leg("hl." + side, upper=-0.2 * up + 0.25 * max(land, 0.0), lower=-0.15 * up - 0.3 * max(land, 0.0), foot=0.3 * up)
        p.rot("ear." + side, z=sign * 0.85 * up, x=-0.3 * up)
    p.rot("neck", x=0.15 * up - 0.1 * land)
    p.rot("head", x=0.3 * up - 0.15 * land)
    p.rot("jaw", x=-0.4 * up)
    _trunk(p, x=2.4 * up, z=0.2 * math.sin(t * TAU * 5) * up)
    _tail(p, t, sway=0.3, speed=3)
    return p


def rhino_idle(c, t):
    """Grumpy and solid: the head held low swinging its horn a little, a
    front hoof scraping at the ground now and then, ears swivelling, the
    tail flicking at flies."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    swing = math.sin(t * TAU + 0.4)
    p.move(z=s * 0.006 * breath)
    p.rot("chest", x=0.02 * breath)
    p.rot("neck", x=-0.1, z=0.1 * swing)
    p.rot("head", x=-0.05 + 0.03 * breath, z=0.08 * swing)
    scrape = max(0.0, math.sin(t * TAU * 2 - 0.5)) ** 2
    p.leg("fl.R", upper=0.18 * scrape, lower=-0.25 * scrape, foot=0.15 * scrape)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.25 * max(0.0, math.sin(t * TAU * 3 + sign * 0.9)) ** 3)
    _tail(p, t, sway=0.35, speed=3)
    return p


def rhino_fidget(c, t):
    """Paws the ground three times with a front hoof, snorts twice with the
    head jerking up and the ears pinning back, then shakes its head."""
    p = rhino_idle(c, 0.0)
    s = _scale(c)
    paw_env = float(keys(t, [(0, 0), (0.08, 1), (0.5, 1), (0.58, 0), (1, 0)]))
    paw = math.sin(t * TAU * 6) * paw_env
    snort = float(keys(t, [(0, 0), (0.55, 0), (0.6, 1), (0.66, 0.2), (0.72, 1), (0.8, 0), (1, 0)]))
    shake = math.sin(t * TAU * 9) * float(keys(t, [(0, 0), (0.82, 0), (0.88, 1), (0.98, 0), (1, 0)]))
    p.leg("fl.R", upper=0.35 * paw_env + 0.3 * paw, lower=-0.45 * paw_env - 0.3 * paw, foot=0.2 * paw_env + 0.3 * paw)
    p.rot("chest", x=-0.03 * paw_env + 0.05 * snort)
    p.rot("neck", x=-0.1 * paw_env + 0.35 * snort, z=0.0)
    p.rot("head", x=-0.1 * paw_env + 0.3 * snort, y=0.3 * shake, z=0.1 * shake)
    p.rot("jaw", x=-0.15 * snort)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, x=0.5 * snort, z=sign * 0.5 * shake)
    p.move(z=-s * 0.01 * paw_env)
    return p


def rhino_victory(c, t):
    """Tosses its horn up and hops, both front legs kicking out, the tail
    straight up, with a snort at the top of each hop."""
    p = rhino_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 2))
    crouch = max(0.0, -math.sin(t * TAU * 2))
    toss = float(keys(t, [(0, 0), (0.2, 1), (0.45, 0.2), (0.7, 1), (0.95, 0.2), (1, 0)]))
    p.move(z=s * 0.25 * hop - s * 0.06 * crouch)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.6 * hop - 0.15 * crouch, lower=-0.4 * hop - 0.3 * crouch, foot=-0.3 * hop, splay=sign * 0.1 * hop)
        p.leg("hl." + side, upper=-0.3 * hop + 0.3 * crouch, lower=-0.25 * hop - 0.45 * crouch, foot=0.35 * hop + 0.4 * crouch)
        p.rot("ear." + side, x=-0.3 * toss, z=sign * 0.2 * hop)
    p.rot("chest", x=0.1 * hop - 0.08 * crouch)
    p.rot("neck", x=0.3 * toss + 0.1 * hop)
    p.rot("head", x=0.35 * toss)
    p.rot("jaw", x=-0.2 * toss)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.6, z=0.3 * math.sin(t * TAU * 4 - i))
    return p


def turtle_idle(c, t):
    """Slow and ancient: the head creeping out of the shell and back in, a
    slow look from side to side, the feet shifting under the shell, the
    beak opening a crack and closing."""
    p = Pose()
    s = _scale(c)
    out = 0.5 + 0.5 * math.sin(t * TAU)
    look = math.sin(t * TAU * 2 + 0.5)
    p.rot("neck", x=-0.45 + 0.45 * out, z=0.15 * look * out)
    p.rot("head", x=0.3 - 0.3 * out, z=0.1 * look * out)
    p.rot("jaw", x=-0.08 * max(0.0, math.sin(t * TAU * 3)))
    p.move(z=s * 0.01 * math.sin(t * TAU * 2))
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.05 * sign * math.sin(t * TAU), lower=-0.03 * sign * math.sin(t * TAU))
    _tail(p, t, sway=0.15)
    return p


def turtle_fidget(c, t):
    """Pulls its head right back into its shell and waits there, then shoots
    it out again with a snap of its beak and a little hop."""
    p = turtle_idle(c, 0.0)
    s = _scale(c)
    tuck = float(keys(t, [(0, 0), (0.15, 1), (0.55, 1), (0.62, -0.3), (0.72, 0), (1, 0)]))
    snap = float(keys(t, [(0, 0), (0.58, 0), (0.63, 1), (0.68, 0), (0.73, 0.6), (0.78, 0), (1, 0)]))
    hop = max(0.0, math.sin(max(0.0, (t - 0.58) / 0.2) * math.pi)) if 0.58 <= t <= 0.78 else 0.0
    p.rot("neck", x=-0.8 * max(tuck, 0.0) + 0.4 * max(-tuck, 0.0))
    p.rot("head", x=0.55 * max(tuck, 0.0) - 0.2 * max(-tuck, 0.0))
    p.rot("jaw", x=-0.9 * snap)
    p.move(y=-s * 0.08 * max(tuck, 0.0), z=s * 0.12 * hop)
    for side in ("L", "R"):
        # The legs draw in under the shell too, then brace for the hop.
        p.leg("fl." + side, upper=-0.3 * max(tuck, 0.0) + 0.25 * hop, lower=0.5 * max(tuck, 0.0) - 0.3 * hop)
        p.leg("hl." + side, upper=0.3 * max(tuck, 0.0) - 0.2 * hop, lower=-0.4 * max(tuck, 0.0) - 0.3 * hop, foot=0.2 * hop)
    return p


def turtle_victory(c, t):
    """Stands up tall on straight legs with its head stretched right out,
    snapping its beak in the air twice, and bobs up and down."""
    p = turtle_idle(c, 0.0)
    s = _scale(c)
    tall = float(keys(t, [(0, 0.7), (0.15, 1), (0.85, 1), (1, 0.7)]))
    bob = math.sin(t * TAU * 2)
    snap = max(0.0, math.sin(t * TAU * 4)) ** 3
    p.move(z=s * (0.25 * tall + 0.05 * bob))
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=-0.35 * tall, lower=0.1 * tall, foot=0.1 * bob * sign)
        p.leg("hl." + side, upper=-0.35 * tall, lower=0.25 * tall, foot=-0.2 * tall)
    p.rot("chest", x=0.1 * tall)
    p.rot("neck", x=0.5 * tall + 0.1 * bob)
    p.rot("head", x=-0.1 * tall + 0.15 * bob, z=0.15 * math.sin(t * TAU))
    p.rot("jaw", x=-0.8 * snap)
    _tail(p, t, sway=0.3, speed=3)
    return p



# --- The Tank Destroyers' personas -------------------------------------------------

def lion_idle(c, t):
    """Regal: stands tall and still, the head turning slowly to survey the
    field, the mane settling with a little shake at the end of each turn,
    the tail tip flicking."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    turn = math.sin(t * TAU * 0.5 * 2)
    p.move(z=s * 0.005 * breath)
    p.rot("chest", x=0.02 * breath)
    p.rot("neck", x=0.12 + 0.02 * breath, z=0.25 * turn)
    shake = math.sin(t * TAU * 6) * max(0.0, math.cos(t * TAU)) ** 6
    p.rot("head", x=0.05, z=0.15 * turn, y=0.12 * shake)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.15 * max(0.0, math.sin(t * TAU * 2 + sign)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.1, z=math.sin(t * TAU * (2 + i) - i) * 0.12 * (0.4 + 0.5 * i))
    return p


def lion_fidget(c, t):
    """A cat stretch: the front legs slide forward, chest to the ground and
    rump high, a huge yawn, then it pushes back up and shakes out its mane."""
    p = lion_idle(c, 0.0)
    s = _scale(c)
    stretch = float(keys(t, [(0, 0), (0.2, 1), (0.6, 1), (0.78, 0), (1, 0)]))
    yawn = float(keys(t, [(0, 0), (0.28, 0), (0.42, 1), (0.6, 0.9), (0.7, 0), (1, 0)]))
    shake = math.sin(t * TAU * 10) * float(keys(t, [(0, 0), (0.8, 0), (0.86, 1), (0.97, 0), (1, 0)]))
    p.move(y=s * 0.1 * stretch, z=-s * 0.12 * stretch)
    p.rot("chest", x=-0.35 * stretch, y=0.08 * shake)
    p.rot("hips", x=0.25 * stretch)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.9 * stretch, lower=-0.15 * stretch, foot=0.3 * stretch)
        p.leg("hl." + side, upper=-0.2 * stretch, lower=0.15 * stretch, foot=-0.1 * stretch)
        p.rot("ear." + side, z=sign * 0.5 * shake, x=-0.3 * yawn)
    p.rot("neck", x=0.25 * stretch + 0.15 * yawn, y=0.1 * shake)
    p.rot("head", x=0.25 * yawn, y=0.35 * shake, z=0.1 * shake)
    p.rot("jaw", x=-c.motion.get("gape", 0.8) * yawn)
    return p


def lion_victory(c, t):
    """The roar: it rears up a little with a front paw raised, throws its
    head back and roars with its mane flying, then settles into a proud sit
    for a beat, and roars again."""
    p = lion_idle(c, 0.0)
    s = _scale(c)
    roar = float(keys(t, [(0, 0), (0.12, 1), (0.42, 1), (0.52, 0), (1, 0)]))
    sit = float(keys(t, [(0, 0), (0.5, 0), (0.62, 1), (0.9, 1), (1, 0)]))
    _rear(c, p, 0.35 * roar + 0.45 * sit)
    p.move(z=-s * 0.18 * sit)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.85 * sit - 0.1 * roar, lower=-1.1 * sit, foot=0.5 * sit)
        if side == "R":
            p.leg("fl.R", upper=1.2 * roar + 0.3 * sit, lower=-1.3 * roar - 0.2 * sit, foot=-0.4 * roar)
        else:
            p.leg("fl.L", upper=0.25 * roar + 0.2 * sit, lower=-0.3 * roar - 0.1 * sit)
        p.rot("ear." + side, x=-0.4 * roar, z=sign * 0.15 * roar)
    p.rot("chest", x=0.1 * roar)
    p.rot("neck", x=0.3 * roar + 0.1 * sit)
    p.rot("head", x=0.45 * roar - 0.05 * sit, y=0.15 * math.sin(t * TAU * 8) * roar)
    p.rot("jaw", x=-c.motion.get("gape", 0.8) * roar)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.5 * roar, z=0.3 * math.sin(t * TAU * 5 - i) * roar)
    return p


def tiger_idle(c, t):
    """Coiled and watchful: standing a little low, the head scanning slowly
    side to side, ears swivelling, the tail lashing in long slow arcs."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    scan = math.sin(t * TAU + 0.3)
    p.move(z=s * 0.004 * breath - s * 0.02)
    p.rot("chest", x=0.015 * breath)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.06, lower=-0.08)
        p.leg("hl." + side, upper=0.08, lower=-0.1, foot=0.04)
        p.rot("ear." + side, z=sign * 0.3 * max(0.0, math.sin(t * TAU * 3 + sign * 0.5)) ** 2)
    p.rot("neck", x=-0.08, z=0.3 * scan)
    p.rot("head", x=0.02 * breath, z=0.2 * scan)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.1, z=math.sin(t * TAU * 2 - i * 0.9) * 0.45 * (0.5 + 0.4 * i))
    return p


def tiger_fidget(c, t):
    """Grooms: sits back, lifts a front paw, licks it and wipes it over its
    face and ear in small circles, then shakes its head and drops back
    down into its crouch."""
    p = tiger_idle(c, 0.0)
    s = _scale(c)
    sit = float(keys(t, [(0, 0), (0.15, 1), (0.78, 1), (0.92, 0), (1, 0)]))
    wipe_env = float(keys(t, [(0, 0), (0.2, 1), (0.7, 1), (0.8, 0), (1, 0)]))
    wipe = math.sin(t * TAU * 5) * wipe_env
    shake = math.sin(t * TAU * 10) * float(keys(t, [(0, 0), (0.78, 0), (0.84, 1), (0.95, 0), (1, 0)]))
    _rear(c, p, 0.45 * sit)
    p.move(z=-s * 0.2 * sit)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.85 * sit, lower=-1.15 * sit, foot=0.5 * sit)
        p.rot("ear." + side, z=sign * (0.3 * wipe_env + 0.5 * shake), x=-0.2 * wipe_env)
    p.leg("fl.R", upper=1.5 * sit + 0.25 * wipe, lower=-1.9 * sit - 0.3 * wipe, foot=-0.5 * sit, splay=-0.3 * sit)
    p.leg("fl.L", upper=0.3 * sit, lower=-0.35 * sit)
    p.rot("neck", x=0.1 * sit)
    p.rot("head", x=-0.15 * wipe_env + 0.1 * wipe, z=-0.3 * wipe_env, y=0.35 * shake)
    p.rot("jaw", x=-0.12 * wipe_env * max(0.0, math.sin(t * TAU * 5)))
    return p


def tiger_victory(c, t):
    """Pounces on the spot: a crouch, a spring with the claws out and the
    jaws wide, a landing in a low crouch, and again."""
    p = tiger_idle(c, 0.0)
    s = _scale(c)
    crouch = max(0.0, -math.sin(t * TAU * 2))
    leap = max(0.0, math.sin(t * TAU * 2))
    p.move(z=s * 0.4 * leap - s * 0.1 * crouch, y=s * 0.05 * leap)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.9 * leap - 0.25 * crouch, lower=-0.6 * leap - 0.45 * crouch, foot=-0.5 * leap + 0.1 * crouch,
              splay=sign * 0.2 * leap)
        p.leg("hl." + side, upper=-0.5 * leap + 0.45 * crouch, lower=-0.3 * leap - 0.6 * crouch, foot=0.5 * leap + 0.5 * crouch)
        p.rot("ear." + side, x=0.5 * leap, z=sign * 0.1 * leap)
    p.rot("chest", x=0.2 * leap - 0.15 * crouch)
    p.rot("hips", x=-0.1 * leap)
    p.rot("neck", x=0.15 * leap - 0.15 * crouch)
    p.rot("head", x=0.25 * leap)
    p.rot("jaw", x=-c.motion.get("gape", 0.75) * leap)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.4 * leap + 0.2 * crouch, z=0.2 * math.sin(t * TAU * 4 - i))
    return p


def boar_idle(c, t):
    """Snuffling: the head low with the snout bobbing along the ground, a
    front hoof rooting, the ears twitching, the tail wiggling."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.005 * breath)
    p.rot("chest", x=0.02 * breath)
    p.rot("neck", x=-0.28 + 0.03 * breath, z=0.1 * math.sin(t * TAU + 0.5))
    snuffle = math.sin(t * TAU * 4)
    p.rot("head", x=-0.1 + 0.06 * snuffle, z=0.08 * math.sin(t * TAU * 2))
    p.rot("jaw", x=-0.06 * max(0.0, snuffle))
    root = max(0.0, math.sin(t * TAU * 2 - 1.0)) ** 2
    p.leg("fl.L", upper=0.2 * root, lower=-0.25 * root, foot=0.15 * root)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.2 * max(0.0, math.sin(t * TAU * 3 + sign * 0.8)) ** 2)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.3, z=math.sin(t * TAU * 5 - i) * 0.3)
    return p


def boar_fidget(c, t):
    """Digs with its snout, the head shoving side to side in the dirt with
    the front hooves scraping, then tosses its head up with a snort and
    shakes the dirt off."""
    p = boar_idle(c, 0.0)
    s = _scale(c)
    dig_env = float(keys(t, [(0, 0), (0.1, 1), (0.55, 1), (0.62, 0), (1, 0)]))
    dig = math.sin(t * TAU * 7) * dig_env
    toss = float(keys(t, [(0, 0), (0.6, 0), (0.68, 1), (0.8, 0.5), (0.9, 0), (1, 0)]))
    shake = math.sin(t * TAU * 11) * float(keys(t, [(0, 0), (0.78, 0), (0.84, 1), (0.96, 0), (1, 0)]))
    p.move(z=-s * 0.08 * dig_env)
    p.rot("chest", x=-0.15 * dig_env + 0.08 * toss)
    p.rot("neck", x=-0.35 * dig_env + 0.55 * toss, z=0.3 * dig)
    p.rot("head", x=-0.15 * dig_env + 0.35 * toss, z=0.2 * dig, y=0.3 * shake)
    p.rot("jaw", x=-0.3 * toss)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.25 * dig_env + 0.2 * dig * sign, lower=-0.3 * dig_env - 0.2 * dig * sign, foot=0.2 * dig_env)
        p.rot("ear." + side, z=sign * 0.5 * shake, x=-0.4 * toss)
    return p


def boar_victory(c, t):
    """Bucks: a hop with the hind legs kicked up high behind it, squealing,
    lands, and bucks again, its tail spinning."""
    p = boar_idle(c, 0.0)
    s = _scale(c)
    buck = max(0.0, math.sin(t * TAU * 2))
    land = max(0.0, -math.sin(t * TAU * 2))
    p.move(z=s * 0.22 * buck - s * 0.05 * land)
    p.rot("chest", x=-0.25 * buck + 0.08 * land)
    p.rot("hips", x=-0.3 * buck)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.2 * buck - 0.1 * land, lower=-0.35 * buck - 0.3 * land, foot=0.1 * land)
        p.leg("hl." + side, upper=-0.9 * buck + 0.2 * land, lower=0.6 * buck - 0.4 * land, foot=-0.3 * buck + 0.3 * land)
        p.rot("ear." + side, x=-0.4 * buck, z=sign * 0.3 * buck)
    p.rot("neck", x=0.4 * buck + 0.1)
    p.rot("head", x=0.3 * buck)
    p.rot("jaw", x=-0.5 * buck)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.6, z=math.sin(t * TAU * 8 - i) * 0.4)
    return p


def wolf_idle(c, t):
    """Alert: ears pricked and swivelling, the head turning sharply to
    check one way then the other, a sniff, the tail held out and swaying."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.005 * breath)
    p.rot("chest", x=0.02 * breath)
    look = float(keys(t, [(0, 0), (0.2, 0), (0.28, 1), (0.48, 1), (0.56, -1), (0.76, -1), (0.84, 0), (1, 0)]))
    sniff = max(0.0, math.sin(t * TAU * 3)) ** 4 * (1.0 - abs(look))
    p.rot("neck", x=0.1 + 0.08 * sniff, z=0.35 * look)
    p.rot("head", x=0.05 + 0.1 * sniff, z=0.25 * look)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, x=-0.25, z=sign * (0.1 + 0.25 * max(0.0, look * sign)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.15, z=math.sin(t * TAU * 2 - i * 0.7) * 0.2 * (0.5 + 0.4 * i))
    return p


def wolf_fidget(c, t):
    """Sits and howls: the rump drops, the muzzle lifts straight up and the
    jaws open for a long howl with the chest swelling, then it stands and
    shakes."""
    p = wolf_idle(c, 0.0)
    s = _scale(c)
    sit = float(keys(t, [(0, 0), (0.14, 1), (0.78, 1), (0.9, 0), (1, 0)]))
    howl = float(keys(t, [(0, 0), (0.22, 1), (0.66, 1), (0.76, 0), (1, 0)]))
    shake = math.sin(t * TAU * 10) * float(keys(t, [(0, 0), (0.86, 0), (0.9, 1), (0.98, 0), (1, 0)]))
    _rear(c, p, 0.4 * sit)
    p.move(z=-s * 0.2 * sit)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.85 * sit, lower=-1.1 * sit, foot=0.5 * sit)
        p.leg("fl." + side, upper=0.15 * sit, lower=-0.15 * sit)
        p.rot("ear." + side, x=0.4 * howl, z=sign * 0.5 * shake)
    p.rot("chest", x=0.08 * howl, y=0.08 * shake)
    p.rot("neck", x=0.55 * howl)
    p.rot("head", x=0.5 * howl, y=0.3 * shake)
    p.rot("jaw", x=-0.6 * howl * (0.8 + 0.2 * math.sin(t * TAU * 6)))
    return p


def wolf_victory(c, t):
    """A howl of triumph with the chest up, the tail wagging hard, then a
    prance on the spot with the front paws lifted high in turn."""
    p = wolf_idle(c, 0.0)
    s = _scale(c)
    howl = float(keys(t, [(0, 0), (0.1, 1), (0.42, 1), (0.52, 0), (1, 0)]))
    prance = float(keys(t, [(0, 0), (0.5, 0), (0.58, 1), (0.92, 1), (1, 0)]))
    step = math.sin(t * TAU * 4) * prance
    _rear(c, p, 0.2 * howl)
    p.move(z=s * 0.05 * abs(step))
    for side, sign in (("L", 1), ("R", -1)):
        lift = max(0.0, step * sign)
        p.leg("fl." + side, upper=0.8 * lift + 0.2 * howl, lower=-0.9 * lift - 0.2 * howl, foot=-0.3 * lift)
        p.leg("hl." + side, upper=-0.1 * howl, lower=-0.1 * howl, foot=0.2 * howl)
        p.rot("ear." + side, x=0.35 * howl - 0.3 * prance, z=sign * 0.15 * prance)
    p.rot("chest", x=0.1 * howl)
    p.rot("neck", x=0.5 * howl + 0.1 * prance)
    p.rot("head", x=0.45 * howl + 0.05 * step)
    p.rot("jaw", x=-0.6 * howl - 0.25 * prance * max(0.0, math.sin(t * TAU * 4)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.45, z=math.sin(t * TAU * 6 - i) * 0.45)
    return p


def badger_idle(c, t):
    """Restless and cocky: low to the ground, the nose twitching and the
    head jerking to look about, a shuffle of the feet, the tail flicking."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.004 * breath - s * 0.01)
    jerk = float(keys(t, [(0, 0), (0.1, 0), (0.14, 1), (0.3, 1), (0.34, -0.6), (0.5, -0.6), (0.54, 0.3), (0.66, 0.3), (0.7, 0), (1, 0)]))
    p.rot("neck", x=-0.05, z=0.3 * jerk)
    p.rot("head", x=0.05 * math.sin(t * TAU * 6), z=0.2 * jerk)
    p.rot("jaw", x=-0.05 * max(0.0, math.sin(t * TAU * 6)))
    shuffle = math.sin(t * TAU * 2)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.06 * max(0.0, shuffle * sign), lower=-0.08 * max(0.0, shuffle * sign))
        p.rot("ear." + side, z=sign * 0.15 * max(0.0, math.sin(t * TAU * 4 + sign)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.1, z=math.sin(t * TAU * 4 - i) * 0.25)
    return p


def badger_fidget(c, t):
    """Sits and scratches behind its ear with a hind leg, fast, then shakes
    all over and drops back down."""
    p = badger_idle(c, 0.0)
    s = _scale(c)
    sit = float(keys(t, [(0, 0), (0.14, 1), (0.74, 1), (0.88, 0), (1, 0)]))
    scratch = math.sin(t * TAU * 9) * float(keys(t, [(0, 0), (0.18, 1), (0.6, 1), (0.68, 0), (1, 0)]))
    shake = math.sin(t * TAU * 12) * float(keys(t, [(0, 0), (0.74, 0), (0.8, 1), (0.94, 0), (1, 0)]))
    _rear(c, p, 0.45 * sit)
    p.move(z=-s * 0.18 * sit)
    p.leg("hl.L", upper=0.85 * sit, lower=-1.1 * sit, foot=0.5 * sit)
    # The right hind leg comes up to scratch behind the ear.
    p.leg("hl.R", upper=1.6 * sit + 0.2 * scratch, lower=-0.9 * sit - 0.3 * scratch, foot=0.2 * sit, splay=-0.5 * sit)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.2 * sit, lower=-0.2 * sit)
        p.rot("ear." + side, z=sign * (0.25 * abs(scratch) + 0.5 * shake))
    p.rot("chest", y=0.1 * shake, z=-0.1 * sit)
    p.rot("neck", x=0.1 * sit, z=-0.2 * sit)
    p.rot("head", x=-0.1 * sit + 0.05 * scratch, z=-0.25 * sit, y=0.35 * shake)
    return p


def badger_victory(c, t):
    """A cocky strut: hops with both front paws up in the air, head bobbing,
    then lands and swaggers, shoulders rolling, mouth open."""
    p = badger_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 3))
    swagger = math.sin(t * TAU * 3 + 1.0)
    _rear(c, p, 0.3 * hop)
    p.move(z=s * 0.2 * hop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=1.3 * hop, lower=-1.2 * hop, foot=-0.3 * hop, splay=sign * 0.3 * hop)
        p.leg("hl." + side, upper=-0.3 * hop, lower=-0.3 * hop, foot=0.4 * hop)
        p.rot("ear." + side, x=-0.3, z=sign * 0.2 * hop)
    p.rot("chest", z=0.08 * swagger, y=0.1 * swagger)
    p.rot("neck", x=0.2 + 0.1 * hop, z=-0.1 * swagger)
    p.rot("head", x=0.2 * hop, z=0.15 * swagger)
    p.rot("jaw", x=-c.motion.get("gape", 0.8) * (0.3 + 0.5 * hop))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.5, z=math.sin(t * TAU * 6 - i) * 0.3)
    return p


def cerberus_idle(c, t):
    """Three heads, never quite agreeing: the heads swing one way and the
    other as they look about, jaws parting to pant, the body hunkered and
    breathing heavy, the tail lashing."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU * 2)
    look = math.sin(t * TAU + 0.4)
    p.move(z=s * 0.005 * breath)
    p.rot("chest", x=0.02 * breath)
    p.rot("neck", x=-0.05 + 0.03 * breath, z=0.28 * look)
    p.rot("head", x=0.05 * breath, z=0.15 * look, y=0.08 * math.sin(t * TAU * 3))
    pant = max(0.0, math.sin(t * TAU * 4))
    p.rot("jaw", x=-0.18 * pant)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.2 * max(0.0, math.sin(t * TAU * 3 + sign * 0.7)) ** 2)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.1, z=math.sin(t * TAU * 3 - i * 0.8) * 0.4 * (0.5 + 0.4 * i))
    return p


def cerberus_fidget(c, t):
    """The heads squabble: they snap at one another, the neck whipping left
    and right with the jaws clacking, then all three shake it off together."""
    p = cerberus_idle(c, 0.0)
    s = _scale(c)
    env = float(keys(t, [(0, 0), (0.1, 1), (0.62, 1), (0.7, 0), (1, 0)]))
    whip = math.sin(t * TAU * 5) * env
    snap = max(0.0, math.sin(t * TAU * 10)) ** 2 * env
    shake = math.sin(t * TAU * 11) * float(keys(t, [(0, 0), (0.74, 0), (0.8, 1), (0.95, 0), (1, 0)]))
    p.rot("chest", z=0.08 * whip, y=0.08 * shake)
    p.rot("neck", x=0.1 * env, z=0.5 * whip)
    p.rot("head", z=0.3 * whip, x=0.1 * snap, y=0.35 * shake)
    p.rot("jaw", x=-0.7 * snap)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, x=0.4 * env, z=sign * 0.5 * shake)
        p.leg("fl." + side, upper=0.1 * env * sign * whip, lower=-0.1 * env * sign * whip)
    p.move(z=-s * 0.03 * env)
    return p


def cerberus_victory(c, t):
    """Rears up on its hind legs with all three heads thrown back howling
    fire, forelegs pawing the air, then drops into a bounce and rears
    again."""
    p = cerberus_idle(c, 0.0)
    s = _scale(c)
    up = float(keys(t, [(0, 0), (0.18, 1), (0.6, 1), (0.72, 0), (0.78, 0.06), (0.86, 0), (1, 0)]))
    paw = math.sin(t * TAU * 4) * up
    land = float(keys(t, [(0, 0), (0.68, 0), (0.74, 1), (0.84, 0), (1, 0)]))
    _rear(c, p, c.motion.get("victory_rear", 0.8) * up)
    p.move(z=-s * 0.08 * land)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.9 * up + 0.35 * paw * sign, lower=-0.8 * up - 0.3 * paw * sign, foot=-0.3 * up, splay=sign * 0.15 * up)
        p.leg("hl." + side, upper=-0.25 * up + 0.3 * land, lower=-0.2 * up - 0.4 * land, foot=0.35 * up)
        p.rot("ear." + side, x=0.5 * up)
    p.rot("chest", x=-0.05 * up - 0.12 * land)
    p.rot("neck", x=0.4 * up - 0.1 * land, z=0.1 * math.sin(t * TAU * 3) * up)
    p.rot("head", x=0.4 * up - 0.15 * land, y=0.1 * math.sin(t * TAU * 7) * up)
    p.rot("jaw", x=-c.motion.get("gape", 0.8) * (0.9 * up))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.4 * up, z=math.sin(t * TAU * 5 - i) * 0.35)
    return p



# --- The Ranged animals' personas ------------------------------------------------------

def squirrel_idle(c, t):
    """Twitchy: sits up on its haunches with its paws held together, the
    head jerking to look about, the nose twitching, the big tail curled up
    over its back and flicking."""
    p = Pose()
    s = _scale(c)
    _rear(c, p, 0.75)
    p.move(z=-s * 0.3)
    jerk = float(keys(t, [(0, 0), (0.18, 0), (0.22, 1), (0.42, 1), (0.46, -0.7), (0.68, -0.7), (0.72, 0), (1, 0)]))
    twitch = math.sin(t * TAU * 8) * 0.03
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.95, lower=-1.3, foot=0.55)
        p.leg("fl." + side, upper=1.2, lower=-1.5, foot=-0.3, splay=sign * 0.1)
        p.rot("ear." + side, z=sign * 0.15 * max(0.0, math.sin(t * TAU * 3 + sign)))
    p.rot("chest", x=0.05 + 0.02 * math.sin(t * TAU * 2))
    p.rot("neck", x=0.15, z=0.3 * jerk)
    p.rot("head", x=twitch, z=0.2 * jerk)
    p.rot("jaw", x=-0.04 * max(0.0, math.sin(t * TAU * 8)))
    curl = 0.5 + 0.1 * math.sin(t * TAU * 2)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-curl * (0.9 + 0.3 * i), z=math.sin(t * TAU * 3 - i) * 0.12)
    return p


def squirrel_fidget(c, t):
    """Nibbles a nut: the paws come up to the mouth and the jaw works fast,
    the head tipped, then it drops onto all fours, flicks its tail and sits
    back up."""
    p = squirrel_idle(c, 0.0)
    s = _scale(c)
    nibble = float(keys(t, [(0, 0), (0.1, 1), (0.5, 1), (0.58, 0), (1, 0)]))
    chew = max(0.0, math.sin(t * TAU * 12)) * nibble
    drop = float(keys(t, [(0, 0), (0.56, 0), (0.64, 1), (0.84, 1), (0.94, 0), (1, 0)]))
    flick = math.sin(t * TAU * 8) * drop
    _rear(c, p, -0.75 * drop)
    p.move(z=s * 0.3 * drop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.5 * nibble - 1.2 * drop, lower=-0.5 * nibble + 1.5 * drop, foot=-0.2 * nibble + 0.3 * drop)
        p.leg("hl." + side, upper=-0.95 * drop, lower=1.3 * drop, foot=-0.55 * drop)
    p.rot("neck", x=-0.1 * nibble - 0.15 * drop)
    p.rot("head", x=-0.25 * nibble + 0.05 * chew, z=0.15 * nibble)
    p.rot("jaw", x=-0.3 * chew)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.3 * drop * (0.5 + 0.3 * i), z=flick * 0.3 * (0.5 + 0.4 * i))
    return p


def squirrel_victory(c, t):
    """Bounces on its hind legs with its paws flung up, the tail whipping,
    chattering."""
    p = squirrel_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 3))
    crouch = max(0.0, -math.sin(t * TAU * 3))
    p.move(z=s * 0.3 * hop - s * 0.05 * crouch)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=1.4 * hop - 0.2 * crouch, lower=0.4 * hop - 0.2 * crouch, foot=-0.3, splay=sign * 0.35 * hop)
        p.leg("hl." + side, upper=-0.5 * hop + 0.2 * crouch, lower=0.4 * hop - 0.2 * crouch, foot=-0.3 * hop + 0.2 * crouch)
        p.rot("ear." + side, x=-0.3 * hop, z=sign * 0.2 * hop)
    p.rot("neck", x=0.1 * hop)
    p.rot("head", x=0.2 * hop, z=0.15 * math.sin(t * TAU * 6))
    p.rot("jaw", x=-0.3 * max(0.0, math.sin(t * TAU * 9)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.3 * hop * (0.5 + 0.3 * i), z=math.sin(t * TAU * 6 - i) * 0.35)
    return p


def raccoon_idle(c, t):
    """Shifty: hunched, sitting up a little with its paws held in front of
    it rubbing together slowly, the masked head turning to peer about, the
    ringed tail swaying."""
    p = Pose()
    s = _scale(c)
    _rear(c, p, 0.3)
    p.move(z=-s * 0.12)
    rub = math.sin(t * TAU * 3)
    peer = math.sin(t * TAU + 0.5)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.45, lower=-0.6, foot=0.3)
        p.leg("fl." + side, upper=0.9 + 0.08 * rub * sign, lower=-1.2 - 0.1 * rub * sign, foot=-0.3, splay=sign * 0.1)
        p.rot("ear." + side, z=sign * 0.12 * max(0.0, math.sin(t * TAU * 2 + sign)))
    p.rot("chest", x=0.1 + 0.02 * math.sin(t * TAU * 2))
    p.rot("neck", x=0.1, z=0.25 * peer)
    p.rot("head", x=-0.05, z=0.15 * peer)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.1, z=math.sin(t * TAU * 2 - i * 0.8) * 0.2 * (0.5 + 0.4 * i))
    return p


def raccoon_fidget(c, t):
    """Washes: sits right up and rubs its paws over each other fast, then
    over its face and ears, and shakes its head with the ears flapping."""
    p = raccoon_idle(c, 0.0)
    s = _scale(c)
    up = float(keys(t, [(0, 0), (0.12, 1), (0.8, 1), (0.92, 0), (1, 0)]))
    wash = math.sin(t * TAU * 7) * float(keys(t, [(0, 0), (0.12, 1), (0.45, 1), (0.5, 0), (1, 0)]))
    face = float(keys(t, [(0, 0), (0.46, 0), (0.54, 1), (0.74, 1), (0.8, 0), (1, 0)]))
    shake = math.sin(t * TAU * 10) * float(keys(t, [(0, 0), (0.8, 0), (0.85, 1), (0.96, 0), (1, 0)]))
    _rear(c, p, 0.4 * up)
    p.move(z=-s * 0.12 * up)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.45 * up, lower=-0.6 * up, foot=0.25 * up)
        p.leg("fl." + side, upper=0.5 * up + 0.15 * wash * sign + 1.2 * face, lower=-0.4 * up - 0.2 * wash * sign - 0.4 * face,
              foot=-0.2 * up, splay=sign * (0.15 * up - 0.1 * face))
        p.rot("ear." + side, z=sign * 0.5 * shake, x=-0.2 * face)
    p.rot("neck", x=0.05 * up - 0.1 * face)
    p.rot("head", x=-0.1 * face + 0.1 * math.sin(t * TAU * 7) * face, y=0.3 * shake, z=0.1 * shake)
    return p


def raccoon_victory(c, t):
    """Up on its hind legs rubbing its paws together with glee, hopping,
    its bottom and ringed tail wiggling."""
    p = raccoon_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 3))
    rub = math.sin(t * TAU * 6)
    wiggle = math.sin(t * TAU * 3 + 1.0)
    _rear(c, p, 0.5)
    p.move(z=-s * 0.05 + s * 0.2 * hop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("hl." + side, upper=0.3 - 0.3 * hop, lower=-0.4 - 0.2 * hop, foot=0.3 + 0.2 * hop)
        p.leg("fl." + side, upper=1.1 + 0.12 * rub * sign, lower=-1.5 - 0.15 * rub * sign, foot=-0.3)
        p.rot("ear." + side, x=-0.2, z=sign * 0.15 * hop)
    p.rot("hips", z=0.1 * wiggle)
    p.rot("chest", x=0.05, z=-0.05 * wiggle)
    p.rot("neck", x=0.15 + 0.1 * hop)
    p.rot("head", x=0.15 * hop, z=0.12 * wiggle)
    p.rot("jaw", x=-0.35 * hop)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.3, z=math.sin(t * TAU * 6 - i) * 0.4)
    return p


def skunk_idle(c, t):
    """Tail held high and waving like a plume, the head low sniffing along,
    a cautious little weight shift."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.005 * breath)
    p.rot("chest", x=0.02 * breath)
    p.rot("neck", x=-0.2, z=0.12 * math.sin(t * TAU + 0.5))
    p.rot("head", x=-0.05 + 0.04 * math.sin(t * TAU * 3), z=0.08 * math.sin(t * TAU + 0.5))
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.12 * max(0.0, math.sin(t * TAU * 2 + sign)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.55 * (1.0 if i == 0 else 0.5), z=math.sin(t * TAU * 2 - i * 0.7) * 0.2 * (0.6 + 0.3 * i))
    return p


def skunk_fidget(c, t):
    """The warning: stamps its front feet fast, one and the other, then
    spins round to show its tail and hoists it straight up, holds, and
    turns back."""
    p = skunk_idle(c, 0.0)
    s = _scale(c)
    stamp_env = float(keys(t, [(0, 0), (0.06, 1), (0.4, 1), (0.46, 0), (1, 0)]))
    stamp = math.sin(t * TAU * 8) * stamp_env
    turn = float(keys(t, [(0, 0), (0.46, 0), (0.6, 1), (0.84, 1), (0.96, 0), (1, 0)]))
    for side, sign in (("L", 1), ("R", -1)):
        lift = max(0.0, stamp * sign)
        p.leg("fl." + side, upper=0.5 * lift, lower=-0.6 * lift, foot=-0.2 * lift)
    p.rot("chest", x=-0.05 * stamp_env)
    p.rot("neck", x=-0.1 * stamp_env + 0.1 * turn)
    p.rot("head", z=0.3 * turn)
    _spin(c, p, z=math.pi * turn)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.7 * turn * (1.0 if i == 0 else 0.4), z=0.1 * math.sin(t * TAU * 4 - i) * turn)
    p.move(z=s * 0.03 * abs(stamp))
    return p


def skunk_victory(c, t):
    """Twirls on the spot with its tail straight up like a flag, hopping on
    its toes, head high."""
    p = skunk_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 3))
    _spin(c, p, z=t * TAU)
    p.move(z=s * 0.15 * hop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.3 * hop, lower=-0.4 * hop, foot=-0.3 * hop)
        p.leg("hl." + side, upper=-0.2 * hop, lower=-0.2 * hop, foot=0.4 * hop)
        p.rot("ear." + side, x=-0.2, z=sign * 0.15 * hop)
    p.rot("neck", x=0.35)
    p.rot("head", x=0.15, z=0.1 * math.sin(t * TAU * 3))
    p.rot("jaw", x=-0.3 * hop)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.75 * (1.0 if i == 0 else 0.45), z=math.sin(t * TAU * 5 - i) * 0.1)
    return p


def cobra_idle(c, t):
    """Raised and watchful: a slow hypnotic sway with the hood spread, the
    head weaving a little against the body, the tongue flicking."""
    p = Pose()
    sway = math.sin(t * TAU)
    p.rot("chest", z=0.08 * sway)
    p.rot("neck", z=0.14 * sway, x=0.03 * math.sin(t * TAU * 2))
    p.rot("neck2", z=-0.1 * sway, x=0.03 * math.sin(t * TAU * 2 + 1.0))
    p.rot("head", z=-0.08 * sway, x=0.04 * math.sin(t * TAU * 2 + 2.0))
    p.rot("jaw", x=-0.08 * max(0.0, math.sin(t * TAU * 5)) ** 3)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=math.sin(t * TAU - i * 0.9) * 0.08)
    return p


def cobra_fidget(c, t):
    """A mock strike: it draws its head back and rises taller, hangs for a
    beat with the jaws parting, strikes forward with a hiss, and draws
    back into its sway."""
    p = cobra_idle(c, 0.0)
    back = float(keys(t, [(0, 0), (0.25, 1), (0.48, 1), (0.54, -0.2), (0.62, 0), (1, 0)]))
    strike = float(keys(t, [(0, 0), (0.48, 0), (0.54, 1), (0.66, 0.7), (0.8, 0), (1, 0)]))
    p.rot("chest", x=0.1 * max(back, 0.0))
    p.rot("neck", x=0.25 * max(back, 0.0) - 0.3 * strike)
    p.rot("neck2", x=-0.4 * max(back, 0.0) + 0.55 * strike)
    p.rot("head", x=0.2 * max(back, 0.0) - 0.15 * strike)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.3 * max(back, 0.0) + 1.3 * strike))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=0.15 * max(back, 0.0) * math.sin(i * 1.2), x=0.1 * strike)
    return p


def cobra_victory(c, t):
    """Dances: the whole raised body weaves side to side in big slow
    swings, the head bobbing against them, jaws open hissing."""
    p = cobra_idle(c, 0.0)
    weave = math.sin(t * TAU)
    bob = math.sin(t * TAU * 2)
    p.rot("hips", z=0.1 * weave)
    p.rot("chest", z=0.2 * weave, x=0.05 * bob)
    p.rot("neck", z=0.25 * weave, x=0.1 * bob)
    p.rot("neck2", z=-0.15 * weave, x=-0.08 * bob)
    p.rot("head", z=-0.2 * weave, x=0.15 * bob)
    p.rot("jaw", x=-c.motion.get("gape", 0.5) * (0.5 + 0.4 * max(0.0, bob)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=math.sin(t * TAU - i * 0.9) * 0.2)
    return p


def camel_idle(c, t):
    """Chewing the cud: the jaw grinding round and round, the head bobbing
    slowly on its long neck, ears flicking, a hind knee bending now and
    then, the tail flicking."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.004 * breath)
    p.rot("chest", x=0.012 * breath)
    p.rot("neck", x=0.05 + 0.03 * math.sin(t * TAU + 1.0), z=0.08 * math.sin(t * TAU * 0.5 * 2))
    p.rot("head", x=-0.05 + 0.03 * math.sin(t * TAU * 2), z=0.05 * math.sin(t * TAU))
    grind = t * TAU * 3
    p.rot("jaw", x=-0.12 - 0.08 * math.sin(grind), z=0.12 * math.cos(grind))
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.3 * max(0.0, math.sin(t * TAU * 2 + sign * 0.7)) ** 3)
    rest = max(0.0, math.sin(t * TAU - 1.5)) ** 2
    p.leg("hl.L", upper=0.15 * rest, lower=-0.25 * rest, foot=0.1 * rest)
    _tail(p, t, sway=0.35, speed=2)
    return p


def camel_fidget(c, t):
    """Works up a spit: chews, draws its head back with its cheeks puffing,
    spits with a thrust of the head and the lips flying open, then grumbles,
    shaking its head and smacking its lips."""
    p = camel_idle(c, 0.0)
    gather = float(keys(t, [(0, 0), (0.15, 0.4), (0.4, 1), (0.46, 1), (0.52, -0.4), (0.6, 0), (1, 0)]))
    spit = float(keys(t, [(0, 0), (0.46, 0), (0.52, 1), (0.6, 0.5), (0.7, 0), (1, 0)]))
    grumble = math.sin(t * TAU * 7) * float(keys(t, [(0, 0), (0.7, 0), (0.76, 1), (0.95, 0), (1, 0)]))
    p.rot("neck", x=-0.2 * max(gather, 0.0) + 0.35 * spit, y=0.1 * grumble)
    p.rot("head", x=-0.15 * max(gather, 0.0) + 0.3 * spit, z=0.15 * grumble, y=0.2 * grumble)
    p.rot("jaw", x=-c.motion.get("gape", 0.4) * (1.6 * spit) - 0.15 * abs(grumble), z=0.2 * grumble)
    p.rot("chest", x=0.03 * max(gather, 0.0) - 0.04 * spit)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, x=0.4 * max(gather, 0.0), z=sign * 0.4 * grumble)
    return p


def camel_victory(c, t):
    """A proud high-stepping prance on the spot, the knees lifting high in
    turn, the head held up and nodding, the tail swishing, lips smacking."""
    p = camel_idle(c, 0.0)
    s = _scale(c)
    step = math.sin(t * TAU * 2)
    p.move(z=s * 0.03 * abs(step))
    for side, sign in (("L", 1), ("R", -1)):
        front = max(0.0, step * sign)
        hind = max(0.0, -step * sign)
        p.leg("fl." + side, upper=0.8 * front, lower=-1.0 * front, foot=-0.2 * front)
        p.leg("hl." + side, upper=-0.5 * hind, lower=-0.4 * hind, foot=0.5 * hind)
        p.rot("ear." + side, x=-0.3, z=sign * 0.2 * abs(step))
    p.rot("chest", x=0.05, z=0.03 * step)
    p.rot("neck", x=0.3 + 0.05 * math.sin(t * TAU * 4))
    p.rot("head", x=0.1 + 0.1 * math.sin(t * TAU * 4), z=0.08 * step)
    p.rot("jaw", x=-0.2 * max(0.0, math.sin(t * TAU * 4)))
    _tail(p, t, sway=0.5, speed=4)
    return p


def orangutan_idle(c, t):
    """Easygoing: the long arms hanging and swinging a little behind a
    slow sway, the body rocking, the head tipping thoughtfully, the lips
    pursing now and then."""
    p = Pose()
    s = _scale(c)
    sway = math.sin(t * TAU)
    breath = math.sin(t * TAU * 2)
    p.move(z=s * 0.006 * breath)
    p.rot("chest", x=0.03 * breath, z=0.04 * sway)
    p.rot("hips", z=-0.025 * sway)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.04 * math.sin(t * TAU - 0.9) + 0.03 * breath, lower=-0.1, foot=-0.15, splay=sign * 0.04 * sway)
        p.leg("hl." + side, upper=0.02 * sign * sway)
    p.rot("neck", x=0.05, z=0.1 * sway)
    p.rot("head", x=-0.02 * breath, z=0.18 * math.sin(t * TAU + 0.8))
    p.rot("jaw", x=-0.12 * max(0.0, math.sin(t * TAU * 2 - 0.5)) ** 3)
    return p


def orangutan_fidget(c, t):
    """Scratches: one long arm comes up to scratch the top of its head
    while the other scratches its side, the head tipping into it, then both
    arms stretch up high with a yawn and drop."""
    p = orangutan_idle(c, 0.0)
    s = _scale(c)
    scratch = float(keys(t, [(0, 0), (0.15, 1), (0.52, 1), (0.6, 0), (1, 0)]))
    rub = math.sin(t * TAU * 6) * scratch
    stretch = float(keys(t, [(0, 0), (0.58, 0), (0.72, 1), (0.86, 1), (0.97, 0), (1, 0)]))
    p.leg("fl.R", upper=2.6 * scratch + 2.9 * stretch, lower=-1.9 * scratch - 0.3 * stretch + 0.2 * rub, foot=-0.4 * scratch, splay=-0.3 * scratch)
    p.leg("fl.L", upper=0.9 * scratch + 2.9 * stretch, lower=-1.6 * scratch - 0.3 * stretch - 0.2 * rub, foot=-0.3 * scratch, splay=0.5 * scratch)
    p.rot("chest", x=0.1 * stretch, z=-0.08 * scratch)
    p.rot("neck", x=0.1 * stretch)
    p.rot("head", z=-0.25 * scratch + 0.05 * rub, x=0.3 * stretch)
    p.rot("jaw", x=-0.7 * stretch)
    p.move(z=s * 0.04 * stretch)
    for side in ("L", "R"):
        p.leg("hl." + side, upper=-0.06 * stretch, lower=0.04 * stretch)
    return p


def orangutan_victory(c, t):
    """The dance: both long arms up over its head waving from side to side
    as the whole body sways with them, feet shuffling, mouth open hooting."""
    p = orangutan_idle(c, 0.0)
    s = _scale(c)
    wave = math.sin(t * TAU * 2)
    sway = math.sin(t * TAU)
    hop = max(0.0, math.sin(t * TAU * 4)) * 0.4
    p.move(z=s * 0.08 * hop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=2.8, lower=-0.4 + 0.25 * wave * sign, foot=-0.3, splay=sign * (0.4 + 0.3 * wave * sign))
        p.leg("hl." + side, upper=0.1 * sign * sway - 0.15 * hop, lower=-0.15 * hop, foot=0.15 * hop)
    p.rot("chest", z=0.12 * sway, x=0.05)
    p.rot("hips", z=-0.08 * sway)
    p.rot("neck", x=0.15, z=0.1 * sway)
    p.rot("head", x=0.2, z=-0.15 * sway)
    p.rot("jaw", x=-0.5 * (0.6 + 0.4 * max(0.0, wave)))
    return p


def unicorn_idle(c, t):
    """Graceful: the head carried high with the neck arched, nodding
    gently, a front hoof pawing the ground now and then, the tail swishing
    in long slow sweeps, ears turning."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.004 * breath)
    p.rot("chest", x=0.012 * breath)
    p.rot("neck", x=0.22 + 0.03 * math.sin(t * TAU * 2), z=0.08 * math.sin(t * TAU + 0.6))
    p.rot("head", x=-0.25 + 0.04 * math.sin(t * TAU * 2 + 1.0), z=0.05 * math.sin(t * TAU + 0.6))
    paw = max(0.0, math.sin(t * TAU * 2 - 0.8)) ** 2 * max(0.0, math.sin(t * TAU))
    p.leg("fl.L", upper=0.35 * paw, lower=-0.5 * paw, foot=0.2 * paw)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.25 * max(0.0, math.sin(t * TAU * 3 + sign * 0.8)) ** 2, x=-0.1)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.2, z=math.sin(t * TAU - i * 0.6) * 0.3 * (0.5 + 0.4 * i))
    return p


def unicorn_fidget(c, t):
    """Rears up and paws the air with both front hooves, then drops and
    tosses its head with a whinny, mane and tail flying."""
    p = unicorn_idle(c, 0.0)
    s = _scale(c)
    up = float(keys(t, [(0, 0), (0.18, 1), (0.52, 1), (0.64, 0), (0.7, 0.05), (0.76, 0), (1, 0)]))
    paw = math.sin(t * TAU * 4) * up
    toss = float(keys(t, [(0, 0), (0.66, 0), (0.74, 1), (0.84, 0.3), (0.92, 0.7), (1, 0)]))
    _rear(c, p, 0.65 * up)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.9 * up + 0.4 * paw * sign, lower=-0.9 * up - 0.3 * paw * sign, foot=-0.3 * up)
        p.leg("hl." + side, upper=-0.25 * up, lower=-0.15 * up, foot=0.3 * up)
        p.rot("ear." + side, x=-0.3 * up + 0.3 * toss, z=sign * 0.2 * toss)
    p.rot("neck", x=0.1 * up + 0.25 * toss, z=0.3 * math.sin(t * TAU * 5) * toss)
    p.rot("head", x=0.1 * up - 0.1 * toss, z=0.15 * math.sin(t * TAU * 5) * toss)
    p.rot("jaw", x=-0.45 * toss)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.6 * up - 0.5 * toss, z=math.sin(t * TAU * 5 - i) * 0.35 * (up + toss))
    return p


def unicorn_victory(c, t):
    """Prances on the spot, knees lifting high in a proud high-step, the
    head tossing with the horn held up and the tail high, then a little
    rear, and on."""
    p = unicorn_idle(c, 0.0)
    s = _scale(c)
    prance = float(keys(t, [(0, 1), (0.55, 1), (0.62, 0), (0.9, 0), (0.98, 1), (1, 1)]))
    rear = float(keys(t, [(0, 0), (0.58, 0), (0.68, 1), (0.86, 1), (0.96, 0), (1, 0)]))
    step = math.sin(t * TAU * 4) * prance
    p.move(z=s * 0.035 * abs(step))
    _rear(c, p, 0.5 * rear)
    for side, sign in (("L", 1), ("R", -1)):
        front = max(0.0, step * sign)
        hind = max(0.0, -step * sign)
        p.leg("fl." + side, upper=0.9 * front + 0.8 * rear + 0.3 * math.sin(t * TAU * 6) * rear * sign, lower=-1.1 * front - 0.8 * rear, foot=-0.3 * front - 0.3 * rear)
        p.leg("hl." + side, upper=-0.5 * hind - 0.2 * rear, lower=-0.4 * hind - 0.1 * rear, foot=0.5 * hind + 0.3 * rear)
        p.rot("ear." + side, x=-0.3, z=sign * 0.15 * abs(step))
    p.rot("neck", x=0.3 + 0.1 * math.sin(t * TAU * 4) * prance, z=0.12 * math.sin(t * TAU * 2) * prance)
    p.rot("head", x=-0.15 + 0.15 * math.sin(t * TAU * 4) * prance + 0.15 * rear)
    p.rot("jaw", x=-0.25 * max(0.0, math.sin(t * TAU * 4)) * prance - 0.3 * rear)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.6, z=math.sin(t * TAU * 6 - i) * 0.35)
    return p



# --- The Air animals' personas ------------------------------------------------------

# --- Hero card poses (docs/ART_DIRECTION.md, "Readability"): each animal's
# signature move, frozen at its most telling moment, facing the camera. ----

def _mirror_pose(p):
    """The same pose with left and right swapped (a card's camera sees the
    animal's left side: its signature move goes on the near paw)."""
    out = Pose()
    for name, value in p.items():
        if name.endswith(".L"):
            out[name[:-2] + ".R"] = value
        elif name.endswith(".R"):
            out[name[:-2] + ".L"] = value
        else:
            out[name] = value
    return out


def hero_bear(c):
    """Reared up mid-swipe, the near front paw high, roaring."""
    p = _mirror_pose(swipe(c, 0.3))
    p.rot("jaw", x=-0.25)
    p.rot("head", x=0.12)
    return p


def hero_falcon(c):
    """A stoop: diving, wings tucked back along the body, the face toward
    us and the talons out ahead."""
    p = Pose()
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("wing_upper." + side, x=0.35, z=0.35 * sign)
        p.rot("wing_lower." + side, x=0.1, z=0.25 * sign)
        p.rot("wing_hand." + side, z=0.2 * sign)
        p.rot("leg." + side, x=1.0)
    p["root_rot"] = (-0.35, -0.25, 0.15)
    p.rot("neck", x=0.3, z=0.25)
    p.rot("head", x=0.2, z=0.3)
    p.rot("jaw", x=-0.3)
    return p


def hero_cobra(c):
    """Up on its coils with the hood spread, leaning toward us, hissing."""
    p = serpent_idle(c, 0.0)
    p["root_rot"] = (0.0, 0.0, 0.3)
    p.rot("neck", x=0.15)
    p.rot("neck2", x=-0.1, z=0.25)
    p.rot("head", x=0.05, z=0.3)
    p.rot("jaw", x=-0.45)
    return p


def perched(c):
    """A bird's card portrait pose: standing with its body pitched up
    (`motion["perch_tilt"]`, radians nose-up; an owl stands nearly upright,
    a condor leans forward), wings folded down along its flanks with the
    tips crossed over the tail, legs straight under it with the feet on the
    ground, chest out and the head level, turned a little toward us (the
    flight pose reads as a dart on a card; "portrait_view" aims the camera).
    The wings are longer than the bird is tall, so their tips go on under
    the ground, which hides them; `motion["perch_wings"]` (0-1) folds the
    wings less."""
    p = Pose()
    tilt = float(c.motion.get("perch_tilt", 1.0))
    fold = float(c.motion.get("perch_wings", 1.0))
    leg_x = float(c.motion.get("perch_legs", 0.3))
    for side, sign in (("L", 1), ("R", -1)):
        # Positive z on the left wing (negative on the right) sweeps it back;
        # negative x drops it to lie along the flank.
        p.rot("wing_upper." + side, x=-0.3 * fold, z=1.25 * fold * sign)
        p.rot("wing_lower." + side, x=-0.1 * fold, z=0.7 * fold * sign)
        p.rot("wing_hand." + side, x=-0.1 * fold, z=0.5 * fold * sign)
        p.rot("leg." + side, x=leg_x)
    p["root_rot"] = (tilt, 0.0, 0.0)
    # Feet on the ground: where the left foot ends up after the leg's pitch
    # and the body's tilt, from the rest joints.
    j = c.joints
    root = np.asarray(j["root"], float)
    hip = np.asarray(j["hip.L"], float) - root
    d = np.asarray(j["foot.L"], float) - root - hip
    d = np.array([d[0], d[1] * math.cos(leg_x) - d[2] * math.sin(leg_x), d[1] * math.sin(leg_x) + d[2] * math.cos(leg_x)])
    f = hip + d
    foot_z = f[1] * math.sin(tilt) + f[2] * math.cos(tilt)
    p.move(z=0.01 - float(c.motion.get("altitude", 0.0)) - foot_z)
    p.rot("chest", x=0.05)
    p.rot("neck", x=-(tilt - 0.1) * 0.6, z=0.2)
    # `perch_head` lifts the head a little more (a parrot's beak hangs).
    p.rot("head", x=-(tilt - 0.1) * 0.4 + float(c.motion.get("perch_head", 0.0)), z=0.25)
    # The tail trails back just off the ground.
    p.rot("tail1", x=-(tilt - 0.25))
    return p


def falcon_idle(c, t):
    """Quick crisp wingbeats, the head snapping to scan one way and the
    other, the tail fanned a little against each beat."""
    p = bird_flap(c, t, power=1.0)
    scan = float(keys(t, [(0, 0), (0.3, 0), (0.36, 1), (0.6, 1), (0.66, -1), (0.9, -1), (0.96, 0), (1, 0)]))
    p.rot("neck", z=0.3 * scan)
    p.rot("head", z=0.2 * scan)
    p.rot("tail1", x=-0.1 * max(0.0, math.sin(t * TAU)))
    return p


def falcon_fidget(c, t):
    """A barrel roll: the wings sweep back and it rolls right over, then
    opens its wings with a shake and flies on."""
    roll = float(keys(t, [(0, 0), (0.2, 0), (0.7, 1), (1, 1)]))
    tuck = math.sin(math.pi * min(1.0, max(0.0, (t - 0.15) / 0.6)))
    p = bird_flap(c, t, power=c.motion.get("hover_power", 0.55))
    _wings(p, upper=-0.3 * tuck, lower=-0.7 * tuck, hand=-0.5 * tuck, sweep=0.6 * tuck)
    _spin(c, p, x=0.0, z=0.0)
    p["root_rot"] = (0.0, -roll * TAU, 0.0)
    shake = math.sin(t * TAU * 12) * float(keys(t, [(0, 0), (0.74, 0), (0.8, 1), (0.95, 0), (1, 0)]))
    p.rot("head", y=0.3 * shake)
    p.rot("neck", x=0.15 * tuck)
    return p


def falcon_victory(c, t):
    """A spiralling climb: beating hard, it screws upward turning as it
    goes, then drops back to height and starts again."""
    p = bird_flap(c, (t * 2) % 1, power=1.2)
    s = c.motion.get("altitude", 0.5)
    rise = math.sin(t * math.pi)
    p.move(z=rise * s * 0.4)
    _spin(c, p, z=t * TAU)
    p["root_rot"] = (p["root_rot"][0] + 0.25 * rise, p["root_rot"][1] + 0.3, p["root_rot"][2])
    p.rot("neck", x=0.2)
    p.rot("head", x=0.15)
    p.rot("jaw", x=-0.3 * max(0.0, math.sin(t * TAU * 3)))
    return p


def owl_idle(c, t):
    """Slow, deep, silent wingbeats, and the famous head: swivelling far
    round to look behind it, then back, the body never turning."""
    p = bird_flap(c, t, power=0.75)
    swivel = float(keys(t, [(0, 0), (0.2, 0), (0.35, 1), (0.6, 1), (0.75, 0), (1, 0)]))
    p.rot("neck", z=0.5 * swivel)
    p.rot("head", z=1.1 * swivel, x=0.05 * math.sin(t * TAU * 2))
    return p


def owl_fidget(c, t):
    """Turns its head almost all the way round to look straight behind,
    holds, snaps it back, and ruffles all its feathers with a shiver."""
    p = bird_flap(c, t, power=0.75)
    turn = float(keys(t, [(0, 0), (0.25, 1), (0.55, 1), (0.62, -0.15), (0.7, 0), (1, 0)]))
    ruffle = math.sin(t * TAU * 14) * float(keys(t, [(0, 0), (0.72, 0), (0.78, 1), (0.95, 0), (1, 0)]))
    p.rot("neck", z=0.9 * turn)
    p.rot("head", z=1.7 * turn, y=0.2 * ruffle)
    _wings(p, upper=0.08 * ruffle, lower=0.1 * ruffle, hand=0.12 * ruffle)
    p.rot("chest", y=0.05 * ruffle)
    p.rot("tail1", z=0.1 * ruffle)
    return p


def owl_victory(c, t):
    """A slow graceful loop with the wings spread wide, the head level all
    the way round, and a soft hoot at the top."""
    p = bird_flap(c, t, power=0.5)
    s = c.motion.get("altitude", 0.5)
    _wings(p, upper=0.35, lower=0.1, hand=0.05)
    _spin(c, p, x=-t * TAU)
    p.move(z=math.sin(t * TAU) * s * 0.15)
    p.rot("neck", x=0.15)
    p.rot("head", x=0.1)
    p.rot("jaw", x=-0.25 * max(0.0, math.sin(t * TAU * 2 + 1.0)) ** 2)
    return p


def eagle_idle(c, t):
    """Powerful, unhurried wingbeats with a glide between them, the head
    carried high and proud, turning slowly to survey."""
    beat = max(0.0, math.sin(t * TAU)) ** 0.7
    p = bird_flap(c, t, power=1.1)
    _wings(p, upper=0.15 * (1.0 - beat), lower=0.05, hand=0.0)
    p.rot("neck", x=0.2, z=0.25 * math.sin(t * TAU * 0.5 * 2))
    p.rot("head", x=0.1, z=0.15 * math.sin(t * TAU))
    return p


def eagle_fidget(c, t):
    """A screech: the head thrown back with the beak wide, the wings flung
    up and held, the talons clenching, then it settles."""
    p = bird_flap(c, t, power=0.6)
    cry = float(keys(t, [(0, 0), (0.2, 1), (0.6, 1), (0.78, 0), (1, 0)]))
    _wings(p, upper=0.7 * cry, lower=0.3 * cry, hand=0.2 * cry)
    for side in ("L", "R"):
        p.rot("leg." + side, x=0.9 * cry)
    p.rot("neck", x=0.4 * cry)
    p.rot("head", x=0.45 * cry)
    p.rot("jaw", x=-0.6 * cry)
    p.rot("chest", x=0.1 * cry)
    return p


def eagle_victory(c, t):
    """Hangs in the air with its wings held high and wide, screeching
    skyward, the tail fanned, rising and falling in slow surges."""
    p = bird_flap(c, (t * 2) % 1, power=0.5)
    s = c.motion.get("altitude", 0.5)
    _wings(p, upper=0.6, lower=0.25, hand=0.15)
    p.move(z=math.sin(t * TAU) * s * 0.18)
    p.rot("neck", x=0.4)
    p.rot("head", x=0.35, z=0.15 * math.sin(t * TAU))
    p.rot("jaw", x=-0.5 * (0.5 + 0.5 * max(0.0, math.sin(t * TAU * 2))))
    p.rot("tail1", x=-0.3)
    return p


def macaw_idle(c, t):
    """Perky, busy wingbeats, the head bobbing along with them and cocking
    to one side, a squawk now and then."""
    p = bird_flap(c, t, power=1.0)
    p.rot("neck", x=0.15 * math.sin(t * TAU * 2), z=0.2 * math.sin(t * TAU + 1.0))
    p.rot("head", x=0.2 * math.sin(t * TAU * 2 + 0.5), z=0.3 * math.sin(t * TAU + 1.0))
    p.rot("jaw", x=-0.35 * max(0.0, math.sin(t * TAU * 2 - 1.2)) ** 4)
    return p


def macaw_fidget(c, t):
    """A loop-the-loop with a squawk, wings flaring wide at the top."""
    p = bird_flap(c, t, power=0.8)
    loop = float(keys(t, [(0, 0), (0.15, 0), (0.75, 1), (1, 1)]))
    flare = math.sin(math.pi * min(1.0, max(0.0, (t - 0.15) / 0.6)))
    _wings(p, upper=0.3 * flare, lower=0.15 * flare, hand=0.1 * flare)
    _spin(c, p, x=loop * TAU)
    p.rot("jaw", x=-0.5 * flare)
    p.rot("neck", x=0.2 * flare)
    return p


def macaw_victory(c, t):
    """The parrot dance: the head bobbing up and down and side to side in
    time, the whole body bouncing, wings flicking, squawking along."""
    p = bird_flap(c, (t * 2) % 1, power=0.7)
    s = c.motion.get("altitude", 0.5)
    bob = math.sin(t * TAU * 4)
    side = math.sin(t * TAU * 2)
    p.move(z=s * 0.08 * bob)
    p.rot("chest", z=0.1 * side)
    p.rot("neck", x=0.35 * bob, z=0.3 * side)
    p.rot("head", x=0.3 * bob, z=0.3 * side)
    p.rot("jaw", x=-0.4 * max(0.0, bob))
    _wings(p, upper=0.15 * max(0.0, bob), lower=0.1 * max(0.0, bob), hand=0.1 * max(0.0, bob))
    p.rot("tail1", z=0.2 * side)
    return p


def condor_idle(c, t):
    """Soaring: the great wings held flat and wide with barely a beat, the
    body tilting gently into slow turns, the fingered tips feeling the air."""
    p = Pose()
    s = c.motion.get("altitude", 0.5)
    tilt = math.sin(t * TAU)
    beat = max(0.0, math.sin(t * TAU * 2 - 2.5)) ** 6 * 0.3
    _wings(p, upper=0.15 + beat, lower=0.0 - beat * 0.5, hand=0.05 * math.sin(t * TAU * 3) - beat * 0.4, twist=0.05 * tilt)
    p["root_rot"] = (0.0, 0.25 * tilt, 0.0)
    p.move(z=math.sin(t * TAU * 2) * s * 0.03)
    p.rot("neck", x=-0.1, z=0.15 * tilt)
    p.rot("head", x=0.1, z=0.1 * tilt)
    p.rot("tail1", z=0.15 * tilt)
    for side in ("L", "R"):
        p.rot("leg." + side, x=-0.9)
    return p


def condor_fidget(c, t):
    """Banks hard one way, then the other, then stretches both wings up
    high in a slow shrug and settles back into its soar."""
    p = condor_idle(c, 0.0)
    bank = float(keys(t, [(0, 0), (0.15, 1), (0.3, 1), (0.45, -1), (0.6, -1), (0.7, 0), (1, 0)]))
    stretch = float(keys(t, [(0, 0), (0.68, 0), (0.78, 1), (0.9, 1), (1, 0)]))
    p["root_rot"] = (0.0, 0.55 * bank, 0.0)
    _wings(p, upper=0.7 * stretch, lower=0.3 * stretch, hand=0.2 * stretch, twist=0.08 * bank)
    p.rot("neck", z=0.3 * bank)
    p.rot("head", z=0.2 * bank, x=0.2 * stretch)
    p.rot("tail1", z=0.3 * bank)
    return p


def condor_victory(c, t):
    """A wide soaring circle, banked into the turn with the wings held
    wide, rising on the way round."""
    p = condor_idle(c, 0.0)
    s = c.motion.get("altitude", 0.5)
    _spin(c, p, z=t * TAU)
    p["root_rot"] = (p["root_rot"][0], p["root_rot"][1] + 0.35, p["root_rot"][2])
    p.move(z=math.sin(t * TAU) * s * 0.12)
    _wings(p, upper=0.05, lower=0.0, hand=0.08 * math.sin(t * TAU * 4))
    p.rot("neck", x=0.1)
    p.rot("head", x=0.1)
    return p


def dragon_idle(c, t):
    """A little dragon in the air: steady wingbeats, the tail swishing
    behind, the head bobbing and sniffing with a puff of smoke, the legs
    paddling lazily."""
    p = winged_flap(c, t, power=c.motion.get("hover_power", 0.55))
    sniff = max(0.0, math.sin(t * TAU * 2 - 1.0)) ** 3
    p.rot("neck", x=0.1 * sniff, z=0.12 * math.sin(t * TAU))
    p.rot("head", x=0.15 * sniff, z=0.1 * math.sin(t * TAU))
    p.rot("jaw", x=-0.15 * sniff)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=math.sin(t * TAU - i * 0.8) * 0.25 * (0.5 + 0.4 * i), x=-0.1)
    return p


def dragon_fidget(c, t):
    """A fire hiccup: the head rears back, the eyes squeeze, then it bursts
    out with a jolt, the jaws snapping wide and smoke everywhere, and it
    shakes its head embarrassed."""
    p = winged_flap(c, t, power=c.motion.get("hover_power", 0.55))
    rear = float(keys(t, [(0, 0), (0.25, 1), (0.45, 1), (0.5, -0.3), (0.6, 0), (1, 0)]))
    burst = float(keys(t, [(0, 0), (0.45, 0), (0.5, 1), (0.62, 0.8), (0.72, 0), (1, 0)]))
    shake = math.sin(t * TAU * 10) * float(keys(t, [(0, 0), (0.74, 0), (0.8, 1), (0.95, 0), (1, 0)]))
    p.rot("chest", x=0.12 * max(rear, 0.0) - 0.1 * burst)
    p.rot("neck", x=0.35 * max(rear, 0.0) - 0.4 * burst)
    p.rot("head", x=0.3 * max(rear, 0.0) - 0.2 * burst, y=0.3 * shake)
    p.rot("jaw", x=-0.9 * burst)
    p.move(z=c.motion.get("altitude", 0.5) * (0.05 * max(rear, 0.0) - 0.08 * burst))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.3 * max(rear, 0.0) * (0.5 + 0.3 * i), z=0.2 * math.sin(t * TAU * 6 - i) * burst)
    return p


def dragon_victory(c, t):
    """A loop-the-loop roaring fire, legs kicking, then a happy wiggle
    before it goes round again."""
    p = winged_flap(c, (t * 2) % 1, power=0.9)
    loop = float(keys(t, [(0, 0), (0.1, 0), (0.65, 1), (1, 1)]))
    wiggle = math.sin(t * TAU * 6) * float(keys(t, [(0, 0), (0.68, 0), (0.75, 1), (0.95, 0), (1, 0)]))
    _spin(c, p, x=loop * TAU)
    p.rot("neck", x=0.25)
    p.rot("head", x=0.2, z=0.2 * wiggle)
    p.rot("jaw", x=-0.7 * max(0.0, math.sin(t * TAU * 2)))
    p.rot("hips", z=0.15 * wiggle)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.3 * math.sin(t * TAU * 4) * sign, lower=0.1)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=math.sin(t * TAU * 4 - i) * 0.35)
    return p



# --- The Specialists' personas ---------------------------------------------------------

def eel_idle(c, t):
    """Low and sinuous: slow waves running down the body, the flat head
    lifting to peer about now and then, a crackle of a twitch."""
    p = Pose()
    wave = lambda k: math.sin(t * TAU - k)
    p.rot("hips", z=wave(0.0) * 0.1)
    p.rot("chest", z=-wave(0.8) * 0.1)
    p.rot("neck", z=wave(1.6) * 0.08, x=0.1 * max(0.0, math.sin(t * TAU * 2 - 1.0)) ** 2)
    p.rot("neck2", z=-wave(2.2) * 0.06, x=0.08 * max(0.0, math.sin(t * TAU * 2 - 1.0)) ** 2)
    p.rot("head", x=0.05 * math.sin(t * TAU * 2), z=0.06 * math.sin(t * TAU + 1.0))
    p.rot("jaw", x=-0.08 * max(0.0, math.sin(t * TAU * 3)) ** 3)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=wave(-0.9 * (i + 1)) * (0.14 + 0.05 * i))
    return p


def eel_fidget(c, t):
    """Charges up: the whole body stiffens and shivers with a crackle,
    the head rising, then it lets go with a jolt and goes limp again."""
    p = eel_idle(c, 0.0)
    charge = float(keys(t, [(0, 0), (0.15, 1), (0.55, 1), (0.6, 0), (1, 0)]))
    shiver = math.sin(t * TAU * 16) * charge
    jolt = float(keys(t, [(0, 0), (0.55, 0), (0.6, 1), (0.7, -0.4), (0.8, 0), (1, 0)]))
    p.rot("neck", x=0.3 * charge + 0.2 * jolt, z=0.1 * shiver)
    p.rot("neck2", x=0.2 * charge, z=-0.08 * shiver)
    p.rot("head", x=0.15 * charge - 0.1 * jolt, z=0.05 * shiver)
    p.rot("jaw", x=-0.5 * max(jolt, 0.0) - 0.1 * charge)
    p.rot("chest", z=0.06 * shiver)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=0.1 * shiver * (1 + 0.5 * i), x=0.15 * jolt)
    return p


def eel_victory(c, t):
    """Rears its front up and whips from side to side, sparking, the jaws
    snapping open in time."""
    p = eel_idle(c, 0.0)
    whip = math.sin(t * TAU * 2)
    p.rot("chest", x=0.15, z=0.2 * whip)
    p.rot("neck", x=0.35, z=0.3 * whip)
    p.rot("neck2", x=0.2, z=-0.15 * whip)
    p.rot("head", x=0.1, z=-0.15 * whip)
    p.rot("jaw", x=-0.5 * max(0.0, math.sin(t * TAU * 4)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, z=math.sin(t * TAU * 2 - i) * 0.25)
    return p


def seal_idle(c, t):
    """Lolling on its belly: a slow blubbery breath, the whiskery head
    looking about, the back flippers waving, a lazy roll onto one side and
    back."""
    p = pinniped_idle(c, t)
    roll = math.sin(t * TAU + 1.0)
    p.rot("chest", y=0.06 * roll)
    p.rot("hips", y=0.08 * roll)
    p.rot("neck", x=0.05 + 0.04 * math.sin(t * TAU * 2), z=0.2 * math.sin(t * TAU))
    p.rot("head", z=0.1 * math.sin(t * TAU))
    return p


def seal_fidget(c, t):
    """Claps its front flippers with its head thrown back, barking, then
    scratches its chin with a back flipper... no, with a front one, and
    rolls over onto its back wriggling and back again."""
    p = pinniped_idle(c, 0.0)
    clap_env = float(keys(t, [(0, 0), (0.08, 1), (0.42, 1), (0.5, 0), (1, 0)]))
    clap = max(0.0, math.sin(t * TAU * 4)) * clap_env
    roll = float(keys(t, [(0, 0), (0.5, 0), (0.62, 1), (0.82, 1), (0.95, 0), (1, 0)]))
    wriggle = math.sin(t * TAU * 6) * roll
    p.rot("neck", x=0.4 * clap_env - 0.1 * roll)
    p.rot("head", x=0.3 * clap_env)
    p.rot("jaw", x=-0.4 * clap)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.6 * clap_env + 0.4 * roll, splay=-sign * (0.6 * clap) + sign * 0.3 * wriggle * roll)
        p.leg("hl." + side, foot=0.3 * wriggle)
    p["root_rot"] = (0.0, math.pi * roll, 0.0)
    p.move(z=0.08 * roll * c.joints["withers"][2])
    return p


def seal_victory(c, t):
    """Bounces on its belly clapping its flippers, barking, its back
    flippers slapping the ground."""
    p = pinniped_idle(c, 0.0)
    s = _size(c)
    bounce = max(0.0, math.sin(t * TAU * 3))
    clap = max(0.0, math.sin(t * TAU * 3 + 0.8))
    p.move(z=s * 0.06 * bounce)
    p.rot("chest", x=-0.12 * bounce)
    p.rot("neck", x=0.3 + 0.1 * bounce)
    p.rot("head", x=0.15)
    p.rot("jaw", x=-0.4 * bounce)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.5, splay=-sign * 0.55 * clap)
        p.leg("hl." + side, foot=0.4 * math.sin(t * TAU * 3 + 1.5))
    return p


def fox_idle(c, t):
    """Sly and quick: standing light on its toes, the head cocking from
    side to side, the big ears swivelling after every sound, the brush
    swishing."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.005 * breath)
    p.rot("chest", x=0.02 * breath)
    cock = float(keys(t, [(0, 0), (0.15, 0), (0.22, 1), (0.45, 1), (0.52, -1), (0.75, -1), (0.82, 0), (1, 0)]))
    p.rot("neck", x=0.05, z=0.1 * cock)
    p.rot("head", z=0.2 * cock, y=0.3 * cock)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.35 * max(0.0, math.sin(t * TAU * 3 + sign * 1.1)) ** 2, x=-0.15)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.05, z=math.sin(t * TAU * 2 - i * 0.7) * 0.3 * (0.5 + 0.4 * i))
    return p


def fox_fidget(c, t):
    """The mouse pounce: freezes with its head cocked, crouches, springs
    high and comes down nose-first with its front paws together, then
    looks up pleased with itself."""
    p = fox_idle(c, 0.0)
    s = _scale(c)
    crouch = float(keys(t, [(0, 0), (0.2, 0), (0.32, 1), (0.4, 0), (1, 0)]))
    spring = float(keys(t, [(0, 0), (0.38, 0), (0.5, 1), (0.62, 0), (1, 0)]))
    dive = float(keys(t, [(0, 0), (0.5, 0), (0.62, 1), (0.78, 1), (0.9, 0), (1, 0)]))
    p.move(z=-s * 0.12 * crouch + s * 0.45 * spring - s * 0.1 * dive, y=s * 0.1 * spring + s * 0.15 * dive)
    p["root_rot"] = (0.15 * spring - 0.45 * dive, 0.0, 0.0)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=-0.2 * crouch + 0.9 * spring + 0.3 * dive, lower=-0.4 * crouch - 0.3 * spring - 0.4 * dive, foot=-0.3 * spring + 0.2 * dive)
        p.leg("hl." + side, upper=0.4 * crouch - 0.6 * spring, lower=-0.6 * crouch + 0.1 * spring, foot=0.5 * crouch + 0.4 * spring)
    p.rot("neck", x=0.1 * crouch - 0.3 * dive, z=0.2 * crouch)
    p.rot("head", x=-0.2 * crouch - 0.2 * dive + 0.3 * float(keys(t, [(0, 0), (0.78, 0), (0.86, 1), (0.95, 0), (1, 0)])), y=0.3 * crouch)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.3 * spring - 0.3 * dive, z=math.sin(t * TAU * 6 - i) * 0.2 * (crouch + dive))
    return p


def fox_victory(c, t):
    """Bounds on the spot like a pup, spinning round after its own brush,
    yipping."""
    p = fox_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 3))
    _spin(c, p, z=t * TAU)
    p.move(z=s * 0.25 * hop)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=0.5 * hop, lower=-0.6 * hop, foot=-0.3 * hop)
        p.leg("hl." + side, upper=-0.4 * hop, lower=-0.2 * hop, foot=0.4 * hop)
    p.rot("neck", x=0.1, z=0.3)
    p.rot("head", x=0.15 * hop, z=0.35)
    p.rot("jaw", x=-0.35 * hop)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.3, z=0.3 + math.sin(t * TAU * 6 - i) * 0.2)
    return p


def gorilla_idle(c, t):
    """Massive and calm: a slow heavy breath through the great chest, the
    knuckles shifting, the head turning deliberately to size things up, a
    lip pout now and then."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    sway = math.sin(t * TAU + 0.8)
    p.move(z=s * 0.01 * breath)
    p.rot("chest", x=0.04 * breath, z=0.025 * sway)
    p.rot("hips", z=-0.015 * sway)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.04 * breath + 0.03 * sign * sway, lower=-0.05, foot=-0.1, splay=sign * 0.03 * sway)
    look = float(keys(t, [(0, 0), (0.2, 0), (0.35, 1), (0.6, 1), (0.75, 0), (1, 0)]))
    p.rot("neck", x=0.03, z=0.3 * look)
    p.rot("head", z=0.2 * look, x=-0.03 * breath)
    p.rot("jaw", x=-0.1 * max(0.0, math.sin(t * TAU * 2 - 1.5)) ** 3)
    return p


def gorilla_fidget(c, t):
    """Picks at its ear thoughtfully with a finger, sniffs the finger,
    then scratches its armpit and yawns hugely."""
    p = gorilla_idle(c, 0.0)
    s = _scale(c)
    pick = float(keys(t, [(0, 0), (0.12, 1), (0.4, 1), (0.48, 0), (1, 0)]))
    sniff = float(keys(t, [(0, 0), (0.4, 0), (0.48, 1), (0.58, 1), (0.64, 0), (1, 0)]))
    scratch = math.sin(t * TAU * 8) * float(keys(t, [(0, 0), (0.62, 0), (0.68, 1), (0.84, 1), (0.9, 0), (1, 0)]))
    yawn = float(keys(t, [(0, 0), (0.7, 0), (0.8, 1), (0.92, 1), (1, 0)]))
    p.leg("fl.R", upper=2.6 * pick + 1.6 * sniff + 0.9 * abs(scratch), lower=-2.0 * pick - 1.9 * sniff - 1.2 * abs(scratch),
          foot=-0.3 * (pick + sniff), splay=-0.35 * pick - 0.1 * sniff + 0.3 * abs(scratch))
    p.rot("neck", z=-0.15 * pick, x=0.15 * yawn - 0.1 * sniff)
    p.rot("head", z=-0.25 * pick + 0.1 * math.sin(t * TAU * 5) * pick, x=-0.15 * sniff + 0.3 * yawn)
    p.rot("jaw", x=-0.8 * yawn)
    p.rot("chest", z=-0.05 * pick + 0.03 * scratch, x=0.08 * yawn)
    return p


def gorilla_victory(c, t):
    """Beats its chest with alternating fists, rising up tall, then lets
    out a roar with both arms flung wide, and stamps."""
    p = gorilla_idle(c, 0.0)
    s = _scale(c)
    beat = math.sin(t * TAU * 4)
    beating = float(keys(t, [(0, 0), (0.06, 1), (0.45, 1), (0.55, 0), (1, 0)]))
    wide = float(keys(t, [(0, 0), (0.48, 0), (0.6, 1), (0.84, 1), (1, 0)]))
    stamp = float(keys(t, [(0, 0), (0.82, 0), (0.88, 1), (0.94, 0), (1, 0)]))
    for side, sign in (("L", 1), ("R", -1)):
        chest = 1.2 + 0.4 * beat * sign
        p.leg("fl." + side, upper=chest * beating + 1.9 * wide, lower=-1.5 * beating - 0.2 * wide, foot=-0.3,
              splay=sign * (0.1 * beating + 0.9 * wide))
        p.leg("hl." + side, upper=0.15 * stamp, lower=-0.2 * stamp, foot=0.15 * stamp)
    p.move(z=s * 0.04 * beating * abs(beat) - s * 0.04 * stamp)
    p.rot("chest", x=0.1 * beating + 0.15 * wide, y=0.05 * beat * beating)
    p.rot("neck", x=0.05 * beating + 0.15 * wide)
    p.rot("head", x=0.2 * beating + 0.35 * wide, y=0.05 * beat * beating)
    p.rot("jaw", x=-0.4 * beating * max(0.0, beat) - 0.9 * wide)
    return p


def red_panda_idle(c, t):
    """Fluffy and curious: a bouncy little stance, the head tipping
    curiously from side to side, the ringed tail curling and waving, a paw
    lifting."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.006 * breath)
    p.rot("chest", x=0.025 * breath)
    tip = math.sin(t * TAU + 0.5)
    p.rot("neck", x=0.1, z=0.1 * tip)
    p.rot("head", z=0.25 * tip, y=0.2 * tip)
    lift = max(0.0, math.sin(t * TAU * 2 - 0.5)) ** 2
    p.leg("fl.R", upper=0.35 * lift, lower=-0.5 * lift, foot=-0.2 * lift)
    for side, sign in (("L", 1), ("R", -1)):
        p.rot("ear." + side, z=sign * 0.2 * max(0.0, math.sin(t * TAU * 2 + sign)))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.4 * (0.5 + 0.3 * i), z=math.sin(t * TAU * 2 - i * 0.8) * 0.3 * (0.5 + 0.4 * i))
    return p


def red_panda_fidget(c, t):
    """Stands up on its back legs with its paws raised to look bigger (the
    famous threat that only makes it cuter), wobbles, then drops down and
    shakes."""
    p = red_panda_idle(c, 0.0)
    s = _scale(c)
    up = float(keys(t, [(0, 0), (0.18, 1), (0.68, 1), (0.8, 0), (1, 0)]))
    wobble = math.sin(t * TAU * 5) * up
    shake = math.sin(t * TAU * 11) * float(keys(t, [(0, 0), (0.82, 0), (0.88, 1), (0.98, 0), (1, 0)]))
    _rear(c, p, 1.15 * up)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=1.9 * up + 0.1 * wobble * sign, lower=-0.6 * up, foot=-0.3 * up, splay=sign * 0.5 * up)
        p.leg("hl." + side, upper=-0.35 * up, lower=-0.1 * up, foot=0.45 * up)
        p.rot("ear." + side, z=sign * 0.5 * shake)
    p.rot("chest", z=0.06 * wobble, y=0.1 * shake)
    p.rot("neck", x=0.1 * up)
    p.rot("head", x=0.15 * up, z=0.1 * wobble, y=0.3 * shake)
    p.rot("jaw", x=-0.3 * up)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.2 * up, z=math.sin(t * TAU * 4 - i) * 0.2 * up)
    return p


def red_panda_victory(c, t):
    """Bounces around in a happy circle on its back legs, paws up, tail
    high."""
    p = red_panda_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 4))
    _rear(c, p, 1.0)
    _spin(c, p, z=t * TAU)
    p.move(z=s * 0.15 * hop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=1.8 + 0.2 * hop, lower=-0.5, foot=-0.3, splay=sign * 0.4)
        p.leg("hl." + side, upper=-0.35 - 0.2 * hop, lower=-0.1 - 0.2 * hop, foot=0.45 + 0.2 * hop)
        p.rot("ear." + side, z=sign * 0.2 * hop)
    p.rot("neck", x=0.1)
    p.rot("head", x=0.15, z=0.15 * math.sin(t * TAU * 2))
    p.rot("jaw", x=-0.4 * hop)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.1, z=math.sin(t * TAU * 8 - i) * 0.25)
    return p


def sloth_idle(c, t):
    """Slow, slow: a long breath that takes the whole loop, the head
    drifting round with the eternal smile, one arm lifting as if to reach
    for something and thinking better of it."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.006 * breath)
    p.rot("chest", x=0.03 * breath)
    p.rot("neck", x=0.1 + 0.05 * breath, z=0.15 * math.sin(t * TAU + 1.0))
    p.rot("head", z=0.12 * math.sin(t * TAU + 1.0), x=0.05 * math.sin(t * TAU * 0.5 * 2))
    reach = max(0.0, math.sin(t * TAU - 0.6)) ** 2
    p.leg("fl.L", upper=0.6 * reach, lower=-0.4 * reach, foot=-0.3 * reach)
    return p


def sloth_fidget(c, t):
    """The slowest stretch in the world: both arms reach up and out, the
    back arches, the mouth opens in a yawn that goes on and on, then it
    all comes down again."""
    p = sloth_idle(c, 0.0)
    s = _scale(c)
    stretch = float(keys(t, [(0, 0), (0.35, 1), (0.7, 1), (1, 0)]))
    yawn = float(keys(t, [(0, 0), (0.3, 0), (0.5, 1), (0.75, 1), (0.95, 0), (1, 0)]))
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=1.5 * stretch, lower=-0.3 * stretch, foot=-0.4 * stretch, splay=sign * 0.35 * stretch)
        p.leg("hl." + side, upper=-0.1 * stretch, lower=0.05 * stretch)
    p.rot("chest", x=0.15 * stretch)
    p.rot("neck", x=0.2 * stretch)
    p.rot("head", x=0.3 * yawn)
    p.rot("jaw", x=-0.8 * yawn)
    p.move(z=s * 0.04 * stretch)
    return p


def sloth_victory(c, t):
    """A slow-motion celebration: one arm goes up... and the other... and
    it sways, grinning, taking its time, a tiny hop at the end."""
    p = sloth_idle(c, 0.0)
    s = _scale(c)
    left = float(keys(t, [(0, 0), (0.25, 1), (0.8, 1), (1, 0)]))
    right = float(keys(t, [(0, 0), (0.3, 0), (0.55, 1), (0.8, 1), (1, 0)]))
    sway = math.sin(t * TAU * 2) * right
    hop = float(keys(t, [(0, 0), (0.82, 0), (0.88, 1), (0.94, 0), (1, 0)]))
    p.leg("fl.L", upper=1.6 * left, lower=-0.3 * left, foot=-0.3 * left, splay=0.3 * left)
    p.leg("fl.R", upper=1.6 * right, lower=-0.3 * right, foot=-0.3 * right, splay=-0.3 * right)
    p.rot("chest", z=0.08 * sway, x=0.05 * right)
    p.rot("neck", x=0.15 * right, z=0.1 * sway)
    p.rot("head", x=0.1 * right, z=0.1 * sway)
    p.rot("jaw", x=-0.3 * right)
    p.move(z=s * 0.12 * hop)
    return p


def pangolin_idle(c, t):
    """Shy and shuffly: the pointed head low and swinging slowly as it
    sniffs, the front claws tucked up, the heavy tail dragging and
    swaying, a scale-rattling shiver now and then."""
    p = Pose()
    s = _scale(c)
    breath = math.sin(t * TAU)
    p.move(z=s * 0.004 * breath)
    p.rot("chest", x=0.02 * breath)
    p.rot("neck", x=-0.2, z=0.15 * math.sin(t * TAU + 0.5))
    p.rot("head", x=-0.05 + 0.04 * math.sin(t * TAU * 3), z=0.1 * math.sin(t * TAU + 0.5))
    shiver = math.sin(t * TAU * 12) * max(0.0, math.sin(t * TAU * 2 - 2.0)) ** 6
    p.rot("chest", y=0.04 * shiver)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=0.25, lower=-0.45, foot=0.2)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.05, z=math.sin(t * TAU - i * 0.6) * 0.12 * (0.5 + 0.4 * i))
    return p


def pangolin_fidget(c, t):
    """Startles, curls up tight into a ball, rocks there a moment, then
    unrolls and peeks out."""
    p = pangolin_idle(c, 0.0)
    s = _scale(c)
    curl = float(keys(t, [(0, 0), (0.08, 1), (0.6, 1), (0.78, 0), (1, 0)]))
    rock = math.sin(t * TAU * 4) * float(keys(t, [(0, 0), (0.15, 1), (0.55, 1), (0.62, 0), (1, 0)]))
    peek = float(keys(t, [(0, 0), (0.78, 0), (0.86, 1), (0.95, 0), (1, 0)]))
    _rear(c, p, 0.5 * curl)
    p.move(z=-s * 0.2 * curl)
    p.rot("hips", x=0.35 * curl)
    p.rot("chest", x=-0.5 * curl, y=0.12 * rock)
    p.rot("neck", x=-0.7 * curl + 0.3 * peek)
    p.rot("head", x=-0.3 * curl + 0.2 * peek, z=0.2 * peek)
    for side in ("L", "R"):
        p.leg("fl." + side, upper=0.9 * curl, lower=-1.6 * curl, foot=0.3 * curl)
        p.leg("hl." + side, upper=0.9 * curl, lower=-1.4 * curl, foot=0.6 * curl)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.55 * curl, z=0.15 * rock)
    return p


def pangolin_victory(c, t):
    """Rolls up into a ball and spins round on the spot like a top, then
    pops open with its claws up."""
    p = pangolin_idle(c, 0.0)
    s = _scale(c)
    ball = float(keys(t, [(0, 0), (0.1, 1), (0.6, 1), (0.72, 0), (1, 0)]))
    pop = float(keys(t, [(0, 0), (0.7, 0), (0.78, 1), (0.92, 1), (1, 0)]))
    _rear(c, p, 0.5 * ball + 0.6 * pop)
    _spin(c, p, z=TAU * float(keys(t, [(0, 0), (0.1, 0), (0.6, 1), (1, 1)])))
    p.move(z=-s * 0.2 * ball)
    p.rot("hips", x=0.35 * ball)
    p.rot("chest", x=-0.5 * ball + 0.1 * pop)
    p.rot("neck", x=-0.7 * ball + 0.3 * pop)
    p.rot("head", x=-0.3 * ball + 0.2 * pop)
    p.rot("jaw", x=-0.3 * pop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.9 * ball + 1.4 * pop, lower=-1.6 * ball - 0.8 * pop, foot=0.3 * ball - 0.3 * pop, splay=sign * 0.3 * pop)
        p.leg("hl." + side, upper=0.9 * ball - 0.2 * pop, lower=-1.4 * ball, foot=0.6 * ball + 0.3 * pop)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=-0.55 * ball - 0.3 * pop)
    return p


def kraken_idle(c, t):
    """Cheeky: the big head bobbing and tilting, the eyes drifting about,
    the walking tentacles shuffling and the spare ones curling and
    uncurling, a bubbly grin."""
    p = Pose()
    s = _scale(c)
    bob = math.sin(t * TAU)
    p.move(z=s * 0.012 * bob)
    p.rot("chest", x=0.03 * bob, z=0.04 * math.sin(t * TAU + 1.0))
    p.rot("neck", z=0.12 * math.sin(t * TAU + 0.5))
    p.rot("head", z=0.15 * math.sin(t * TAU + 0.5), x=0.05 * bob)
    for side, sign in (("L", 1), ("R", -1)):
        curl = math.sin(t * TAU * 2 + sign * 0.8)
        p.leg("fl." + side, upper=0.15 * curl, lower=-0.3 * curl, foot=-0.2 * curl)
        p.leg("hl." + side, upper=-0.1 * curl, lower=0.25 * curl, foot=0.2 * curl)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.3 * math.sin(t * TAU - i * 0.8), z=0.2 * math.sin(t * TAU * 2 - i))
    p.rot("jaw", x=-0.15 * max(0.0, math.sin(t * TAU * 2 - 0.5)))
    return p


def kraken_fidget(c, t):
    """Squeezes its eyes shut and blows a big bubble: the head swells up,
    up, then pops back with a wobble, tentacles flailing."""
    p = kraken_idle(c, 0.0)
    s = _scale(c)
    swell = float(keys(t, [(0, 0), (0.3, 1), (0.55, 1.1), (0.6, -0.3), (0.72, 0.1), (0.8, 0), (1, 0)]))
    flail = math.sin(t * TAU * 8) * float(keys(t, [(0, 0), (0.58, 0), (0.62, 1), (0.85, 0), (1, 0)]))
    p.move(z=s * 0.12 * max(swell, 0.0))
    p.rot("chest", x=0.1 * max(swell, 0.0) - 0.15 * max(-swell, 0.0) / 0.3)
    p.rot("neck", x=0.25 * max(swell, 0.0), z=0.1 * flail)
    p.rot("head", x=0.2 * max(swell, 0.0) - 0.2 * max(-swell, 0.0) / 0.3, z=0.15 * flail)
    p.rot("jaw", x=-0.5 * max(swell, 0.0) - 0.4 * max(-swell, 0.0) / 0.3)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.5 * max(swell, 0.0) + 0.4 * flail * sign, lower=-0.6 * max(swell, 0.0), foot=-0.3 * flail)
        p.leg("hl." + side, upper=-0.2 * flail * sign, lower=0.3 * max(swell, 0.0))
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.4 * max(swell, 0.0), z=0.4 * flail * (0.5 + 0.3 * i))
    return p


def kraken_victory(c, t):
    """A happy tentacle dance: it spins slowly with its spare tentacles
    waving in the air and its walking ones hopping, grinning wide."""
    p = kraken_idle(c, 0.0)
    s = _scale(c)
    hop = max(0.0, math.sin(t * TAU * 4))
    _spin(c, p, z=t * TAU)
    p.move(z=s * 0.15 * hop)
    for side, sign in (("L", 1), ("R", -1)):
        p.leg("fl." + side, upper=0.9 + 0.4 * math.sin(t * TAU * 3) * sign, lower=-0.5, foot=-0.4, splay=sign * 0.5)
        p.leg("hl." + side, upper=-0.3 * hop, lower=0.3 * hop, foot=0.2 * hop)
    p.rot("neck", x=0.15)
    p.rot("head", x=0.2, z=0.2 * math.sin(t * TAU * 2))
    p.rot("jaw", x=-0.5 - 0.2 * hop)
    for i, bone in enumerate(("tail1", "tail2", "tail3")):
        p.rot(bone, x=0.6 * (0.5 + 0.3 * i), z=math.sin(t * TAU * 3 - i) * 0.5)
    return p


PERSONAS = {
    "yeti": {"idle": yeti_idle, "fidget": yeti_fidget, "victory": yeti_victory},
    "eel": {"idle": eel_idle, "fidget": eel_fidget, "victory": eel_victory},
    "seal": {"idle": seal_idle, "fidget": seal_fidget, "victory": seal_victory},
    "fox": {"idle": fox_idle, "fidget": fox_fidget, "victory": fox_victory},
    "gorilla": {"idle": gorilla_idle, "fidget": gorilla_fidget, "victory": gorilla_victory},
    "red_panda": {"idle": red_panda_idle, "fidget": red_panda_fidget, "victory": red_panda_victory},
    "sloth": {"idle": sloth_idle, "fidget": sloth_fidget, "victory": sloth_victory},
    "pangolin": {"idle": pangolin_idle, "fidget": pangolin_fidget, "victory": pangolin_victory},
    "kraken": {"idle": kraken_idle, "fidget": kraken_fidget, "victory": kraken_victory},
    "falcon": {"idle": falcon_idle, "fidget": falcon_fidget, "victory": falcon_victory, "portrait": hero_falcon},
    "owl": {"idle": owl_idle, "fidget": owl_fidget, "victory": owl_victory, "portrait": perched},
    "eagle": {"idle": eagle_idle, "fidget": eagle_fidget, "victory": eagle_victory, "portrait": perched},
    "macaw": {"idle": macaw_idle, "fidget": macaw_fidget, "victory": macaw_victory, "portrait": perched},
    "condor": {"idle": condor_idle, "fidget": condor_fidget, "victory": condor_victory, "portrait": perched},
    "dragon": {"idle": dragon_idle, "fidget": dragon_fidget, "victory": dragon_victory},
    "squirrel": {"idle": squirrel_idle, "fidget": squirrel_fidget, "victory": squirrel_victory},
    "raccoon": {"idle": raccoon_idle, "fidget": raccoon_fidget, "victory": raccoon_victory},
    "skunk": {"idle": skunk_idle, "fidget": skunk_fidget, "victory": skunk_victory},
    "cobra": {"idle": cobra_idle, "fidget": cobra_fidget, "victory": cobra_victory, "portrait": hero_cobra},
    "camel": {"idle": camel_idle, "fidget": camel_fidget, "victory": camel_victory},
    "orangutan": {"idle": orangutan_idle, "fidget": orangutan_fidget, "victory": orangutan_victory},
    "unicorn": {"idle": unicorn_idle, "fidget": unicorn_fidget, "victory": unicorn_victory},
    "lion": {"idle": lion_idle, "fidget": lion_fidget, "victory": lion_victory},
    "tiger": {"idle": tiger_idle, "fidget": tiger_fidget, "victory": tiger_victory},
    "boar": {"idle": boar_idle, "fidget": boar_fidget, "victory": boar_victory},
    "wolf": {"idle": wolf_idle, "fidget": wolf_fidget, "victory": wolf_victory},
    "badger": {"idle": badger_idle, "fidget": badger_fidget, "victory": badger_victory},
    "cerberus": {"idle": cerberus_idle, "fidget": cerberus_fidget, "victory": cerberus_victory},
    "bear": {"idle": bear_idle, "fidget": bear_fidget, "victory": bear_victory, "portrait": hero_bear},
    "panda": {"idle": panda_idle, "fidget": panda_fidget, "victory": panda_victory},
    "hippo": {"idle": hippo_idle, "fidget": hippo_fidget, "victory": hippo_victory},
    "elephant": {"idle": elephant_idle, "fidget": elephant_fidget, "victory": elephant_victory},
    "rhino": {"idle": rhino_idle, "fidget": rhino_fidget, "victory": rhino_victory},
    "turtle": {"idle": turtle_idle, "fidget": turtle_fidget, "victory": turtle_victory},
}

ATTACKS.update({"slam": slam, "rake": rake, "lob": lob, "handstand": handstand, "leap": leap,
                "tail_slap": tail_slap, "ram": ram, "pound": pound})
HIT_AT.update({"slam": 0.55, "rake": 0.5, "lob": 0.5, "handstand": 0.5, "leap": 0.5, "tail_slap": 0.5,
               "ram": 0.45, "special": 0.72, "pound": 0.6})


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
    "fidget": (fidget, 10, 10, False),
    # Only for animals with a second attack (motion["attack2"]).
    "attack2": (attack2, 10, 16, False),
    # Only for Stun animals (motion["special"]): the big wind-up.
    "special": (special, 14, 14, False),
    # Only kept for the animals rendered with it (the game celebrates
    # without it otherwise); motion["victory_render"] renders it.
    "victory": (victory, 10, 10, True),
}
# Not in sheets any more (the game's knockouts are a cartoon poof), but kept
# for previews: python strip.py <id> death
EXTRA = {"death": (death, 6, 10, False)}


def portrait_pose(c):
    """The pose for the card portrait: a persona's own (a bird perched)
    or the first frame of the idle."""
    persona = PERSONAS.get(c.motion.get("persona"), {})
    if "portrait" in persona:
        return persona["portrait"](c)
    return idle(c, 0.0)


def animations_for(c, existing=()):
    """The animations this creature's sheet has: the second attack and the
    special only if it has them, the victory only if it's asked for or the
    sheet in `existing` already has one."""
    out = {}
    for name, spec in ANIMATIONS.items():
        if name == "attack2" and not c.motion.get("attack2"):
            continue
        if name == "special" and not c.motion.get("special"):
            continue
        if name == "victory" and not (c.motion.get("victory_render") or name in existing):
            continue
        out[name] = spec
    return out


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
    fn = {**ANIMATIONS, **EXTRA}[name][0]
    apply(arm, fn(creature, float(when or 0)))
