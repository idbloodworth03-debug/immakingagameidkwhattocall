"""Attacks, played from key poses (strikes.json).

An attack is a short list of poses and the moment each is reached: the
wind-up (the body going the other way first, held a beat), the strike (a
couple of frames, landing on the clip's hit moment exactly), the
follow-through (the blow carrying on past the hit) and the way back. This
module blends between them, lets the loose parts (tail, ears, head) trail
a little behind the body and wobble to a stop after the hit, and squashes
and stretches the body. Every number is in strikes.json; tools/creatures/
README.md ("Attacks") explains how to write one.

A clip's length and its hit moment are motion.py's (ANIMATIONS, HIT_AT),
as before: the game times its hits to them.
"""
import json
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = json.load(open(os.path.join(HERE, "strikes.json")))
GAME = os.path.join(HERE, "..", "..", "game")

AXES = "xyz"
# The whole body's channels (a pose's top-level numbers).
BODY = ("rear", "dip", "pitch", "turn", "roll", "squash", "stretch", "swell")


def _ease(kind, u):
    """How a pose is arrived at: "out" brakes into it (a wind-up settling),
    "in" speeds into it (a strike landing at full speed), "inout" does
    both, "linear" neither; "hold" stays on the pose before until the very
    end."""
    u = min(max(u, 0.0), 1.0)
    if kind == "in":
        return u * u * u
    if kind == "in2":
        return u * u
    if kind == "out":
        return 1.0 - (1.0 - u) ** 3
    if kind == "out2":
        return 1.0 - (1.0 - u) ** 2
    if kind == "linear":
        return u
    if kind == "hold":
        return 1.0 if u >= 1.0 else 0.0
    return u * u * (3.0 - 2.0 * u)


def _merge(base, over):
    """`over` laid on `base`: tables merge, anything else replaces."""
    out = dict(base)
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict) and not value.get("replace"):
            out[key] = _merge(out[key], value)
        else:
            out[key] = value
    return out


def spec_of(c, style):
    """An animal's attack of a style: the style's own (strikes.json
    "styles"), its body plan's if that has one (a snake's bite is not a
    wolf's), then the animal's own changes on top ("animals")."""
    spec = DATA["styles"].get(style)
    body = DATA.get("bodies", {}).get(c.motion.get("body") or c.motion.get("gait") or "", {}).get(style)
    if body is not None:
        spec = body if spec is None or body.get("replace") else _merge(spec, body)
    own = DATA.get("animals", {}).get(c.name, {}).get(style)
    if own is not None:
        spec = own if spec is None else _merge(spec, own)
    return _whole(spec)


def _whole(spec, depth=0):
    """A style built on another ("like": its name, or "body.style" for a
    body plan's), with its own keys and poses laid on top."""
    if spec is None or "like" not in spec or depth > 4:
        return spec
    name = spec["like"]
    if "." in name:
        body, style = name.split(".", 1)
        base = DATA.get("bodies", {}).get(body, {}).get(style)
    else:
        base = DATA["styles"].get(name)
    if base is None:
        raise KeyError(f"strikes.json: no style '{name}' to build on")
    return _merge(_whole(base, depth + 1), {k: v for k, v in spec.items() if k != "like"})


def has(c, style):
    """Whether an animal's attack of a style is played from key poses: its
    name is on the roster (strikes.json) and the style has them."""
    return c.name in DATA.get("roster", []) and spec_of(c, style) is not None


