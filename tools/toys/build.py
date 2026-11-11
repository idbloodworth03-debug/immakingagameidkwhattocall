"""Builds our own toy-style animals (toy.py) into art_sources/own/.

    python build.py red_fox            # -> art_sources/own/red_fox_LOD0.glb, _LOD1.glb
    python build.py --all

It also writes the animal's entry in tools/packs/packs.json (the pack
"own"), so it comes into the game as any pack animal does
(tools/packs/README.md):
    python ../packs/convert.py red_fox
    python ../packs/render.py red_fox
"""
import argparse
import glob
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import toy


def design(name):
    """An animal's design module, animals/<name>.py (loaded by its path:
    tools/creatures has species files of the same names)."""
    spec = importlib.util.spec_from_file_location("toy_" + name, os.path.join(HERE, "animals", name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PACKS = os.path.join(HERE, "..", "packs", "packs.json")
GAME = os.path.join(HERE, "..", "..", "game")


def register(made, clips):
    """Writes a toy's entry in tools/packs/packs.json. A toy plays our own
    animations as they are: each of the game's animations is its clip of
    the same name, timed as the animal's sheet has it (game/art/units/<id>/
    sheet.json: frames, fps and the swing's hit moment, which the clip's
    own strike lands on exactly). Its body plan, attack styles and walk
    cycle are the sheet's too; its size on the ground stays as it was (or
    starts as bodies.json has it; tools/toys/sizes.py sets it)."""
    packs = json.load(open(PACKS))
    old = packs["animals"].get(made.name, {})
    sheet = json.load(open(os.path.join(GAME, "art", "units", made.name, "sheet.json")))
    bodies = json.load(open(os.path.join(GAME, "data", "bodies.json")))
    recipes = {}
    for name in ("idle", "walk", "attack", "attack2", "special", "fidget", "victory"):
        if name not in clips:
            continue
        spec = {"clip": name}
        if name not in ("idle", "walk", "victory"):
            spec["once"] = True
        hit = sheet.get("animations", {}).get(name, {}).get("hit")
        if hit is not None:
            spec["strike"] = hit
        recipes[name] = spec
    entry = {"pack": "own", "source": made.name, "timing": made.name, "body": sheet.get("body", "quadruped"),
             "attack_style": sheet.get("attack_style", "bite")}
    if "attack2" in recipes:
        entry["attack2_style"] = sheet.get("attack2_style", entry["attack_style"])
    entry["tiles_long"] = old.get("tiles_long", bodies["animals"][made.name]["size"])
    entry["walk_cycle_tiles"] = sheet.get("walk_cycle_tiles", 1.0)
    entry["lid_color"] = made.colors[made.lid or made.base]
    entry["clips"] = recipes
    entry["hero"] = {"clip": "hero", "at": 0.0, "face": {}, "turn": 0.0}
    packs["animals"][made.name] = entry
    with open(PACKS, "w") as f:
        f.write(json.dumps(packs, indent=1, ensure_ascii=False) + "\n")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("animals", nargs="*")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--out", default=toy.OUT)
    args = parser.parse_args(argv)
    names = args.animals
    if args.all:
        names = sorted(os.path.basename(p)[:-3] for p in glob.glob(os.path.join(HERE, "animals", "*.py")))
    for name in names:
        made = design(name).make()
        clips = toy.export(made, args.out)
        register(made, clips)


if __name__ == "__main__":
    main()
