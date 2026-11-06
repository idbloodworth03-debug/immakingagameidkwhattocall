"""Small sprite strips for the animals that watch and scurry round the
arenas (the game's arena life, data/arena_life.json): a few animations, one
direction each, cut from an animal's own sprite sheet and shrunk. A
spectator needs its idle and a cheer facing the field; a runner its walk
seen from the side. Tiny next to a full sheet, so an arena's crowd costs
almost no memory.

    python crowd.py                 # every animal data/arena_life.json uses
    python crowd.py red_fox walrus  # just these

Writes game/art/arenas/crowd/<id>.webp and <id>.json. Plain Python (Pillow),
no Blender. Run it again after re-rendering an animal's sheet.
"""
import argparse
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "game")
UNITS = os.path.join(ROOT, "art", "units")
OUT = os.path.join(ROOT, "art", "arenas", "crowd")
LIFE = os.path.join(ROOT, "data", "arena_life.json")

# What each strip holds: name -> (animation in the sheet, direction).
# Facing 180 is toward the camera (down the field), 90 is to the right.
STRIP = {
    "idle": ("idle", "180"),
    "cheer": ("fidget", "180"),
    "run": ("walk", "90"),
    "pounce": ("attack", "90"),
}
PIXELS_PER_TILE = 64
GAP = 2


def _pages(unit_dir, meta):
    count = int(meta.get("pages", 1) or 1)
    names = ["sheet.webp"] + ["sheet_%d.webp" % i for i in range(1, count)]
    return [Image.open(os.path.join(unit_dir, n)).convert("RGBA") for n in names]


def _shrink(im, k):
    """Resizes with premultiplied alpha, so edges don't pick up dark fringes."""
    a = np.asarray(im, float) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    pre = Image.fromarray(np.concatenate([rgb, a[..., 3:4]], -1).__mul__(255).round().astype(np.uint8), "RGBA")
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    small = np.asarray(pre.resize((w, h), Image.LANCZOS), float) / 255.0
    alpha = small[..., 3:4]
    rgb = np.where(alpha > 1e-4, small[..., :3] / np.maximum(alpha, 1e-4), 0.0)
    return Image.fromarray((np.concatenate([np.clip(rgb, 0, 1), alpha], -1) * 255).round().astype(np.uint8), "RGBA")


def make(animal_id, wanted):
    unit_dir = os.path.join(UNITS, animal_id)
    meta = json.load(open(os.path.join(unit_dir, "sheet.json")))
    pages = _pages(unit_dir, meta)
    k = PIXELS_PER_TILE / float(meta["pixels_per_tile"])
    rows = []
    for name in wanted:
        anim, direction = STRIP[name]
        spec = meta["animations"].get(anim)
        if spec is None and name == "cheer":
            anim, spec = "idle", meta["animations"]["idle"]
        if spec is None:
            continue
        cw, ch = spec["cell"]
        frames = []
        for at in spec["at"][direction]:
            page = pages[int(at[2]) if len(at) > 2 else 0]
            frames.append(_shrink(page.crop((int(at[0]), int(at[1]), int(at[0]) + cw, int(at[1]) + ch)), k))
        rows.append((name, spec, frames))
    width = max(sum(f.width + GAP for f in frames) for _, _, frames in rows)
    height = sum(frames[0].height + GAP for _, _, frames in rows)
    width, height = (width + 3) // 4 * 4, (height + 3) // 4 * 4
    strip = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    info = {"pixels_per_tile": PIXELS_PER_TILE, "animations": {}}
    y = 0
    for name, spec, frames in rows:
        x = 0
        rects = []
        for f in frames:
            strip.paste(f, (x, y))
            rects.append([x, y, f.width, f.height])
            x += f.width + GAP
        info["animations"][name] = {
            "frames": rects, "fps": spec["fps"], "loop": bool(spec["loop"]) if name != "cheer" else False,
            "anchor": [spec["anchor"][0] * k, spec["anchor"][1] * k],
        }
        y += frames[0].height + GAP
    os.makedirs(OUT, exist_ok=True)
    strip.save(os.path.join(OUT, animal_id + ".webp"), "WEBP", lossless=True, quality=100, method=6)
    with open(os.path.join(OUT, animal_id + ".json"), "w") as f:
        json.dump(info, f, indent=1)
    return strip.size


def needed():
    """Every animal the arenas use, and the strips each needs."""
    life = json.load(open(LIFE))
    want = {}
    for arena, spec in life.items():
        if arena.startswith("_"):
            continue
        for actor in spec.get("actors", []):
            animal = actor.get("animal")
            if not animal:
                continue
            kinds = {"spectator": ["idle", "cheer"], "runner": ["run"], "pouncer": ["idle", "pounce"]}
            want.setdefault(animal, set()).update(kinds.get(actor["kind"], ["idle"]))
    order = list(STRIP)
    return {a: sorted(s, key=order.index) for a, s in want.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("animals", nargs="*")
    args = parser.parse_args()
    jobs = needed()
    for animal_id in args.animals or list(jobs):
        size = make(animal_id, jobs.get(animal_id, ["idle", "cheer", "run"]))
        print("crowd", animal_id, size)


if __name__ == "__main__":
    main()