def _channels(spec, poses, depth=0):
    """A key pose as {channel: value}. A pose may build on another one
    ("like": its name, "times": how much of it), with its own numbers laid
    on top."""
    out = {}
    if "like" in spec and depth < 8:
        k = float(spec.get("times", 1.0))
        out = {ch: v * k for ch, v in _channels(poses[spec["like"]], poses, depth + 1).items()}
    for name in BODY:
        if name in spec:
            out[("body", name)] = float(spec[name])
    if "move" in spec:
        for i, axis in enumerate(AXES):
            out[("move", axis)] = float(spec["move"][i])
    for bone, rot in spec.get("bones", {}).items():
        for i, axis in enumerate(AXES):
            out[("rot", bone, axis)] = float(rot[i])
    for leg, values in spec.get("legs", {}).items():
        kind, side = leg.split(".")
        values = list(values) + [0.0] * (4 - len(values))
        out[("rot", f"{kind}_upper.{side}", "x")] = float(values[0])
        out[("rot", f"{kind}_lower.{side}", "x")] = float(values[1])
        out[("rot", f"{kind}_foot.{side}", "x")] = float(values[2])
        out[("rot", f"{kind}_upper.{side}", "z")] = float(values[3])
    if "wings" in spec:
        # Both wings, as motion._wings: raise at the shoulder, the elbow
        # and the hand, sweep back, twist.
        w = list(spec["wings"]) + [0.0] * (5 - len(spec["wings"]))
        for side, sign in (("L", 1.0), ("R", -1.0)):
            out[("rot", "wing_upper." + side, "x")] = w[0]
            out[("rot", "wing_lower." + side, "x")] = w[1]
            out[("rot", "wing_hand." + side, "x")] = w[2]
            out[("rot", "wing_upper." + side, "z")] = -w[3] * sign
            out[("rot", "wing_lower." + side, "z")] = -w[3] * 0.6 * sign
            out[("rot", "wing_hand." + side, "z")] = -w[3] * 0.4 * sign
            out[("rot", "wing_upper." + side, "y")] = w[4] * sign
    if "tail" in spec:
        # The whole tail: curl (up is below 0) and swing to its left.
        curl, swing = (list(spec["tail"]) + [0.0])[:2]
        for i, bone in enumerate(("tail1", "tail2", "tail3")):
            out[("rot", bone, "x")] = curl * (0.8 + 0.2 * i) / 3.0
            out[("rot", bone, "z")] = swing * (0.6 + 0.3 * i) / 3.0
    if "trunk" in spec:
        curl, swing = (list(spec["trunk"]) + [0.0])[:2]
        for bone, k, kz in (("trunk1", 0.5, 0.5), ("trunk2", 0.8, 0.7), ("trunk3", 1.0, 1.0)):
            out[("rot", bone, "x")] = curl * k
            out[("rot", bone, "z")] = swing * kz
    if "ears" in spec:
        # Both ears: back (below 0 lays them flat) and out to the sides.
        back, out_ = (list(spec["ears"]) + [0.0])[:2]
        for side, sign in (("L", 1.0), ("R", -1.0)):
            out[("rot", "ear." + side, "x")] = back
            out[("rot", "ear." + side, "z")] = out_ * sign
    for bone, size in spec.get("scale", {}).items():
        for i, axis in enumerate(AXES):
            out[("scale", bone, axis)] = float(size[i]) - 1.0
    for bone, by in spec.get("shift", {}).items():
        for i, axis in enumerate(AXES):
            out[("shift", bone, axis)] = float(by[i])
    return out


def _when(value, hit):
    """A key's moment in the clip (0-1): a number, or "hit", "hit-0.2",
    "hit+0.07" (so a style keeps its shape whatever its hit moment)."""
    if isinstance(value, str):
        rest = value.replace("hit", "", 1).strip()
        return hit + (float(rest) if rest else 0.0)
    return float(value)


def _mirrored(channels):
    """The same pose led by the other side."""
    out = {}
    for ch, v in channels.items():
        kind = ch[0]
        if kind in ("rot", "scale", "shift"):
            bone = ch[1]
            if bone.endswith(".L"):
                bone = bone[:-2] + ".R"
            elif bone.endswith(".R"):
                bone = bone[:-2] + ".L"
            flip = (kind == "rot" and ch[2] in ("y", "z")) or (kind == "shift" and ch[2] == "x")
            out[(kind, bone, ch[2])] = -v if flip else v
        elif ch in (("body", "turn"), ("body", "roll"), ("move", "x")):
            out[ch] = -v
        else:
            out[ch] = v
    return out


