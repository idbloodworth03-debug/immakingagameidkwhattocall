"""Writes each art test's drawn size and tallest pose into the game's data,
from the game's own measurements:

    godot --headless --path game res://tests/art_test_report.tscn | python3 tools/packs/sizes.py

The report's last line (ARTTEST {...}) gives, per art test, the size (its
longest side in field tiles) at which it stands exactly as tall on screen as
the animal it plays as, the size at which its tallest pose stands as tall
as that animal's tallest (size_tallest: for an animal that rests low and
rears up, art_tests.json "match": "tallest"), and its pose_up (how much
taller than standing its tallest pose is). They go into game/data/art_tests.json; packs.json's
tiles_long follows the size, so its sprites are rendered at the size they
are drawn. Run convert.py and render.py again after a size changes.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.join(HERE, "..", "..", "game", "data", "art_tests.json")
PACKS = os.path.join(HERE, "packs.json")


def main():
    measured = None
    for line in sys.stdin:
        if line.startswith("ARTTEST "):
            measured = json.loads(line[len("ARTTEST "):])
    if measured is None:
        raise SystemExit("No ARTTEST line: pipe in the output of tests/art_test_report.tscn")
    tests = json.load(open(TESTS))
    packs = json.load(open(PACKS))
    for animal_id, numbers in measured.items():
        entry = tests["animals"].get(animal_id)
        if entry is None:
            continue
        old = (entry.get("size"), entry.get("pose_up"))
        entry["size"] = numbers["size_tallest"] if entry.get("match") == "tallest" else numbers["size"]
        entry["pose_up"] = numbers["pose_up"]
        if animal_id in packs["animals"]:
            packs["animals"][animal_id]["tiles_long"] = entry["size"]
        print(f"{animal_id}: size {old[0]} -> {entry['size']}, pose_up {old[1]} -> {numbers['pose_up']}")
    with open(TESTS, "w") as f:
        f.write(json.dumps(tests, indent=2, ensure_ascii=False) + "\n")
    with open(PACKS, "w") as f:
        f.write(json.dumps(packs, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
