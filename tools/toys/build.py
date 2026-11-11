"""Builds our own toy-style animals (toy.py) into art_sources/own/.

    python build.py red_fox            # -> art_sources/own/Fox.glb
    python build.py --all

Then bring it into the game as any pack animal (tools/packs/README.md):
    python ../packs/convert.py own_fox
    python ../packs/render.py own_fox
"""
import argparse
import glob
import importlib.util
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
        toy.export(design(name).make(), args.out)


if __name__ == "__main__":
    main()