def _lags(spec):
    """How far behind the body each loose bone runs, as a share of the
    clip. "tail", "ears", "trunk" and "wings" name their bones (each tail
    bone a little further behind than the one before: a whip)."""
    out = {}
    for name, lag in spec.get("lag", {}).items():
        if name == "tail":
            for i, bone in enumerate(("tail1", "tail2", "tail3")):
                out[bone] = lag * (i + 1)
        elif name == "trunk":
            for i, bone in enumerate(("trunk1", "trunk2", "trunk3")):
                out[bone] = lag * (i + 1)
        elif name == "ears":
            out["ear.L"] = out["ear.R"] = lag
        elif name == "wings":
            for side in ("L", "R"):
                for i, part in enumerate(("wing_upper", "wing_lower", "wing_hand")):
                    out[f"{part}.{side}"] = lag * i
        else:
            out[name] = lag
    return out


def _wobbles(spec):
    """Loose bones springing to a stop after the hit: {bone: (axis, size
    in radians, swings, how fast it dies)}."""
    out = {}
    for name, w in spec.get("wobble", {}).items():
        w = list(w)
        axis = w.pop(0) if isinstance(w[0], str) else "x"
        size, swings, die = (w + [2.0, 3.0])[:3]
        if name == "tail":
            for i, bone in enumerate(("tail1", "tail2", "tail3")):
                out[bone] = (axis, size * (0.6 + 0.3 * i), swings, die, 0.25 * i)
        elif name == "trunk":
            for i, bone in enumerate(("trunk1", "trunk2", "trunk3")):
                out[bone] = (axis, size * (0.6 + 0.3 * i), swings, die, 0.25 * i)
        elif name == "ears":
            out["ear.L"] = out["ear.R"] = (axis, size, swings, die, 0.0)
        else:
            out[name] = (axis, size, swings, die, 0.0)
    return out


def _shivers(spec):
    """Loose bones trembling through the wind-up's held beat (a rattling
    tail, a wiggling rump): {bone: (axis, size in radians, shakes)}."""
    out = {}
    for name, w in spec.get("shiver", {}).items():
        w = list(w)
        axis = w.pop(0) if isinstance(w[0], str) else "z"
        size, shakes = (w + [3.0])[:2]
        if name == "tail":
            for i, bone in enumerate(("tail1", "tail2", "tail3")):
                out[bone] = (axis, size * (0.5 + 0.5 * i), shakes, 0.2 * i)
        else:
            out[name] = (axis, size, shakes, 0.0)
    return out


