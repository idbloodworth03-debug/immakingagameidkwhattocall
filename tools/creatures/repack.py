"""Converts sprite sheets made before the tight layout (one row per
animation and direction) to the packed layout, shrinking them to the
current pixels per tile on the way. No re-rendering needed.

    python repack.py red_fox wolf_pack ...
"""
import json
import os
import sys

import numpy as np
from PIL import Image

import sprites

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "art", "units")


def repack(species):
    base = os.path.join(ROOT, species)
    meta = json.load(open(os.path.join(base, "sheet.json")))
    if meta.get("version") == 2:
        print(species, "already packed")
        return
    sheet = np.asarray(Image.open(os.path.join(base, "sheet.webp")).convert("RGBA"))
    cw, ch = meta["cell"]
    pad = meta["padding"]
    scale = sprites.PIXELS_PER_TILE / float(meta.get("pixels_per_tile", 64))
    new_w, new_h = int(round(cw * scale)), int(round(ch * scale))
    crops, timing = {}, {}
    for anim, info in meta["animations"].items():
        timing[anim] = (info["frames"], info["fps"], info["loop"])
        for d, row in info["rows"].items():
            frames = []
            for f in range(info["frames"]):
                x, y = f * (cw + pad * 2) + pad, row * (ch + pad * 2) + pad
                cell = Image.fromarray(sheet[y:y + ch, x:x + cw])
                frames.append(np.asarray(cell.resize((new_w, new_h), Image.LANCZOS)))
            crops[(anim, int(d))] = frames
    hit = meta["animations"].get("attack", {}).get("hit", 0.45)
    anchor = (meta["anchor"][0] * new_w / cw, meta["anchor"][1] * new_h / ch)
    packed, new_meta = sprites.pack(crops, timing, hit, anchor)
    new_meta["walk_cycle_tiles"] = meta.get("walk_cycle_tiles", 1.0)
    new_meta["top"] = round(meta.get("top", 40.0) * new_h / ch, 1)
    packed.save(os.path.join(base, "sheet.webp"), "WEBP", quality=90, method=6)
    json.dump(new_meta, open(os.path.join(base, "sheet.json"), "w"), indent=1)
    print(f"{species}: {sheet.shape[1]}x{sheet.shape[0]} -> {packed.size[0]}x{packed.size[1]}")


if __name__ == "__main__":
    for name in sys.argv[1:]:
        repack(name)
