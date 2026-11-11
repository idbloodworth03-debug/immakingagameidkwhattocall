"""Says whether a toy is built like the approved ones, from its design's
shapes (no rendering):
    python tools/toys/measure.py                  # every design
    python tools/toys/measure.py raccoon unicorn  # these
(Blender's Python, as for build.py.)

The first fifteen toys (the Red Fox, the Tank Destroyers and the Tanks)
are the standard. What they have in common, and a first draft of the next
classes did not (lankier bodies, smaller heads, thinner legs, birds that
were mostly wing):

  head  the head's width against the body's: as wide as the body or wider
        (0.85 at the least; less only under a great muzzle, trunk or horn
        that carries the face, as the Hippo's, the Elephant's, the Rhino's)
  legs  a leg's thickness against the body's half width: 0.36 or more
        (thick, stubby legs; the Komodo Dragon's sprawl and the Boar's
        and Cerberus's are the thin ones)
  eye   an eye's width against the head's: 0.19 or more
  tall  how much of its standing height is head: 0.33 or more (a mane,
        a horn, a crest or a neck reared up counts toward its height, so
        the Lion's, the Unicorn's and the Cobra's read lower)
  wide  a bird's wingspan against its height: under 2 (its body and face
        are what you see, not its wings)

A value under these is marked "low" ("WIDE" for a bird's span): rework the
design, or say in it why this animal is the exception. The numbers are no
substitute for looking at it beside approved toys, in one picture and in
the game's viewer, in the pose it stands in there (the Squirrel sits up
on its haunches, which tips a face built for all fours up at the sky).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(HERE, "..", "packs"), os.path.join(HERE, "..", "creatures")]

import numpy as np

import build

FLOORS = {"head": 0.85, "legs": 0.36, "eye": 0.19, "tall": 0.33}
WIDEST = 2.0
BODY = ("torso", "body", "skirt")
LIMBS = ("leg", "arm", "tentacle")


def measure(toy):
    """A design's proportions (0 where it has no such part)."""
    c = toy.creature
    lo, hi = np.full(3, np.inf), np.full(3, -np.inf)
    body = head = 0.0
    head_z = None
    legs = []
    for s in c.shapes:
        if s.kind == "ellipsoid":
            rot = getattr(s, "rot", None)
            reach = np.abs(np.asarray(rot) @ np.diag(s.radii)).max(axis=1) if rot is not None else np.asarray(s.radii)
            lo, hi = np.minimum(lo, s.a - reach), np.maximum(hi, s.a + reach)
            if s.region in BODY:
                body = max(body, float(s.radii[0]))
            if s.region == "head" and float(s.radii[0]) > head:
                head, head_z = float(s.radii[0]), (float(s.a[2] - s.radii[2]), float(s.a[2] + s.radii[2]))
        elif s.kind == "cone":
            for p, r in ((s.a, s.ra), (s.b, s.rb)):
                lo, hi = np.minimum(lo, np.asarray(p) - r), np.maximum(hi, np.asarray(p) + r)
            if s.region in LIMBS and s.bone.startswith(("fl_", "hl_")) and ("upper" in s.bone or "lower" in s.bone):
                legs.append((s.ra + s.rb) / 2)
            if s.region in BODY and "tail" not in s.bone:
                body = max(body, float(max(s.ra, s.rb)))
    size = hi - lo
    eye = toy.eyes[0].radius if toy.eyes else 0.0
    return {"head": head / body if body else 0.0, "legs": float(np.mean(legs)) / body if legs and body else 0.0,
            "eye": eye / head if head else 0.0, "tall": (head_z[1] - head_z[0]) / size[2] if head_z else 0.0,
            "wide": float(size[0] / max(size[2], 1e-6)), "bird": "wing_upper.L" in {b.name for b in c.bones} and not legs}


def main():
    names = [a for a in sys.argv[1:] if not a.startswith("-")]
    if not names:
        names = sorted(f[:-3] for f in os.listdir(os.path.join(HERE, "animals")) if f.endswith(".py"))
    print(f"{'':24s} {'head':>9s} {'legs':>9s} {'eye':>9s} {'tall':>9s} {'wide':>9s}")
    for name in names:
        m = measure(build.design(name).make())
        cells = []
        for key in ("head", "legs", "eye", "tall"):
            low = 0 < m[key] < FLOORS[key]
            cells.append(f"{m[key]:5.2f}{' low' if low else '    '}" if m[key] else "    -    ")
        cells.append(f"{m['wide']:5.2f}{' WIDE' if m['bird'] and m['wide'] > WIDEST else ''}")
        print(f"{name:24s} " + " ".join(cells))


if __name__ == "__main__":
    main()