class Clip:
    """One animal's attack, ready to sample."""

    def __init__(self, c, style, hit):
        spec = spec_of(c, style)
        self.spec = spec
        self.hit = hit
        poses = dict(spec.get("poses", {}))
        poses.setdefault("rest", {})
        mirror = bool(spec.get("mirror"))
        self.stance = _channels(spec.get("stance", {}), poses)
        if mirror:
            self.stance = _mirrored(self.stance)
        self.keys = []
        for key in spec["keys"]:
            when, name = key[0], key[1]
            ease = key[2] if len(key) > 2 else "inout"
            channels = _channels(poses[name], poses)
            self.keys.append((_when(when, hit), _mirrored(channels) if mirror else channels, ease))
        self.keys.sort(key=lambda k: k[0])
        self.lags = _lags(spec)
        self.wobbles = _wobbles(spec)
        self.shivers = _shivers(spec)
        # The held beat: from the first pose reached to the hit.
        self.beat = self.keys[1][0] if len(self.keys) > 1 else 0.0
        if mirror:
            flip = lambda bone: bone[:-2] + (".R" if bone.endswith(".L") else ".L") if bone[-2:] in (".L", ".R") else bone
            self.lags = {flip(b): v for b, v in self.lags.items()}
            self.wobbles = {flip(b): v for b, v in self.wobbles.items()}
            self.shivers = {flip(b): v for b, v in self.shivers.items()}
        self.gain = 1.0
        self.all = set(self.stance)
        for _, channels, _ in self.keys:
            self.all.update(channels)

    def value(self, channel, t):
        keys = self.keys
        if t <= keys[0][0]:
            return keys[0][1].get(channel, 0.0)
        for (t0, a, _), (t1, b, ease) in zip(keys, keys[1:]):
            if t <= t1:
                u = _ease(ease, (t - t0) / max(t1 - t0, 1e-9))
                v0, v1 = a.get(channel, 0.0), b.get(channel, 0.0)
                return v0 + (v1 - v0) * u
        return keys[-1][1].get(channel, 0.0)

    def sample(self, t):
        """{channel: value} at a moment of the clip (0-1), the stance
        included."""
        out = {}
        for channel in self.all:
            when = t
            bone = channel[1] if channel[0] in ("rot", "scale", "shift") else None
            lag = self.lags.get(bone, 0.0) if bone else 0.0
            if lag:
                # Trailing behind, and caught up by the end of the clip.
                when = max(0.0, t - lag * min(1.0, (1.0 - t) / 0.12))
            v = self.value(channel, when)
            if self.gain != 1.0 and ((channel == ("move", "y") and v > 0.0) or (channel[0] == "shift" and self.gain < 1.0)):
                # (The reach rule: its own travel forward, drawn in or let out.)
                v *= self.gain
            out[channel] = self.stance.get(channel, 0.0) + v
        if self.shivers and self.beat * 0.5 < t < self.hit:
            u = (t - self.beat * 0.5) / max(1e-6, self.hit - self.beat * 0.5)
            for bone, (axis, size, shakes, late) in self.shivers.items():
                bump = size * math.sin(math.tau * (u * shakes - late)) * math.sin(math.pi * u) ** 0.6
                out[("rot", bone, axis)] = out.get(("rot", bone, axis), 0.0) + bump
        if t > self.hit:
            u = (t - self.hit) / max(1e-6, 1.0 - self.hit)
            for bone, (axis, size, swings, die, late) in self.wobbles.items():
                phase = max(0.0, u * swings - late)
                bump = size * math.sin(math.tau * phase) * math.exp(-die * u) * (1.0 - u)
                out[("rot", bone, axis)] = out.get(("rot", bone, axis), 0.0) + bump
        return out


    def keep(self, motion, c):
        """The reach rule for this clip: (where its front and its back end
        are as it starts, how far forward its front may be at the hit and
        at most, how far back its back end), or None when it has no reach
        to keep to. Its own steps forward and its bones' slides are drawn
        in (or, for a lunge, let out) to fit: self.gain; where a pose
        would still pass the mark, the body is held at it (held())."""
        if not hasattr(self, "_keep"):
            self._keep = None
            allowed = _reach(c)
            if allowed is not None:
                at_hit, most, backward = allowed
                at_hit *= float(self.spec.get("reach", 1.0))
                most *= float(self.spec.get("reach", 1.0))
                front0, back0 = _ends(c, _pose(motion, c, self.sample(0.0)))
                moments = [i / 40.0 for i in range(41)] + [self.hit]

                def travel():
                    ends = [_ends(c, _pose(motion, c, self.sample(t))) for t in moments]
                    return max(e[0] for e in ends) - front0, ends[-1][0] - front0, back0 - min(e[1] for e in ends)

                far, hit, behind = travel()
                first = (far, hit)
                # A lunge ("fill") steps as far as its reach allows, whatever
                # the animal's build; any other clip only ever steps less.
                # (A shooter stands off and has nothing to step up to.)
                shooter = bool(_BODIES["bodies"].get(c.name, {}).get("shooter"))
                more = (4.0, 3.0, 2.5, 2.0, 1.7, 1.45, 1.2) if self.spec.get("fill") and not shooter else ()
                for gain in more + (1.0, 0.85, 0.7, 0.55, 0.4, 0.25, 0.1, 0.0):
                    self.gain = gain
                    far, hit, behind = travel()
                    if far <= most * 1.001 and hit <= at_hit * 1.001:
                        break
                self._keep = (front0, back0, at_hit, most, backward)
                self.travel = {"asked_most": first[0], "asked_at_hit": first[1], "gain": self.gain, "ahead_at_hit": min(hit, at_hit),
                               "ahead_most": min(far, most), "behind": min(behind, backward),
                               "held": max(0.0, hit - at_hit, far - most), "allowed": (at_hit, most, backward)}
        return self._keep

    def held(self, c, p, t):
        """How far to slide the body in a pose so that its front is no
        further forward than the rule allows at this moment (its mark at
        the hit, easing out to its furthest just after), nor its back end
        further back: like meeting a wall, it stops there and the rest of
        the pose carries on."""
        front0, back0, at_hit, most, backward = self._keep
        front, back = _ends(c, p)
        mark = at_hit + (most - at_hit) * min(1.0, max(0.0, (t - self.hit) / 0.05))
        slide = 0.0
        if front - front0 > mark:
            slide -= front - front0 - mark
        if back0 - back > backward:
            slide += back0 - back - backward
        return slide


