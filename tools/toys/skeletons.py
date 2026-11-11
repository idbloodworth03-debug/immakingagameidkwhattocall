"""Freezes each roster animal's skeleton and motion settings for the toys.

    python tools/toys/skeletons.py            # -> tools/toys/skeletons.json

A toy keeps the skeleton and the animations its animal already has: the
joints and bones of its model as it stands in the game (tools/creatures:
its species file, made a chibi by cartoon.py with movie.json's shape) and
how it moves (its gait, attacks and persona: motion.py). This writes those
down once, for every animal in game/data/animals.json, so a toy's design
(animals/<id>.py) starts from them and tools/toys no longer needs the old
models' builders. Run again only if the old pipeline's skeletons change.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CREATURES = os.path.normpath(os.path.join(HERE, "..", "creatures"))
sys.path.insert(0, CREATURES)
sys.path.insert(0, os.path.join(CREATURES, "species"))
OUT = os.path.join(HERE, "skeletons.json")


def main():
    import cartoon
    animals = json.load(open(os.path.join(HERE, "..", "..", "game", "data", "animals.json")))
    out = {}
    for animal in animals:
        sid = animal["id"]
        c = cartoon.load(sid, style="cartoon")
        out[sid] = {
            "joints": {k: [round(float(x), 4) for x in v] for k, v in c.joints.items()},
            "bones": [[b.name, b.head, b.tail, b.parent, list(b.up) if b.up is not None else None] for b in c.bones],
            "motion": c.motion,
            "tiles_long": float(c.tiles_long),
        }
        print(f"{sid}: {len(c.joints)} joints, {len(c.bones)} bones, motion {c.motion}")
    with open(OUT, "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
