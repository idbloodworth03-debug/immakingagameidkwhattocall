"""Shortcuts for writing a toy's design (animals/<id>.py): a Design starts
from the animal's own skeleton (toy.skeleton), then takes its shapes (round
blobs, sticks and flat plates, each on the bone that moves it), its color
patches, its eyes and its nose.

Sizes are in units of the animal's own size (`u`: its height at the
withers, so a design's numbers are proportions and carry from one animal
to another): a radius of 0.3 is 0.3 of that height, whatever the animal.
Places are joints of its skeleton, moved by an offset in the same units:
d.p("skull", (0, 0.2, -0.1)). The animal faces +Y with +Z up; its left side
is x < 0. A sided part is written once, for the left, and mirrored: `pair`
calls a function for each side with the side's suffix (".L", ".R") and k
(1 left, -1 right), and side(offset, k) mirrors a left-side offset.
"""
import numpy as np

import motion
from sdf import cone, ellipsoid, plate

import toy as T

EYE_COLORS = {"eye_white": "#ffffff", "pupil": "#231d26", "nose": "#2b2024"}


def side(p, k):
    """A left-side offset or point (x < 0) on the left (k = 1) or mirrored (k = -1)."""
    return np.array([p[0] * k, p[1], p[2]], float)


# --- Patches: where on the body a color goes (each is a field: toy.Surface) -----

def part(*regions):
    """The body parts with these names."""
    return lambda s: s.part(*regions) - 0.5


def both(*fields):
    """Where all of them are."""
    return lambda s: np.minimum.reduce([f(s) for f in fields])


def either(*fields):
    """Where any of them is."""
    return lambda s: np.maximum.reduce([f(s) for f in fields])


def but(field, *others):
    """Where `field` is and none of `others` are."""
    return lambda s: np.minimum.reduce([field(s)] + [-f(s) for f in others])


def card_pose(t=0.3, jaw=-0.3, turn=0.25, lean=0.0, head=(0.0, 0.0), clip="attack"):
    """A card pose of the toy's own, where the old model's hides what the
    toy is known by (a face turned down, a mouth agape): a moment `t` of
    one of its animations (`clip`: its attack unless given), mirrored so
    its near side leads on the card's camera, the body turned `turn`
    toward us (radians; below 0: side on the other way) and leaning
    `lean`, the head tipped and turned (`head`: up, toward us), the jaw
    open by `jaw`. Give it to Design.toy(hero=...)."""
    def pose(c):
        p = motion._mirror_pose(motion.ANIMATIONS[clip][0](c, t))
        rx, ry, rz = p.get("root_rot", (0.0, 0.0, 0.0))
        p["root_rot"] = (rx + lean, ry, rz + turn)
        p.rot("head", x=head[0], z=head[1])
        p.rot("jaw", x=jaw)
        return p
    return pose


def facing(direction, at_least=0.0):
    """Where the surface faces `direction` (1: squarely; 0: side on)."""
    d = np.asarray(direction, float)
    d = d / np.linalg.norm(d)
    return lambda s: s.n @ d - at_least