_CLIPS = {}


def clip(c, style, hit):
    key = (c.name, style, hit, id(DATA))
    if key not in _CLIPS:
        _CLIPS[key] = Clip(c, style, hit)
    return _CLIPS[key]


def play(motion, c, style, t):
    """The pose of an animal's attack of a style at t (0-1): a motion.Pose
    with the bones' turns, the body's move and turn, and (new with these
    attacks) bones' sizes ("scale") and slides ("shift"). Its body never
    travels further than its reach allows (the reach rule, below)."""
    hit = motion.HIT_AT.get(style, 0.45)
    cl = clip(c, style, hit)
    p = _pose(motion, c, cl.sample(t))
    keep = cl.keep(motion, c)
    if keep is not None:
        slide = cl.held(c, p, t)
        if abs(slide) > 1e-9:
            p.move(y=slide)
    return p


def _pose(motion, c, values):
    """A motion.Pose from a clip's channels."""
    p = motion.Pose()
    bones = {}
    for channel, v in values.items():
        if channel[0] == "rot" and abs(v) > 1e-6:
            rot = bones.setdefault(channel[1], [0.0, 0.0, 0.0])
            rot[AXES.index(channel[2])] += v
    known = {b.name for b in c.bones}
    gape = float(c.motion.get("gape", DATA.get("gape", 0.5)))
    for bone, rot in bones.items():
        if bone not in known:
            continue
        if bone == "jaw":
            # A jaw's opening is in the animal's own gapes (a hippo's is huge).
            rot = [rot[0] * gape, rot[1], rot[2]]
        p.rot(bone, *rot)
    body = lambda name: values.get(("body", name), 0.0)
    s = _unit(motion, c)
    rear, dip = body("rear"), body("dip")
    # (Where the feet stand, from the rig's own origin: the body turns about that.)
    hind_y = _toe(c, "hind")
    front_y = _toe(c, "front")
    if abs(rear) > 1e-6:
        # Nose up, the hind feet staying where they stand.
        p.move(y=hind_y * (1 - math.cos(rear)), z=-hind_y * math.sin(rear))
    if abs(dip) > 1e-6:
        # Nose down, the front feet staying where they stand.
        p.move(y=front_y * (1 - math.cos(dip)), z=front_y * math.sin(dip))
    pitch = rear - dip + body("pitch")
    turn, roll = body("turn"), body("roll")
    if abs(turn) > 1e-6:
        # Turning on the feet it stands on: the hind ones when reared up,
        # the front ones when tipped forward, else on the spot.
        about = hind_y * min(1.0, abs(rear) / 0.3) + front_y * min(1.0, abs(dip) / 0.3)
        p.move(x=about * math.sin(turn), y=about * (1 - math.cos(turn)))
    if any(abs(v) > 1e-6 for v in (pitch, roll, turn)):
        rr = p.get("root_rot", (0.0, 0.0, 0.0))
        p["root_rot"] = (rr[0] + pitch, rr[1] + roll, rr[2] + turn)
    move = [values.get(("move", axis), 0.0) * s for axis in AXES]
    if any(abs(v) > 1e-9 for v in move):
        p.move(*move)
    scale, shift = {}, {}
    squash, stretch, swell = body("squash"), body("stretch"), body("swell")
    if any(abs(v) > 1e-6 for v in (squash, stretch, swell)):
        # The whole body, about the ground under it, keeping its volume:
        # squashed lower and wider, stretched longer and thinner, or
        # swollen all round (a puffed-up threat).
        tall = 1.0 - squash
        long = 1.0 + stretch
        wide = 1.0 / math.sqrt(max(0.2, tall * long))
        k = 1.0 + swell
        scale["root"] = (wide * k, long * k, tall * k)
    for channel, v in values.items():
        if channel[0] == "scale" and channel[1] in known:
            cur = scale.setdefault(channel[1], [1.0, 1.0, 1.0])
            cur = list(cur)
            cur[AXES.index(channel[2])] *= 1.0 + v
            scale[channel[1]] = tuple(cur)
        elif channel[0] == "shift" and channel[1] in known and abs(v) > 1e-9:
            cur = list(shift.get(channel[1], (0.0, 0.0, 0.0)))
            cur[AXES.index(channel[2])] += v * s
            shift[channel[1]] = tuple(cur)
    scale = {b: v for b, v in scale.items() if any(abs(x - 1.0) > 1e-5 for x in v)}
    if scale:
        p["scale"] = scale
    if shift:
        p["shift"] = shift
    return p


