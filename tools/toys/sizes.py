"""Keeps every animal exactly as tall on screen when it becomes a toy.

    godot --headless --path game res://tests/stand_report.tscn | python3 tools/toys/sizes.py --record
    godot --headless --path game res://tests/stand_report.tscn | python3 tools/toys/sizes.py

bodies.json "size" is an animal's longest side as drawn, so a toy of other
proportions (a longer tail, a bigger head) needs another size to stand as
tall as the model it replaces. --record writes down how each animal is
drawn now (stands.json: how tall it stands, its outline in its idle pose,
and how long it is on the ground, both in field tiles), once, before its
art changes: an animal already written down, or already a toy, is left
alone. Without it, every toy in the roster gets the size at which it
stands exactly that tall and its tallest pose as its model measures
(game/data/bodies.json size and pose_up), and its sprites' size follows
(tools/packs/packs.json tiles_long: its longest side on the ground). It
also says how long each toy is now drawn on the ground against before: its
body's room in a fight (bodies.json footprint, width) doesn't change with
its art, so a toy much longer than the model it replaces would overlap its
neighbors (design it more compact: a tail carried higher, a shorter body).
Convert its battle model again (and render its sprites) after a change.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STANDS = os.path.join(HERE, "stands.json")
BODIES = os.path.join(HERE, "..", "..", "game", "data", "bodies.json")
PACKS = os.path.join(HERE, "..", "packs", "packs.json")


def main():
    measured = None
    for line in sys.stdin:
        if line.startswith("STANDS "):
            measured = json.loads(line[len("STANDS "):])
    if measured is None:
        raise SystemExit("No STANDS line: pipe in the output of tests/stand_report.tscn")
    stands = json.load(open(STANDS)) if os.path.exists(STANDS) else {}
    if "--record" in sys.argv:
        for animal_id, m in sorted(measured.items()):
            if animal_id in stands or m["toy"]:
                continue
            stands[animal_id] = {"stands": m["stands"], "long": round(m["size"] * m["flat_share"], 3)}
            print(f"{animal_id}: stands {m['stands']} tiles tall, {stands[animal_id]['long']} long on the ground")
        with open(STANDS, "w") as f:
            f.write(json.dumps(stands, indent=1, sort_keys=True) + "\n")
        return
    text = open(BODIES).read()
    bodies = json.loads(text)
    packs = json.load(open(PACKS))
    changed = 0
    for animal_id, m in sorted(measured.items()):
        if not m["toy"]:
            continue
        if animal_id not in stands:
            raise SystemExit(f"{animal_id} is a toy but stands.json doesn't say how tall it stood: record it before its art changes.")
        body = bodies["animals"][animal_id]
        was = stands[animal_id]
        size = round(was["stands"] / m["up_share"], 2)
        pose_up = m["pose_up_now"]
        long = round(size * m["flat_share"], 2)
        if body.get("size") != size or body.get("pose_up") != pose_up:
            changed += 1
        print(f"{animal_id}: size {body.get('size')} -> {size}, pose_up {body.get('pose_up')} -> {pose_up}; stands {was['stands']} tall, "
              f"{long} long on the ground (was {was['long']}: {long / was['long'] * 100 - 100:+.0f}%; footprint {body.get('footprint')})")
        body["size"] = size
        body["pose_up"] = pose_up
        if animal_id in packs["animals"]:
            packs["animals"][animal_id]["tiles_long"] = long
    with open(BODIES, "w") as f:
        f.write(json.dumps(bodies, indent=1, ensure_ascii=False) + ("\n" if text.endswith("\n") else ""))
    with open(PACKS, "w") as f:
        f.write(json.dumps(packs, indent=1, ensure_ascii=False) + "\n")
    print(f"{changed} changed")


if __name__ == "__main__":
    main()