class Design:
    """A toy being designed. `changes`: joints of the frozen skeleton to
    move (toy.skeleton; in meters). `unit`: the animal's own size, if not
    its height at the withers."""

    def __init__(self, animal_id, colors, base, changes=None, straight_legs=True, unit=None):
        self.id = animal_id
        self.c = T.skeleton(animal_id, changes)
        if straight_legs and "elbow.L" in self.c.joints and "knee.L" in self.c.joints:
            self._straighten_legs()
        self.u = float(unit if unit is not None else self.c.joints["withers"][2])
        self.colors = dict(EYE_COLORS, **colors)
        self.base = base
        self.patches = []
        self.eyes = []
        self.pieces = []
        self._ears = []

    def _straighten_legs(self):
        """A toy's legs are sticks: each leg's knee and ankle come under its
        top joint (where the old model's leg zigzagged like a real one), its
        toes a little ahead of the ankle on the ground. The leg's bones keep
        their order, so its walk and swings still bend it."""
        for suffix in (".L", ".R"):
            for names in (("shoulder", "elbow", "wrist", "front_toe"), ("hip", "knee", "hock", "hind_toe")):
                top, mid, low, toe = (np.asarray(self.c.joints[n + suffix], float) for n in names)
                x = (top[0] + toe[0]) / 2
                y = (top[1] + toe[1]) / 2
                foot = max(float(np.hypot(toe[0] - low[0], toe[1] - low[1])), top[2] * 0.12)
                self.c.joints[names[0] + suffix] = (x, y, top[2])
                self.c.joints[names[1] + suffix] = (x, y, top[2] * 0.56)
                self.c.joints[names[2] + suffix] = (x, y, max(low[2], top[2] * 0.2))
                self.c.joints[names[3] + suffix] = (x, y + foot, toe[2])

    # --- Places ---

    def j(self, name):
        """A joint's position, meters (a sided one with its side: "elbow.L")."""
        return np.asarray(self.c.joints[name], float)

    def p(self, where, offset=(0, 0, 0)):
        """A place: a joint (by name) or a point in meters, moved by
        `offset` in the animal's units."""
        base = self.j(where) if isinstance(where, str) else np.asarray(where, float)
        return base + np.asarray(offset, float) * self.u

    def move(self, names, offset):
        """Moves joints (a sided one named without its side moves on both
        sides, mirrored) by `offset` in the animal's units: do it before
        the shapes on them are made."""
        for name in names:
            if name in self.c.joints:
                self.c.joints[name] = tuple(self.j(name) + np.asarray(offset, float) * self.u)
            else:
                for suffix, k in ((".L", 1), (".R", -1)):
                    self.c.joints[name + suffix] = tuple(self.j(name + suffix) + side(offset, k) * self.u)

    def put(self, name, where, offset=(0, 0, 0)):
        """Puts a joint at a place (a sided one, named without its side, on
        both sides: the place is the left one's, mirrored for the right):
        do it before the shapes on it are made."""
        at = self.p(where, offset)
        if name in self.c.joints:
            self.c.joints[name] = tuple(at)
        else:
            self.c.joints[name + ".L"] = tuple(at)
            self.c.joints[name + ".R"] = (-at[0], at[1], at[2])

    def pair(self, fn):
        for suffix, k in ((".L", 1), (".R", -1)):
            fn(suffix, k)

    # --- Shapes (places as for p(); sizes in the animal's units) ---

    def blob(self, center, radii, part_name, bone, blend=0.1, yaw=0.0, pitch=0.0, roll=0.0):
        self.c.shapes.append(ellipsoid(self.p(center), np.asarray(radii, float) * self.u, part_name, bone, blend=blend * self.u,
                                       yaw=yaw, pitch=pitch, roll=roll))

    def stick(self, a, b, ra, rb, part_name, bone, bone_b=None, blend=0.07):
        self.c.shapes.append(cone(self.p(a), self.p(b), ra * self.u, rb * self.u, part_name, bone, bone_b, blend=blend * self.u))

    def rope(self, joints, radii, bones, part_name, blend=0.1, steps=3):
        """A rope of a body through joints (a snake's, an eel's), curved
        smoothly through them where sticks would bend at each: `radii` at
        each joint; `bones`: the bone each stretch between two joints
        follows, and one more for the last joint to blend into;
        `part_name`: one name, or one for each stretch."""
        points = [self.p(j) for j in joints]
        last = len(points) - 1
        names = [part_name] * last if isinstance(part_name, str) else list(part_name)
        for i in range(last):
            p0, p1, p2, p3 = points[max(i - 1, 0)], points[i], points[i + 1], points[min(i + 2, last)]

            def at(t):
                return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3)
            for k in range(steps):
                t0, t1 = k / steps, (k + 1) / steps
                ra = radii[i] + (radii[i + 1] - radii[i]) * t0
                rb = radii[i] + (radii[i + 1] - radii[i]) * t1
                onto = bones[i + 1] if k == steps - 1 and i + 1 < len(bones) else None
                self.stick(at(t0), at(t1), ra, rb, names[i], bones[i], onto, blend=blend)

    def flat(self, a, b, tip, thick, rounding, part_name, bone, blend=0.07):
        self.c.shapes.append(plate(self.p(a), self.p(b), self.p(tip), thick * self.u, rounding * self.u, part_name, bone,
                                   blend=blend * self.u))

    # --- The usual parts of a four-legged animal, placed on its joints ---

    def torso(self, rump, chest, rump_at=(0, 0, 0), chest_at=(0, 0, 0), blend=0.27, part_name="torso"):
        """A bean of a body: a rump round the pelvis and a chest round the
        withers (each its half sizes across, along and up; moved by `*_at`)."""
        self.blob(self.p("pelvis", rump_at), rump, part_name, "hips", blend=0.0)
        self.blob(self.p("withers", chest_at), chest, part_name, "chest", blend=blend)

    def head(self, radii, at=(0, 0, 0), blend=0.13, pitch=0.0, part_name="head"):
        self.blob(self.p("skull", at), radii, part_name, "head", blend=blend, pitch=pitch)

    def muzzle(self, root, base, end, blend=0.13, part_name="muzzle", tip=(0, 0, 0)):
        """A muzzle from the skull (moved by `root`) to the snout's tip
        (moved by `tip`)."""
        self.stick(self.p("skull", root), self.p("snout_tip", tip), base, end, part_name, "head", blend=blend)

    def neck(self, base, top, blend=0.2, part_name="torso"):
        self.stick("neck_base", "head_base", base, top, part_name, "neck", "head", blend=blend)

    def limb(self, kind, suffix, radii, end, part_name, end_part=None, blend=0.05, on_ground=True):
        """One limb as sticks along its joints: `kind` "fl" (a front leg, or
        an upright animal's arm: shoulder, elbow, wrist, front toe) or "hl"
        (a hind leg: hip, knee, hock, hind toe); `radii`: the stick's radius
        at the top, the knee and the ankle; `end`: the paw's (or hand's)
        half sizes across, along and up. A paw `on_ground` rests on it under
        the toes; a hand hangs where its joints are."""
        joints = ("shoulder", "elbow", "wrist", "front_toe") if kind == "fl" else ("hip", "knee", "hock", "hind_toe")
        top, mid, low, toe = (self.j(n + suffix) for n in joints)
        self.stick(top, mid, radii[0], radii[1], part_name, f"{kind}_upper{suffix}", blend=blend)
        self.stick(mid, low, radii[1], radii[2], part_name, f"{kind}_lower{suffix}", blend=blend)
        if on_ground:
            center = np.array([toe[0], (low[1] + toe[1]) / 2 + end[1] * self.u * 0.25, end[2] * self.u])
        else:
            center = (low + toe) / 2
        self.blob(center, end, end_part or part_name, f"{kind}_foot{suffix}", blend=blend)

    def legs(self, front, hind, paw, blend=0.05, part_name="leg", paw_part=None):
        """Four stick legs along the leg joints: `front` and `hind` are the
        stick's radius at the top, the knee and the ankle; `paw` the paw's
        half sizes (across, along, up)."""
        def one(suffix, k):
            self.limb("fl", suffix, front, paw, part_name, paw_part, blend)
            self.limb("hl", suffix, hind, paw, part_name, paw_part, blend)
        self.pair(one)

    def jaw(self, base, end, blend=0.03, part_name="jaw", tip=(0, 0, 0)):
        """A lower jaw of its own, from the jaw's hinge to the chin (moved by
        `tip`), on the jaw bone: it opens when the animal bites or yawns.
        Paint mouth_line() where it meets the head."""
        self.stick("jaw_hinge", self.p("chin", tip), base, end, part_name, "jaw", blend=blend)

    def mouth_line(self, width=0.1, part_name="jaw"):
        """The line where the lower jaw meets the head: a thin line with the
        mouth shut, and the inside of the mouth as it opens (the skin there
        stretches between the two)."""
        return lambda s: width - np.abs(s.part(part_name) - 0.5)

    def tail(self, radii, blend=0.1, part_name="tail"):
        """A tail along its joints: its radius at the base, the middle, the
        end and the very tip."""
        self.stick("tail_base", "tail_mid", radii[0], radii[1], part_name, "tail1", "tail2", blend=blend)
        self.stick("tail_mid", "tail_end", radii[1], radii[2], part_name, "tail2", "tail3", blend=blend)
        self.stick("tail_end", "tail_tip_end", radii[2], radii[3], part_name, "tail3", blend=blend)

    def ears_pointed(self, width, thick=0.06, rounding=0.087, turn=0.35, lean=0.0, blend=0.07, part_name="ear"):
        """Pointed ears: a rounded triangle from each ear's base joint to its
        tip joint, `width` wide at the base, turned outward by `turn`
        (radians), its tip moved outward by `lean`."""
        def one(suffix, k):
            base, tip = self.j("ear_base" + suffix), self.j("ear_tip" + suffix)
            out = -1.0 if suffix == ".L" else 1.0
            across = np.array([np.cos(turn) * out, -np.sin(turn), 0.0])
            a, b = base - across * width * self.u / 2, base + across * width * self.u / 2
            c = tip + np.array([out * lean * self.u, 0.0, 0.0])
            self.flat(a, b, c, thick, rounding, part_name, "ear" + suffix, blend=blend)
            self._ears.append((a, b, c))
        self.pair(one)

    def ears_round(self, radii, at=(0, 0, 0), blend=0.07, part_name="ear", tilt=0.0):
        """Round ears: a flattened ball on each ear's base joint (moved by
        `at`, given for the left)."""
        def one(suffix, k):
            self.blob(self.p("ear_base" + suffix, side(at, k)), radii, part_name, "ear" + suffix, blend=blend, roll=tilt * k)
        self.pair(one)

    # --- A bird in its flying pose (wings spread, legs trailing); wings on a four-legged body ---

    WING = ("shoulder", "elbow", "wrist", "wing_tip")

    def bird_stance(self, head=(0, -0.15, 0.55), hip=(-0.3, 0.3, -0.5), foot=(-0.3, 0.05, -0.95)):
        """A toy bird carries a big head high over a round body and lets
        its legs dangle under it (the bird it replaces flew stretched out
        flat, its legs trailing): its head's joints move by `head`, and
        each hip and foot go to a place from its pelvis (given for the
        left). Do it before its shapes are made."""
        self.move(["head_base", "skull", "beak_tip", "jaw_hinge", "chin"], head)
        self.put("hip", "pelvis", hip)
        self.put("foot", "pelvis", foot)

    def shorten_wings(self, share, joints=WING):
        """A toy's wings are stubbier than a real bird's, which leaves its
        body more of its size on screen: each wing's joints come in toward
        its shoulder, to `share` of their distance. Do it before the wings
        are made."""
        for suffix in (".L", ".R"):
            root = self.j(joints[0] + suffix)
            for name in joints[1:]:
                self.c.joints[name + suffix] = tuple(root + (self.j(name + suffix) - root) * share)

    def wings(self, chords, thick=0.09, lead=0.2, blend=0.08, part_name="wing", joints=WING):
        """Wings: a flat lobe along each of a wing's three bones (from the
        shoulder to the elbow, the wrist and the tip), as deep front to
        back as `chords` says for each, its front edge a little (`lead` of
        its depth) ahead of the bone."""
        def one(suffix, k):
            points = [self.j(n + suffix) for n in joints]
            for a, b, chord, bone in zip(points, points[1:], chords, ("wing_upper", "wing_lower", "wing_hand")):
                along = b - a
                flat = float(np.hypot(along[0], along[1]))
                back = np.array([-along[1], along[0], 0.0]) / flat
                if back[1] > 0:
                    back = -back
                center = (a + b) / 2 + back * chord * (0.5 - lead) * self.u
                radii = (float(np.linalg.norm(along)) / 2 + chord * 0.3 * self.u, chord * self.u / 2, thick * self.u)
                self.c.shapes.append(ellipsoid(center, radii, part_name, bone + suffix, blend=blend * self.u,
                                               yaw=float(np.arctan2(along[1], along[0])), roll=-float(np.arctan2(along[2], flat))))
        self.pair(one)

    def wing_fingers(self, count, length, radius, fan=(-0.1, -1.0), blend=0.04, part_name="wing", joints=WING):
        """The long feathers at each wing's tip (an eagle's, a condor's):
        `count` fingers from the tip, fanned from `fan`[0] to `fan`[1]
        radians off the wing's last bone, toward the back."""
        def one(suffix, k):
            wrist, tip = self.j(joints[2] + suffix), self.j(joints[3] + suffix)
            along = (tip - wrist) / np.linalg.norm(tip - wrist)
            for i in range(count):
                turn = fan[0] + (fan[1] - fan[0]) * i / max(count - 1, 1)
                a = turn if suffix == ".L" else -turn
                way = np.array([along[0] * np.cos(a) - along[1] * np.sin(a), along[0] * np.sin(a) + along[1] * np.cos(a), along[2]])
                root = tip - along * 0.35 * length * self.u
                self.stick(root, root + way * length * 1.35 * self.u, radius, radius * 0.75, part_name, "wing_hand" + suffix, blend=blend)
        self.pair(one)

    def tail_fan(self, spread, root=0.3, thick=0.07, rounding=0.1, blend=0.08, part_name="tail", end=(0, 0, 0)):
        """A bird's tail: a flat fan from a point `root` ahead of the tail's
        base (inside its body) to the tail's end (moved by `end`), `spread`
        wide there."""
        tip = self.p("tail_end", end)
        half = np.array([spread * self.u / 2, 0.0, 0.0])
        self.flat(tip - half, tip + half, self.p("tail_base", (0, root, 0)), thick, rounding, part_name, "tail1", blend=blend)

    def bird_legs(self, radius, foot, blend=0.04, part_name="leg", foot_part="foot"):
        """A bird's legs, trailing under its tail as it flies: a stick from
        each hip to its foot, and the foot's ball (its half sizes)."""
        def one(suffix, k):
            self.stick("hip" + suffix, "foot" + suffix, radius, radius * 0.85, part_name, "leg" + suffix, blend=blend)
            self.blob("foot" + suffix, foot, foot_part, "leg" + suffix, blend=blend)
        self.pair(one)

    def beak(self, root, base, end, hook=0.0, blend=0.03, part_name="beak", tip=(0, 0, 0)):
        """The upper beak, from the skull (moved by `root`) to the beak's
        tip (moved by `tip`); `hook`: how far its tip turns down (a
        raptor's, a parrot's). The lower beak is the jaw()."""
        a, b = self.p("skull", root), self.p("beak_tip", tip)
        self.stick(a, b, base, end, part_name, "head", blend=blend)
        if hook:
            self.stick(b, self.p(b, (0, -0.3 * hook, -hook)), end, end * 0.45, part_name, "head", blend=blend)

    # --- Color patches ---

    def paint(self, color, field):
        """A patch of `color` where `field` is (a field is a function of
        toy.Surface, above 0 inside the patch: the functions above and the
        methods below make them); later patches cover earlier ones."""
        self.patches.append((color, field))

    def around(self, where, offset, radii, yaw=0.0, pitch=0.0, mirrored=False):
        """Inside an ellipsoid round a place (and, `mirrored`, its mirror
        image on the other side)."""
        center = self.p(where, offset)
        r = np.asarray(radii, float) * self.u
        def field(s):
            f = s.within(center, r, yaw, pitch)
            if mirrored:
                f = np.maximum(f, s.within((-center[0], center[1], center[2]), r, -yaw, pitch))
            return f
        return field

    def beyond(self, where, offset, direction):
        """Past the plane through a place, facing `direction`."""
        point = self.p(where, offset)
        return lambda s: s.beyond(point, direction)

    def below(self, where, offset=(0, 0, 0)):
        z = self.p(where, offset)[2]
        return lambda s: z - s.v[:, 2]

    def above(self, where, offset=(0, 0, 0)):
        z = self.p(where, offset)[2]
        return lambda s: s.v[:, 2] - z

    def ahead(self, where, offset=(0, 0, 0)):
        y = self.p(where, offset)[1]
        return lambda s: s.v[:, 1] - y

    def behind(self, where, offset=(0, 0, 0)):
        y = self.p(where, offset)[1]
        return lambda s: y - s.v[:, 1]

    def off_middle(self, x):
        """Further than x from the animal's middle line."""
        return lambda s: np.abs(s.v[:, 0]) - x * self.u

    def near_middle(self, x):
        return lambda s: x * self.u - np.abs(s.v[:, 0])

    def bands(self, where, offset, direction, every, share=0.5):
        """Stripes across `direction`, one every `every` from a place, each
        `share` of that wide."""
        point = self.p(where, offset)
        d = np.asarray(direction, float)
        d = d / np.linalg.norm(d)
        return lambda s: np.cos(2 * np.pi * ((s.v - point) @ d) / (every * self.u)) - np.cos(np.pi * share)

    def _ear_sides(self, s):
        """For each pointed ear: how far in front of its plate each point is
        and how far inside its triangle, meters (toy.Surface)."""
        out = []
        for a, b, c in self._ears:
            n = np.cross(b - a, c - a)
            n = n / np.linalg.norm(n) * (1.0 if n[1] > 0 else -1.0)
            inside = np.full(len(s.v), np.inf)
            for p, q, r in ((a, b, c), (b, c, a), (c, a, b)):
                edge = np.cross(n, q - p)
                edge /= np.linalg.norm(edge)
                if (r - p) @ edge < 0:
                    edge = -edge
                inside = np.minimum(inside, (s.v - p) @ edge)
            out.append(((s.v - a) @ n, inside))
        return out

    def ear_fronts(self, inset=-0.013, part_name="ear"):
        """The inside of each pointed ear: its front, `inset` in from the
        triangle's edge (below 0: a little past it)."""
        def field(s):
            f = np.full(len(s.v), -1.0)
            for front, inside in self._ear_sides(s):
                f = np.maximum(f, np.minimum(front - 0.013 * self.u, inside - inset * self.u))
            return np.minimum(f, s.part(part_name) - 0.5)
        return field

    def ear_backs(self, part_name="ear"):
        def field(s):
            f = np.full(len(s.v), -1.0)
            for (a, b, c), (front, inside) in zip(self._ears, self._ear_sides(s)):
                near = 0.6 * np.linalg.norm(c - (a + b) / 2) - np.linalg.norm(s.v - (a + b + c) / 3, axis=1)
                f = np.maximum(f, np.minimum(-front - 0.007 * self.u, near))
            return np.minimum(f, s.part(part_name) - 0.5)
        return field

    def ear_tips(self, share=0.35, part_name="ear"):
        """The top `share` of each pointed ear."""
        def field(s):
            f = np.full(len(s.v), -1.0)
            for a, b, c in self._ears:
                base = (a + b) / 2
                up = c - base
                length = np.linalg.norm(up)
                f = np.maximum(f, np.minimum((s.v - base) @ (up / length) - length * (1 - share),
                                             length * 0.9 - np.linalg.norm(s.v - (base + c) / 2, axis=1)))
            return np.minimum(f, s.part(part_name) - 0.5)
        return field

    # --- Face ---

    def eye(self, toward, radius, origin="skull", offset=(0, 0, 0), **more):
        """A pair of button eyes on the surface, `toward` (the left eye's
        direction) from a place inside the head."""
        self.eyes.append(T.Eye(origin=tuple(self.p(origin, offset)), toward=tuple(toward), radius=radius * self.u, **more))

    def nose(self, where, offset, radii, color="nose", bone="head"):
        self.pieces.append(T.Piece(center=tuple(self.p(where, offset)), radii=tuple(np.asarray(radii, float) * self.u), color=color, bone=bone))

    def toy(self, **more):
        """The finished design. Its mesh's fineness follows its size."""
        more.setdefault("voxel", 0.02 * self.u)
        more.setdefault("longest", (0.1 * self.u, 0.167 * self.u))
        return T.Toy(self.id, self.c, self.colors, self.base, self.patches, self.eyes, self.pieces, **more)