def _unit(motion, c):
    """What a pose's moves and slides are measured in: the animal's height
    at the shoulder (a field tile for a flier, a legless body's length)."""
    if c.motion.get("body") in ("bird", "winged"):
        # A flier's moves are in field tiles: it flies a set height over the
        # field (feel.json acting air_height_tiles) and stoops onto animals
        # standing on it, whatever its own size.
        _reach(c)
        model = _BODIES["models"].get(c.name)
        return 1.0 / float(model["tile_scale"]) if model else float(c.motion.get("altitude", 0.5)) * 0.5
    if "withers" in c.joints and c.joints["withers"][2] > 0.05 and c.motion.get("body") not in ("serpent", "pinniped"):
        return c.joints["withers"][2]
    return motion._size(c)


def _toe(c, which):
    for name in (f"{which}_toe.L", "foot.L"):
        if name in c.joints:
            return c.joints[name][1]
    return c.joints["root"][1]


# --- The reach rule ---------------------------------------------------------------
# In a fight an animal stands its reach away from its target (bodies.json),
# and the game's own lunge carries it part of the way across (feel.json
# combat lunge_gap_share). So a clip's own travel is held to the rest: at
# the hit its front (its nose, a paw) is at most "reach_at_hit" of its
# reach ahead of where it stood, and never more than "reach_most"; a
# shooter, which stands far off, and a flier, which is over its target,
# have their own allowances; nor does its back end push further back than
# "back_tiles" into whoever stands behind (strikes.json "limits"). A clip
# that would go further has its own steps forward drawn in; and where a
# pose still passes the mark (a long arm, a bowing head), the body is held
# there as if it met a wall, while the pose carries on.

def _euler(rx, ry, rz):
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return mz @ my @ mx


_RESTS = {}


def _rests(c):
    """Each bone at rest in the rig's space, as scene._armature builds it:
    (4x4, its length)."""
    key = id(c)
    if key in _RESTS:
        return _RESTS[key]
    out = {}
    for b in c.bones:
        head = np.array(c.joints[b.head], float)
        along = np.array(c.joints[b.tail], float) - head
        length = float(np.linalg.norm(along))
        y = along / max(length, 1e-9)
        z = np.array(b.up, float) if b.up is not None else np.cross([1.0, 0.0, 0.0], y)
        if np.linalg.norm(z) < 1e-4:
            z = np.array([0.0, 1.0, 0.0])
        z = z - y * float(z @ y)
        z /= max(float(np.linalg.norm(z)), 1e-9)
        m = np.eye(4)
        m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3] = np.cross(y, z), y, z, head
        out[b.name] = (m, length)
    _RESTS[key] = out
    return out


def joints_of(c, p):
    """Where every bone's two ends are in a pose (the rig's space, the
    body's own move and turn included): {bone: (head, tail)}."""
    rests = _rests(c)
    body = np.eye(4)
    body[:3, :3] = _euler(*p.get("root_rot", (0.0, 0.0, 0.0)))
    body[:3, 3] = p.get("root_loc", (0.0, 0.0, 0.0))
    scale, shift = p.get("scale", {}), p.get("shift", {})
    world, out = {}, {}
    todo = list(c.bones)
    while todo:
        b = todo.pop(0)
        if b.parent and b.parent not in world:
            todo.append(b)
            continue
        rest, length = rests[b.name]
        local = np.eye(4)
        local[:3, :3] = _euler(*p.get(b.name, (0.0, 0.0, 0.0))) * np.array(scale.get(b.name, (1.0, 1.0, 1.0)))
        local[:3, 3] = shift.get(b.name, (0.0, 0.0, 0.0))
        if b.parent:
            m = world[b.parent] @ np.linalg.inv(rests[b.parent][0]) @ rest @ local
        else:
            m = body @ rest @ local
        world[b.name] = m
        out[b.name] = (m[:3, 3].copy(), (m @ np.array([0.0, length, 0.0, 1.0]))[:3])
    return out


def _ends(c, p):
    """How far forward its front is and how far back its back end, in a
    pose (its ears aside: their tips tipping forward are no part of a
    blow)."""
    joints = joints_of(c, p)
    front = [end[1] for bone, ends in joints.items() if not bone.startswith("ear.") for end in ends]
    # (Nor is a tail swung up behind it a body backing into someone.)
    back = [end[1] for bone, ends in joints.items() if not bone.startswith("tail") for end in ends]
    return max(front), min(back)


_BODIES = {}


def _reach(c):
    """An animal's reach and how far a clip may carry it, in its model's
    own units: (forward at the hit, forward at most, backward at most), or
    None for an animal the game doesn't have yet."""
    if not _BODIES:
        try:
            _BODIES["bodies"] = json.load(open(os.path.join(GAME, "data", "bodies.json")))["animals"]
            _BODIES["models"] = json.load(open(os.path.join(GAME, "art", "models", "battle", "models.json")))
        except (OSError, KeyError, ValueError):
            _BODIES["bodies"], _BODIES["models"] = {}, {}
    body, model = _BODIES["bodies"].get(c.name), _BODIES["models"].get(c.name)
    if body is None or model is None:
        return None
    limits = DATA["limits"]
    tile = 1.0 / float(model["tile_scale"])
    if body.get("shooter"):
        at_hit = most = float(limits["shooter_ahead_tiles"]) * tile
    else:
        reach = float(body["reach"]) * tile
        k = float(limits["flier_reach"]) if c.motion.get("body") in ("bird", "winged") else 1.0
        at_hit, most = reach * k * float(limits["reach_at_hit"]), reach * k * float(limits["reach_most"])
    return at_hit, most, float(limits["back_tiles"]) * tile
